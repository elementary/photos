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

private class WorkSniffer : BackgroundImportJob {
    const uint MIN_SIZE = 64; // minimum file size to consider a photo
    public Gee.List<FileToPrepare> files_to_prepare = new Gee.ArrayList<FileToPrepare> ();
    public uint64 total_bytes = 0;

    private Gee.Iterable<BatchImportJob> jobs;
    private Gee.HashSet<File>? skipset;

    public WorkSniffer (BatchImport owner, Gee.Iterable<BatchImportJob> jobs, CompletionCallback callback,
                        Cancellable cancellable, CancellationCallback cancellation, Gee.HashSet<File>? skipset = null) {
        base (owner, callback, cancellable, cancellation);

        this.jobs = jobs;
        this.skipset = skipset;
    }

    public override void execute () {
        // walk the list of jobs accumulating work for the background jobs; if submitted job
        // is a directory, recurse into the directory picking up files to import (also creating
        // work for the background jobs)
        foreach (BatchImportJob job in jobs) {
            ImportResult result = abort_check ();
            if (result != ImportResult.SUCCESS) {
                report_failure (job, null, job.get_source_identifier (), job.get_dest_identifier (),
                                result);

                continue;
            }

            try {
                sniff_job (job);
            } catch (Error err) {
                report_error (job, null, job.get_source_identifier (), job.get_dest_identifier (), err,
                              ImportResult.FILE_ERROR);
            }

            if (is_cancelled ())
                break;
        }

        // Time to handle RAW+JPEG pairs!
        // Now we build a new list of all the files (but not folders) we're
        // importing and sort it by filename.
        Gee.List<FileToPrepare> sorted = new Gee.ArrayList<FileToPrepare> ();
        foreach (FileToPrepare ftp in files_to_prepare) {
            if (!ftp.is_directory ())
                sorted.add (ftp);
        }
        sorted.sort ((a, b) => {
            FileToPrepare file_a = (FileToPrepare) a;
            FileToPrepare file_b = (FileToPrepare) b;
            string sa = file_a.get_path ();
            string sb = file_b.get_path ();
            return utf8_cs_compare (sa, sb);
        });

        // For each file, check if the current file is RAW.  If so, check the previous
        // and next files to see if they're a "plus jpeg."
        for (int i = 0; i < sorted.size; ++i) {
            string name, ext;
            FileToPrepare ftp = sorted.get (i);
            disassemble_filename (ftp.get_basename (), out name, out ext);

            if (is_string_empty (ext))
                continue;

            if (RawFileFormatProperties.get_instance ().is_recognized_extension (ext)) {
                // Got a raw file.  See if it has a pair.  If a pair is found, remove it
                // from the list and link it to the RAW file.
                if (i > 0 && is_paired (ftp, sorted.get (i - 1))) {
                    FileToPrepare associated_file = sorted.get (i - 1);
                    files_to_prepare.remove (associated_file);
                    ftp.set_associated (associated_file);
                } else if (i < sorted.size - 1 && is_paired (ftp, sorted.get (i + 1))) {
                    FileToPrepare associated_file = sorted.get (i + 1);
                    files_to_prepare.remove (associated_file);
                    ftp.set_associated (associated_file);
                }
            }
        }
    }

    // Check if a file is paired.  The raw file must be a raw photo.  A file
    // is "paired" if it has the same basename as the raw file, is in the same
    // directory, and is a JPEG.
    private bool is_paired (FileToPrepare raw, FileToPrepare maybe_paired) {
        if (raw.get_parent_path () != maybe_paired.get_parent_path ())
            return false;

        string name, ext, test_name, test_ext;
        disassemble_filename (maybe_paired.get_basename (), out test_name, out test_ext);

        if (!JfifFileFormatProperties.get_instance ().is_recognized_extension (test_ext))
            return false;

        disassemble_filename (raw.get_basename (), out name, out ext);

        return name == test_name;
    }

    private void sniff_job (BatchImportJob job) throws Error {
        // Only called by BatchImport
        // May receive either FileImportJob or CameraImportJob
        uint64 size = 0;
        File? file_or_dir = null;
        bool determined_size = job.determine_file_size (out size, out file_or_dir);
        // file_dir is always null for a CameraImportJob but FileImportJob has associated file
        // size is always zero for FileImportJob but CameraImportJob has file_size

        if (job.is_directory ()) { // false for CameraImportJob
            // safe to call job.prepare without it invoking extra I/O; this is merely a directory
            // to search
            File dir;
            bool copy_to_library;
            if (!job.prepare (out dir, out copy_to_library)) {
                report_failure (job, null, job.get_source_identifier (), job.get_dest_identifier (),
                ImportResult.FILE_ERROR);

                return;
            }

            // search_dir () will throw error if dir not directory
            try {
                search_dir (job, dir, copy_to_library);
            } catch (Error err) {
                report_error (job, dir, job.get_source_identifier (), dir.get_path (), err,
                              ImportResult.FILE_ERROR);
            }
        } else {
            // if did not get the file size (FileImportJob), do so now
            if (!determined_size) {
                size = query_total_file_size (file_or_dir, get_cancellable ());
            }

            if (size < MIN_SIZE) {
                return;
            }
            total_bytes += size;

            // job is a direct file, so no need to search, prepare it directly
            if ((file_or_dir != null) && skipset != null && skipset.contains (file_or_dir))
                return;  /* do a short-circuit return and don't enqueue if this file is to be
                            skipped */

            files_to_prepare.add (new FileToPrepare (job));
        }
    }

    public void search_dir (BatchImportJob job, File dir, bool copy_to_library) throws Error {
        FileEnumerator enumerator = dir.enumerate_children ("standard::*",
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);

        FileInfo info = null;
        while ((info = enumerator.next_file (get_cancellable ())) != null) {
            // next_file () doesn't always respect the cancellable
            if (is_cancelled ())
                break;

            File child = dir.get_child (info.get_name ());
            FileType file_type = info.get_file_type ();

            if (file_type == FileType.DIRECTORY) {
                if (info.get_name ().has_prefix ("."))
                    continue;

                try {
                    search_dir (job, child, copy_to_library);
                } catch (Error err) {
                    report_error (job, child, child.get_path (), child.get_path (), err,
                                  ImportResult.FILE_ERROR);
                }
            } else if (file_type == FileType.REGULAR) {
                if ((skipset != null) && skipset.contains (child))
                    continue; /* don't enqueue if this file is to be skipped */

                if ((Photo.is_file_image (child) && PhotoFileFormat.is_file_supported (child)) ||
                        VideoReader.is_supported_video_file (child)) {
                    total_bytes += info.get_size ();
                    files_to_prepare.add (new FileToPrepare (job, child, copy_to_library));

                    continue;
                }
            } else {
                warning ("Ignoring import of %s file type %d", child.get_path (), (int) file_type);
            }
        }
    }
}
