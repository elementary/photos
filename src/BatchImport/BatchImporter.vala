/*
* Copyright (c) 2009-2013 Yorba Foundation
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/


// BatchImport executes a list of import jobs taking a file from each and properly importing
// it into the system, including database additions and thumbnail creation.  It can be monitored by
// multiple observers, but only one ImportReporter can be registered.
//
// TODO: With background threads. the better way to implement this is via a FSM (finite state
// machine) that exists in states and responds to various events thrown off by the background
// jobs.  However, getting this code to a point that it works with threads is task enough, so it
// will have to wait (especially since we'll want to write a generic FSM engine).

//
// The order of the background jobs is important, both for how feedback is presented to the user
// and to protect certain subsystems which don't work well in a multithreaded situation (i.e.
// gPhoto).
//
// 1. WorkSniffer builds a list of all the work to do.  If the BatchImportJob is a file, there's
// not much more to do.  If it represents a directory, the directory is traversed, with more work
// generated for each file.  Very little processing is done here on each file, however, and the
// BatchImportJob.prepare is only called when a directory.
//
// 2. PrepareFilesJob walks the list WorkSniffer generated, preparing each file and examining it
// for any obvious problems.  This in turn generates a list of prepared files (i.e. downloaded from
// camera).
//
// 3. Each file ready for importing is a separate background job.  It is responsible for copying
// the file (if required), examining it, and generating a pixbuf for preview and thumbnails.
//

public class BatchImport : Object {
    private const int WORK_SNIFFER_THROBBER_MSEC = 125;

    public const int REPORT_EVERY_N_PREPARED_FILES = 100;
    public const int REPORT_PREPARED_FILES_EVERY_N_MSEC = 3000;

    private const int READY_SOURCES_COUNT_OVERFLOW = 10;

    private const int DISPLAY_QUEUE_TIMER_MSEC = 125;
    private const int DISPLAY_QUEUE_HYSTERESIS_OVERFLOW = (3 * 1000) / DISPLAY_QUEUE_TIMER_MSEC;

    private static Workers feeder_workers = new Workers (1, false);
    private static Workers import_workers = new Workers (Workers.thread_per_cpu_minus_one (), false);

    private Gee.Iterable<BatchImportJob> jobs;
    private BatchImportRoll import_roll;
    private string name;
    private uint64 completed_bytes = 0;
    private uint64 total_bytes = 0;
    private unowned ImportReporter reporter;
    private ImportManifest manifest;
    private bool scheduled = false;
    private bool completed = false;
    private int file_imports_to_perform = -1;
    private int file_imports_completed = 0;
    private Cancellable? cancellable = null;
    private int64 last_preparing_ms = 0;
    private Gee.HashSet<File> skipset;
#if !NO_DUPE_DETECTION
    private Gee.HashMap<string, File> imported_full_md5_table = new Gee.HashMap<string, File> ();
#endif
    private uint throbber_id = 0;
    private int max_outstanding_import_jobs = Workers.thread_per_cpu_minus_one ();
    private bool untrash_duplicates = true;
    private bool mark_duplicates_online = true;
    private GLib.Settings file_settings;

    // These queues are staging queues, holding batches of work that must happen in the import
    // process, working on them all at once to minimize overhead.
    private Gee.List<PreparedFile> ready_files = new Gee.LinkedList<PreparedFile> ();
    private Gee.List<CompletedImportObject> ready_thumbnails =
        new Gee.LinkedList<CompletedImportObject> ();
    private Gee.List<CompletedImportObject> display_imported_queue =
        new Gee.LinkedList<CompletedImportObject> ();
    private Gee.List<CompletedImportObject> ready_sources = new Gee.LinkedList<CompletedImportObject> ();

    // Called at the end of the batched jobs.  Can be used to report the result of the import
    // to the user.  This is called BEFORE import_complete is fired.
    public delegate void ImportReporter (ImportManifest manifest, BatchImportRoll import_roll);

    // Called once, when the scheduled task begins
    public signal void starting ();

    // Called repeatedly while preparing the launched BatchImport
    public signal void preparing ();

    // Called repeatedly to report the progress of the BatchImport (but only called after the
    // last "preparing" signal)
    public signal void progress (uint64 completed_bytes, uint64 total_bytes);

    // Called for each Photo or Video imported to the system. For photos, the pixbuf is
    // screen-sized and rotated. For videos, the pixbuf is a frame-grab of the first frame.
    //
    // The to_follow number is the number of queued-up sources to expect following this signal
    // in one burst.
    public signal void imported (MediaSource source, Gdk.Pixbuf pixbuf, int to_follow);

    // Called when a fatal error occurs that stops the import entirely.  Remaining jobs will be
    // failed and import_complete () is still fired.
    public signal void fatal_error (ImportResult result, string message);

    // Called when a job fails.  import_complete will also be called at the end of the batch
    public signal void import_job_failed (BatchImportResult result);

    // Called at the end of the batched jobs; this will be signalled exactly once for the batch
    public signal void import_complete (ImportManifest manifest, BatchImportRoll import_roll);

    construct {
        file_settings = new GLib.Settings (GSettingsConfigurationEngine.FILES_PREFS_SCHEMA_NAME);
    }

    public BatchImport (Gee.Iterable<BatchImportJob> jobs, string name, ImportReporter? reporter,
                        Gee.ArrayList<BatchImportJob>? prefailed = null,
                        Gee.ArrayList<BatchImportJob>? pre_already_imported = null,
                        Cancellable? cancellable = null, BatchImportRoll? import_roll = null,
                        ImportManifest? skip_manifest = null) {
        this.jobs = jobs;
        this.name = name;
        this.reporter = reporter;
        this.manifest = new ImportManifest (prefailed, pre_already_imported);
        this.cancellable = (cancellable != null) ? cancellable : new Cancellable ();
        this.import_roll = import_roll != null ? import_roll : new BatchImportRoll ();

        if (skip_manifest != null) {
            skipset = new Gee.HashSet<File> (file_hash, file_equal);
            foreach (MediaSource source in skip_manifest.imported) {
                skipset.add (source.get_file ());
            }
        }

        // watch for user exit in the application
        ((Photos.Application) GLib.Application.get_default ()).exiting.connect (user_halt);

        // Use a timer to report imported photos to observers
        Timeout.add (DISPLAY_QUEUE_TIMER_MSEC, display_imported_timer);
    }

    ~BatchImport () {
#if TRACE_DTORS
        debug ("DTOR: BatchImport (%s)", name);
#endif
        ((Photos.Application) GLib.Application.get_default ()).exiting.disconnect (user_halt);
    }

    public string get_name () {
        return name;
    }

    public void user_halt () {
        cancellable.cancel ();
    }

    public bool get_untrash_duplicates () {
        return untrash_duplicates;
    }

    public void set_untrash_duplicates (bool untrash_duplicates) {
        this.untrash_duplicates = untrash_duplicates;
    }

    public bool get_mark_duplicates_online () {
        return mark_duplicates_online;
    }

    public void set_mark_duplicates_online (bool mark_duplicates_online) {
        this.mark_duplicates_online = mark_duplicates_online;
    }

    private void log_status (string where) {
#if TRACE_IMPORT
        debug ("%s: to_perform=%d completed=%d ready_files=%d ready_thumbnails=%d display_queue=%d ready_sources=%d",
               where, file_imports_to_perform, file_imports_completed, ready_files.size,
               ready_thumbnails.size, display_imported_queue.size, ready_sources.size);
        debug ("%s workers: feeder=%d import=%d", where, feeder_workers.get_pending_job_count (),
               import_workers.get_pending_job_count ());
#endif
    }

    private bool report_failure (BatchImportResult import_result) {
        bool proceed = true;

        manifest.add_result (import_result);

        if (import_result.result != ImportResult.SUCCESS) {
            import_job_failed (import_result);

            if (import_result.file != null && !import_result.result.is_abort ()) {
                uint64 filesize = 0;
                try {
                    // A BatchImportResult file is guaranteed to be a single file
                    filesize = query_total_file_size (import_result.file);
                } catch (Error err) {
                    warning ("Unable to query file size of %s: %s", import_result.file.get_path (),
                             err.message);
                }

                report_progress (filesize);
            }
        }

        // fire this signal only once, and only on non-user aborts
        if (import_result.result.is_nonuser_abort () && proceed) {
            fatal_error (import_result.result, import_result.errmsg);
            proceed = false;
        }

        return proceed;
    }

    private void report_progress (uint64 increment_of_progress) {
        completed_bytes += increment_of_progress;

        // only report "progress" if progress has been made (and enough time has progressed),
        // otherwise still preparing
        if (completed_bytes == 0) {
            int64 now = now_ms ();
            if (now - last_preparing_ms > 250) {
                last_preparing_ms = now;
                preparing ();
            }
        } else if (increment_of_progress > 0) {
            int64 now = now_ms ();
            if (now - last_preparing_ms > 250) {
                last_preparing_ms = now;
                progress (completed_bytes, total_bytes);
            }
        }
    }

    private bool report_failures (BackgroundImportJob background_job) {
        bool proceed = true;

        foreach (BatchImportResult import_result in background_job.failed) {
            if (!report_failure (import_result))
                proceed = false;
        }

        return proceed;
    }

    private void report_completed (string where) {
        if (completed)
            error ("Attempted to complete already-completed import: %s", where);

        completed = true;

        flush_ready_sources ();

        log_status ("Import completed: %s".printf (where));

        // report completed to the reporter (called prior to the "import_complete" signal)
        if (reporter != null)
            reporter (manifest, import_roll);

        import_complete (manifest, import_roll);
    }

    // This should be called whenever a file's import process is complete, successful or otherwise
    private void file_import_complete () {
        // mark this job as completed
        file_imports_completed++;
        if (file_imports_to_perform != -1)
            assert (file_imports_completed <= file_imports_to_perform);

        // because notifications can come in after completions, have to watch if this is the
        // last file
        if (file_imports_to_perform != -1 && file_imports_completed == file_imports_to_perform)
            report_completed ("completed preparing files, all outstanding imports completed");
    }

    public void schedule () requires (scheduled == false) {
        scheduled = true;

        starting ();

        // fire off a background job to generate all FileToPrepare work
        feeder_workers.enqueue (new WorkSniffer (this, jobs, on_work_sniffed_out, cancellable,
                                on_sniffer_cancelled, skipset));
        throbber_id = Timeout.add (WORK_SNIFFER_THROBBER_MSEC, on_sniffer_working);
    }

    //
    // WorkSniffer stage
    //

    private bool on_sniffer_working () {
        report_progress (0);

        return true;
    }

    private void on_work_sniffed_out (BackgroundJob j) requires (!completed) {
        WorkSniffer sniffer = (WorkSniffer) j;

        log_status ("on_work_sniffed_out");

        if (!report_failures (sniffer) || sniffer.files_to_prepare.size == 0) {
            report_completed ("work sniffed out: nothing to do");

            return;
        }

        total_bytes = sniffer.total_bytes;

        // submit single background job to go out and prepare all the files, reporting back when/if
        // they're ready for import; this is important because gPhoto can't handle multiple accesses
        // to a camera without fat locking, and it's just not worth it.  Serializing the imports
        // also means the user sees the photos coming in in (roughly) the order they selected them
        // on the screen
        PrepareFilesJob prepare_files_job = new PrepareFilesJob (this, sniffer.files_to_prepare,
                on_file_prepared, on_files_prepared, cancellable, on_file_prepare_cancelled);

        feeder_workers.enqueue (prepare_files_job);

        if (throbber_id > 0) {
            Source.remove (throbber_id);
            throbber_id = 0;
        }
    }

    private void on_sniffer_cancelled (BackgroundJob j) requires (!completed) {
        WorkSniffer sniffer = (WorkSniffer) j;

        log_status ("on_sniffer_cancelled");

        report_failures (sniffer);
        report_completed ("work sniffer cancelled");

        if (throbber_id > 0) {
            Source.remove (throbber_id);
            throbber_id = 0;
        }
    }

    //
    // PrepareFiles stage
    //

    private void flush_import_jobs () {
        // flush ready thumbnails before ready files because PreparedFileImportJob is more intense
        // than ThumbnailWriterJob; reversing this order causes work to back up in ready_thumbnails
        // and takes longer for the user to see progress (which is only reported after the thumbnail
        // has been written)
        while (ready_thumbnails.size > 0 && import_workers.get_pending_job_count () < max_outstanding_import_jobs) {
            import_workers.enqueue (new ThumbnailWriterJob (this, ready_thumbnails.remove_at (0),
                                    on_thumbnail_writer_completed, cancellable, on_thumbnail_writer_cancelled));
        }

        while (ready_files.size > 0 && import_workers.get_pending_job_count () < max_outstanding_import_jobs) {
            import_workers.enqueue (new PreparedFileImportJob (this, ready_files.remove_at (0),
                                    import_roll.import_id, on_import_files_completed, cancellable,
                                    on_import_files_cancelled));
        }
    }

    // This checks for duplicates in the current import batch, which may not already be in the
    // library and therefore not detected there.
    private File? get_in_current_import (PreparedFile prepared_file) {
#if !NO_DUPE_DETECTION
        if (prepared_file.full_md5 != null
                && imported_full_md5_table.has_key (prepared_file.full_md5)) {

            return imported_full_md5_table.get (prepared_file.full_md5);
        }

        // add for next one
        if (prepared_file.full_md5 != null)
            imported_full_md5_table.set (prepared_file.full_md5, prepared_file.file);
#endif
        return null;
    }

    // Called when a cluster of files are located and deemed proper for import by PrepareFiledJob
    private void on_file_prepared (BackgroundJob j, NotificationObject? user) requires (!completed) {
        PreparedFileCluster cluster = (PreparedFileCluster) user;

        log_status ("on_file_prepared (%d files)".printf (cluster.list.size));

        process_prepared_files.begin (cluster.list);
    }

    // TODO: This logic can be cleaned up.  Attempt to remove all calls to
    // the database, as it's a blocking call (use in-memory lookups whenever possible)
    private async void process_prepared_files (Gee.List<PreparedFile> list) {
        foreach (PreparedFile prepared_file in list) {
            Idle.add (process_prepared_files.callback);
            yield;

            BatchImportResult import_result = null;

            // first check if file is already registered as a media object

            LibraryPhotoSourceCollection.State photo_state;
            LibraryPhoto? photo = LibraryPhoto.global.get_state_by_file (prepared_file.file,
                                  out photo_state);
            if (photo != null) {
                switch (photo_state) {
                case LibraryPhotoSourceCollection.State.ONLINE:
                case LibraryPhotoSourceCollection.State.OFFLINE:
                case LibraryPhotoSourceCollection.State.EDITABLE:
                case LibraryPhotoSourceCollection.State.DEVELOPER:
                    import_result = new BatchImportResult (prepared_file.job, prepared_file.file,
                                                           prepared_file.file.get_path (), prepared_file.file.get_path (),
                                                           DuplicatedFile.create_from_file (photo.get_master_file ()),
                                                           ImportResult.PHOTO_EXISTS);

                    if (photo_state == LibraryPhotoSourceCollection.State.OFFLINE)
                        photo.mark_online ();
                    break;

                case LibraryPhotoSourceCollection.State.TRASH:
                    // let the code below deal with it
                    break;

                default:
                    error ("Unknown LibraryPhotoSourceCollection state: %s", photo_state.to_string ());
                }
            }

            if (import_result != null) {
                report_failure (import_result);
                file_import_complete ();

                continue;
            }

            VideoSourceCollection.State video_state;
            Video? video = Video.global.get_state_by_file (prepared_file.file, out video_state);
            if (video != null) {
                switch (video_state) {
                case VideoSourceCollection.State.ONLINE:
                case VideoSourceCollection.State.OFFLINE:
                    import_result = new BatchImportResult (prepared_file.job, prepared_file.file,
                                                           prepared_file.file.get_path (), prepared_file.file.get_path (),
                                                           DuplicatedFile.create_from_file (video.get_master_file ()),
                                                           ImportResult.PHOTO_EXISTS);

                    if (video_state == VideoSourceCollection.State.OFFLINE)
                        video.mark_online ();
                    break;

                case VideoSourceCollection.State.TRASH:
                    // let the code below deal with it
                    break;

                default:
                    error ("Unknown VideoSourceCollection state: %s", video_state.to_string ());
                }
            }

            if (import_result != null) {
                report_failure (import_result);
                file_import_complete ();

                continue;
            }

            // now check if the file is a duplicate

            if (prepared_file.is_video && Video.is_duplicate (prepared_file.file, prepared_file.full_md5)) {
                VideoID[] duplicate_ids =
                    VideoTable.get_instance ().get_duplicate_ids (prepared_file.file,
                            prepared_file.full_md5);
                assert (duplicate_ids.length > 0);

                DuplicatedFile? duplicated_file =
                    DuplicatedFile.create_from_video_id (duplicate_ids[0]);

                ImportResult result_code = ImportResult.PHOTO_EXISTS;
                if (mark_duplicates_online) {
                    Video? dupe_video =
                        (Video) Video.global.get_offline_bin ().fetch_by_master_file (prepared_file.file);
                    if (dupe_video == null)
                        dupe_video = (Video) Video.global.get_offline_bin ().fetch_by_md5 (prepared_file.full_md5);

                    if (dupe_video != null) {
                        debug ("duplicate video found offline, marking as online: %s",
                               prepared_file.file.get_path ());

                        dupe_video.set_master_file (prepared_file.file);
                        dupe_video.mark_online ();

                        duplicated_file = null;

                        manifest.imported.add (dupe_video);
                        report_progress (dupe_video.get_filesize ());
                        file_import_complete ();

                        result_code = ImportResult.SUCCESS;
                    }
                }

                import_result = new BatchImportResult (prepared_file.job, prepared_file.file,
                                                       prepared_file.file.get_path (), prepared_file.file.get_path (), duplicated_file,
                                                       result_code);

                if (result_code == ImportResult.SUCCESS) {
                    manifest.add_result (import_result);

                    continue;
                }
            }

            if (get_in_current_import (prepared_file) != null) {
                // this looks for duplicates within the import set, since Photo.is_duplicate
                // only looks within already-imported photos for dupes
                import_result = new BatchImportResult (prepared_file.job, prepared_file.file,
                                                       prepared_file.file.get_path (), prepared_file.file.get_path (),
                                                       DuplicatedFile.create_from_file (get_in_current_import (prepared_file)),
                                                       ImportResult.PHOTO_EXISTS);
            } else if (Photo.is_duplicate (prepared_file.file, null, prepared_file.full_md5,
                                           prepared_file.file_format)) {
                if (untrash_duplicates) {
                    // If a file is being linked and has a dupe in the trash, we take it out of the trash
                    // and revert its edits.
                    photo = LibraryPhoto.global.get_trashed_by_file (prepared_file.file);

                    if (photo == null && prepared_file.full_md5 != null)
                        photo = LibraryPhoto.global.get_trashed_by_md5 (prepared_file.full_md5);

                    if (photo != null) {
                        debug ("duplicate linked photo found in trash, untrashing and removing transforms for %s",
                               prepared_file.file.get_path ());

                        photo.set_master_file (prepared_file.file);
                        photo.untrash ();
                        photo.remove_all_transformations ();
                    }
                }

                if (photo == null && mark_duplicates_online) {
                    // if a duplicate is found marked offline, make it online
                    photo = LibraryPhoto.global.get_offline_by_file (prepared_file.file);

                    if (photo == null && prepared_file.full_md5 != null)
                        photo = LibraryPhoto.global.get_offline_by_md5 (prepared_file.full_md5);

                    if (photo != null) {
                        debug ("duplicate photo found marked offline, marking online: %s",
                               prepared_file.file.get_path ());

                        photo.set_master_file (prepared_file.file);
                        photo.mark_online ();
                    }
                }

                if (photo != null) {
                    import_result = new BatchImportResult (prepared_file.job, prepared_file.file,
                                                           prepared_file.file.get_path (), prepared_file.file.get_path (), null,
                                                           ImportResult.SUCCESS);

                    manifest.imported.add (photo);
                    manifest.add_result (import_result);

                    report_progress (photo.get_filesize ());
                    file_import_complete ();

                    continue;
                }

                debug ("duplicate photo detected, not importing %s", prepared_file.file.get_path ());

                PhotoID[] photo_ids =
                    PhotoTable.get_instance ().get_duplicate_ids (prepared_file.file, null,
                            prepared_file.full_md5, prepared_file.file_format);
                assert (photo_ids.length > 0);

                DuplicatedFile duplicated_file = DuplicatedFile.create_from_photo_id (photo_ids[0]);

                import_result = new BatchImportResult (prepared_file.job, prepared_file.file,
                                                       prepared_file.file.get_path (), prepared_file.file.get_path (), duplicated_file,
                                                       ImportResult.PHOTO_EXISTS);
            }

            if (import_result != null) {
                report_failure (import_result);
                file_import_complete ();

                continue;
            }

            report_progress (0);
            ready_files.add (prepared_file);
        }

        flush_import_jobs ();
    }

    private void done_preparing_files (BackgroundJob j, string caller) requires (!completed) {
        PrepareFilesJob prepare_files_job = (PrepareFilesJob) j;

        report_failures (prepare_files_job);

        // mark this job as completed and record how many file imports must finish to be complete
        file_imports_to_perform = prepare_files_job.prepared_files;
        assert (file_imports_to_perform >= file_imports_completed);

        log_status (caller);

        // this call can result in report_completed () being called, so don't call twice
        flush_import_jobs ();

        // if none prepared, then none outstanding (or will become outstanding, depending on how
        // the notifications are queued)
        if (file_imports_to_perform == 0 && !completed)
            report_completed ("no files prepared for import");
        else if (file_imports_completed == file_imports_to_perform && !completed)
            report_completed ("completed preparing files, all outstanding imports completed");
    }

    private void on_files_prepared (BackgroundJob j) {
        done_preparing_files (j, "on_files_prepared");
    }

    private void on_file_prepare_cancelled (BackgroundJob j) {
        done_preparing_files (j, "on_file_prepare_cancelled");
    }

    //
    // Files ready for import stage
    //

    private void on_import_files_completed (BackgroundJob j) requires (
                                                                !completed &&
                                                                ((PreparedFileImportJob) j).not_ready == null) {
        PreparedFileImportJob job = (PreparedFileImportJob) j;

        log_status ("on_import_files_completed");

        // // should be ready in some form
        // assert (job.not_ready == null);

        // mark failed photo
        if (job.failed != null) {
            // assert (job.failed.result != ImportResult.SUCCESS);
            if (job.failed.result == ImportResult.SUCCESS) {
                critical ("Import job failed with unexpected failed result SUCCESS");
            }

            report_failure (job.failed);
            file_import_complete ();
        }

        // resurrect ready photos before adding to database and rest of system ... this is more
        // efficient than doing them one at a time
        if (job.ready != null) {
            // assert (job.ready.batch_result.result == ImportResult.SUCCESS);
            if (job.ready.batch_result.result != ImportResult.SUCCESS) {
                critical ("Import job ready with unexpected result not SUCCESS");
            }

            Tombstone? tombstone = Tombstone.global.locate (job.ready.final_file);
            if (tombstone != null)
                Tombstone.global.resurrect (tombstone);

            // import ready photos into database
            MediaSource? source = null;
            if (job.ready.is_video) {
                job.ready.batch_result.result = Video.import_create (job.ready.video_import_params,
                                                out source);
            } else {
                job.ready.batch_result.result = LibraryPhoto.import_create (job.ready.photo_import_params,
                                                out source);
                Photo photo = source as Photo;

                if (job.ready.photo_import_params.final_associated_file != null) {
                    // Associate RAW+JPEG in database.
                    BackingPhotoRow bpr = new BackingPhotoRow ();
                    bpr.file_format = PhotoFileFormat.JFIF;
                    bpr.filepath = job.ready.photo_import_params.final_associated_file.get_path ();
                    debug ("Associating %s with sibling %s", ((Photo) source).get_file ().get_path (),
                           bpr.filepath);
                    try {
                        ((Photo) source).add_backing_photo_for_development (RawDeveloper.CAMERA, bpr);
                    } catch (Error e) {
                        warning ("Unable to associate JPEG with RAW. File: %s Error: %s",
                                 bpr.filepath, e.message);
                    }
                }

                // Set the default developer for raw photos
                if (photo.get_master_file_format () == PhotoFileFormat.RAW) {
                    var d = RawDeveloper.from_string (file_settings.get_string ("raw-developer-default"));
                    if (d == RawDeveloper.CAMERA && !photo.is_raw_developer_available (d))
                        d = RawDeveloper.EMBEDDED;

                    photo.set_default_raw_developer (d);
                    photo.set_raw_developer (d);
                }
            }

            if (job.ready.batch_result.result != ImportResult.SUCCESS) {
                debug ("on_import_file_completed: %s", job.ready.batch_result.result.to_string ());

                report_failure (job.ready.batch_result);
                file_import_complete ();
            } else {
                ready_thumbnails.add (new CompletedImportObject (source, job.ready.get_thumbnails (),
                                      job.ready.prepared_file.job, job.ready.batch_result));
            }
        }

        flush_import_jobs ();
    }

    private void on_import_files_cancelled (BackgroundJob j) requires (!completed) {
        // assert (!completed);

        PreparedFileImportJob job = (PreparedFileImportJob) j;

        log_status ("on_import_files_cancelled");

        if (job.not_ready != null) {
            report_failure (new BatchImportResult (job.not_ready.job, job.not_ready.file,
                                                   job.not_ready.file.get_path (), job.not_ready.file.get_path (), null,
                                                   ImportResult.USER_ABORT));
            file_import_complete ();
        }

        if (job.failed != null) {
            report_failure (job.failed);
            file_import_complete ();
        }

        if (job.ready != null) {
            report_failure (job.ready.abort ());
            file_import_complete ();
        }

        flush_import_jobs ();
    }

    //
    // ThumbnailWriter stage
    //
    // Because the LibraryPhoto has been created at this stage, any cancelled work must also
    // destroy the LibraryPhoto.
    //

    private void on_thumbnail_writer_completed (BackgroundJob j) requires (!completed) {
        // assert (!completed);

        ThumbnailWriterJob job = (ThumbnailWriterJob) j;
        CompletedImportObject completed = job.completed_import_source;

        log_status ("on_thumbnail_writer_completed");

        if (completed.batch_result.result != ImportResult.SUCCESS) {
            warning ("Failed to import %s: unable to write thumbnails (%s)",
                     completed.source.to_string (), completed.batch_result.result.to_string ());

            if (completed.source is LibraryPhoto)
                LibraryPhoto.import_failed (completed.source as LibraryPhoto);
            else if (completed.source is Video)
                Video.import_failed (completed.source as Video);

            report_failure (completed.batch_result);
            file_import_complete ();
        } else {
            manifest.imported.add (completed.source);
            manifest.add_result (completed.batch_result);

            display_imported_queue.add (completed);
        }

        flush_import_jobs ();
    }

    private void on_thumbnail_writer_cancelled (BackgroundJob j) requires (!completed) {
        // assert (!completed);

        ThumbnailWriterJob job = (ThumbnailWriterJob) j;
        CompletedImportObject completed_import_source = job.completed_import_source;

        log_status ("on_thumbnail_writer_cancelled");

        if (completed_import_source.source is LibraryPhoto)
            LibraryPhoto.import_failed (completed_import_source.source as LibraryPhoto);
        else if (completed_import_source.source is Video)
            Video.import_failed (completed_import_source.source as Video);

        report_failure (completed_import_source.batch_result);
        file_import_complete ();

        flush_import_jobs ();
    }

    //
    // Display imported sources and integrate into system
    //

    private void flush_ready_sources () {
        if (ready_sources.size == 0)
            return;

        // the user_preview and thumbnails in the CompletedImportObjects are not available at
        // this stage

        log_status ("flush_ready_sources (%d)".printf (ready_sources.size));

        var all = new Gee.ArrayList<MediaSource> ();
        var photos = new Gee.ArrayList<LibraryPhoto> ();
        var videos = new Gee.ArrayList<Video> ();
        Gee.HashMap<MediaSource, BatchImportJob> completion_list =
            new Gee.HashMap<MediaSource, BatchImportJob> ();
        foreach (CompletedImportObject completed in ready_sources) {
            all.add (completed.source);

            if (completed.source is LibraryPhoto)
                photos.add ((LibraryPhoto) completed.source);
            else if (completed.source is Video)
                videos.add ((Video) completed.source);

            completion_list.set (completed.source, completed.original_job);
        }

        MediaCollectionRegistry.get_instance ().begin_transaction_on_all ();
        Event.global.freeze_notifications ();
        Tag.global.freeze_notifications ();

        LibraryPhoto.global.import_many (photos);
        Video.global.import_many (videos);

        // allow the BatchImportJob to perform final work on the MediaSource
        foreach (MediaSource media in completion_list.keys) {
            try {
                completion_list.get (media).complete (media, import_roll);
            } catch (Error err) {
                warning ("Completion error when finalizing import of %s: %s", media.to_string (),
                         err.message);
            }
        }

        // generate events for MediaSources not yet assigned
        Event.generate_many_events (all, import_roll.generated_events);

        Tag.global.thaw_notifications ();
        Event.global.thaw_notifications ();
        MediaCollectionRegistry.get_instance ().commit_transaction_on_all ();

        ready_sources.clear ();
    }

    // This is called throughout the import process to notify watchers of imported photos in such
    // a way that the GTK event queue gets a chance to operate.
    private bool display_imported_timer () {
        if (display_imported_queue.size == 0)
            return !completed;

        if (cancellable.is_cancelled ())
            debug ("Importing %d photos at once", display_imported_queue.size);

        log_status ("display_imported_timer");

        // only display one at a time, so the user can see them come into the library in order.
        // however, if the queue backs up to the hysteresis point (currently defined as more than
        // 3 seconds wait for the last photo on the queue), then begin doing them in increasingly
        // larger chunks, to stop the queue from growing and then to get ahead of the other
        // import cycles.
        //
        // if cancelled, want to do as many as possible, but want to relinquish the thread to
        // keep the system active
        int total = 1;
        if (!cancellable.is_cancelled ()) {
            if (display_imported_queue.size > DISPLAY_QUEUE_HYSTERESIS_OVERFLOW)
                total =
                    1 << ((display_imported_queue.size / DISPLAY_QUEUE_HYSTERESIS_OVERFLOW) + 2).clamp (0, 16);
        } else {
            // do in overflow-sized chunks
            total = DISPLAY_QUEUE_HYSTERESIS_OVERFLOW;
        }

        total = int.min (total, display_imported_queue.size);

#if TRACE_IMPORT
        if (total > 1) {
            debug ("DISPLAY IMPORT QUEUE: hysteresis, dumping %d/%d media sources", total,
                   display_imported_queue.size);
        }
#endif

        // post-decrement because the 0-based total is used when firing "imported"
        while (total-- > 0) {
            CompletedImportObject completed_object = display_imported_queue.remove_at (0);

            // stash preview for reporting progress
            Gdk.Pixbuf user_preview = completed_object.user_preview;

            // expensive pixbufs no longer needed
            completed_object.user_preview = null;
            completed_object.thumbnails = null;

            // Stage the number of ready media objects to incorporate into the system rather than
            // doing them one at a time, to keep the UI thread responsive.
            // NOTE: completed_object must be added prior to file_import_complete ()
            ready_sources.add (completed_object);

            imported (completed_object.source, user_preview, total);
            report_progress (completed_object.source.get_filesize ());
            file_import_complete ();
        }

        if (ready_sources.size >= READY_SOURCES_COUNT_OVERFLOW || cancellable.is_cancelled ())
            flush_ready_sources ();

        return true;
    }
} /* class BatchImport */
