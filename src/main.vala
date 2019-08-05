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

enum ShotwellCommand {
    // user-defined commands must be positive ints
    MOUNTED_CAMERA = 1
}

private Timer startup_timer = null;
private bool was_already_running = false;
public const string TRANSLATABLE = "translatable";

void library_exec (string[] mounts) {
    was_already_running = Application.app_get_is_remote ();

    if (was_already_running) {
        // Send attached cameras out to the primary instance.
        // The primary instance will get a 'command-line' signal with mounts[]
        // as an argument, and an 'activate', which will present the window.
        //
        // This will also take care of killing us when it sees that another
        // instance was already registered.
        Application.present_primary_instance ();
        Application.send_to_primary_instance (mounts);
        return;
    }

    // preconfigure units
    Db.preconfigure (AppDirs.get_data_subdir ("data").get_child ("photo.db"));

    // initialize units
    try {
        Library.app_init ();
    } catch (Error err) {
        AppWindow.panic (err.message);

        return;
    }

    // validate the databases prior to using them
    message ("Verifying database …");
    string error_title = null;
    string error_message = null;
    string app_version;
    int schema_version;
    Db.VerifyResult result = Db.verify_database (out app_version, out schema_version);
    switch (result) {
        case Db.VerifyResult.OK:
            // do nothing; no problems
            break;
        case Db.VerifyResult.FUTURE_VERSION:
            error_title = _("Your Photo Library Is Not Compatible With This Version of Photos");
            error_message =  _("It appears it was created by Photos %s (schema %d). This version is %s (schema %d). Please use the latest version of Photos.").printf (app_version, schema_version, Resources.APP_VERSION, DatabaseTable.SCHEMA_VERSION);
            break;
        case Db.VerifyResult.UPGRADE_ERROR:
            error_title = _("Photos Was Unable To Upgrade Your Photo Library From Version %s (Schema %d) to %s (Schema %d)").printf (app_version, schema_version, Resources.APP_VERSION, DatabaseTable.SCHEMA_VERSION);
            error_message = _("For more information please check the Photos Wiki at %s").printf (Resources.WIKI_URL);
            break;
        case Db.VerifyResult.NO_UPGRADE_AVAILABLE:
            error_title = _("Your Photo Library Is Not Compatible With This Version of Photos");
            error_message = _("It appears it was created by Photos %s (schema %d). This version is %s (schema %d). Please clear your library by deleting %s and re-import your photos.").printf (app_version, schema_version, Resources.APP_VERSION, DatabaseTable.SCHEMA_VERSION, AppDirs.get_data_dir ().get_path ());
            break;
        default:
            error_title = _("Unknown Error Attempting To Verify Photos' Database");
            error_message = result.to_string ();
            break;
    }

    if (error_title != null) {
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            error_title,
            error_message,
            "dialog-error"
        );
        dialog.run ();
        dialog.destroy ();

        DatabaseTable.terminate ();

        return;
    }

    Upgrades.init ();

    ProgressDialog progress_dialog = null;
    AggregateProgressMonitor aggregate_monitor = null;
    ProgressMonitor monitor = null;

    if (!CommandlineOptions.no_startup_progress) {
        // only throw up a startup progress dialog if over a reasonable amount of objects ... multiplying
        // photos by two because there's two heavy-duty operations on them: creating the LibraryPhoto
        // objects and then populating the initial page with them.
        uint64 grand_total = PhotoTable.get_instance ().get_row_count ()
                             + EventTable.get_instance ().get_row_count ()
                             + TagTable.get_instance ().get_row_count ()
                             + VideoTable.get_instance ().get_row_count ()
                             + Upgrades.get_instance ().get_step_count ();
        if (grand_total > 5000) {
            progress_dialog = new ProgressDialog (null, _ ("Loading Photos"));
            progress_dialog.update_display_every (100);
            progress_dialog.set_minimum_on_screen_time_msec (250);

            aggregate_monitor = new AggregateProgressMonitor (grand_total, progress_dialog.monitor);
            monitor = aggregate_monitor.monitor;
        }
    }

    ThumbnailCache.init ();
    Tombstone.init ();

    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("LibraryPhoto.init");
    LibraryPhoto.init (monitor);
    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("Video.init");
    Video.init (monitor);
    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("Upgrades.execute");
    Upgrades.get_instance ().execute ();

    LibraryMonitorPool.init ();
    MediaCollectionRegistry.init ();
    MediaCollectionRegistry registry = MediaCollectionRegistry.get_instance ();
    registry.register_collection (LibraryPhoto.global);
    registry.register_collection (Video.global);

    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("Event.init");
    Event.init (monitor);
    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("Tag.init");
    Tag.init (monitor);

    MetadataWriter.init ();

    Application.get_instance ().init_done ();

    // create main library application window
    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("LibraryWindow");
    LibraryWindow library_window = new LibraryWindow (monitor);

    if (aggregate_monitor != null)
        aggregate_monitor.next_step ("done");

    // destroy and tear down everything ... no need for them to stick around the lifetime of the
    // application

    monitor = null;
    aggregate_monitor = null;
    if (progress_dialog != null)
        progress_dialog.destroy ();
    progress_dialog = null;

    // report mount points
    foreach (string mount in mounts)
        library_window.mounted_camera_shell_notification (mount, true);

    library_window.show_all ();

    WelcomeServiceEntry[] selected_import_entries = new WelcomeServiceEntry[0];

    if (selected_import_entries.length > 0) {
        do_external_import = true;
        foreach (WelcomeServiceEntry entry in selected_import_entries)
            entry.execute ();
    }
    if (do_system_pictures_import) {
        /*  Do the system import even if other plugins have run as some plugins may not
            as some plugins may not import pictures from the system folder.
         */
        run_system_pictures_import ();
    }

    debug ("%lf seconds to Gtk.main ()", startup_timer.elapsed ());

    Application.get_instance ().start ();

    MetadataWriter.terminate ();
    Tag.terminate ();
    Event.terminate ();
    LibraryPhoto.terminate ();
    LibraryMonitorPool.terminate ();
    Tombstone.terminate ();
    ThumbnailCache.terminate ();
    Video.terminate ();
    Library.app_terminate ();
}

private bool do_system_pictures_import = false;
private bool do_external_import = false;

public void run_system_pictures_import (ImportManifest? external_exclusion_manifest = null) {
    if (!do_system_pictures_import)
        return;

    Gee.ArrayList<FileImportJob> jobs = new Gee.ArrayList<FileImportJob> ();
    jobs.add (new FileImportJob (AppDirs.get_import_dir (), false));

    LibraryWindow library_window = (LibraryWindow) AppWindow.get_instance ();

    BatchImport batch_import = new BatchImport (jobs, "startup_import",
            report_system_pictures_import, null, null, null, null, external_exclusion_manifest);
    library_window.enqueue_batch_import (batch_import, true);

    library_window.switch_to_import_queue_page ();
}

private void report_system_pictures_import (ImportManifest manifest, BatchImportRoll import_roll) {
    /* Don't report the manifest to the user if exteral import was done and the entire manifest
       is empty. An empty manifest in this case results from files that were already imported
       in the external import phase being skipped. Note that we are testing against manifest.all,
       not manifest.success; manifest.all is zero when no files were enqueued for import in the
       first place and the only way this happens is if all files were skipped -- even failed
       files are counted in manifest.all */
    if (do_external_import && (manifest.all.size == 0))
        return;

    ImportUI.report_manifest (manifest, true);
}

void editing_exec (string filename) {
    File initial_file = File.new_for_commandline_arg (filename);

    // preconfigure units
    Direct.preconfigure (initial_file);
    Db.preconfigure (null);

    // initialize units for direct-edit mode
    try {
        Direct.app_init ();
    } catch (Error err) {
        AppWindow.panic (err.message);

        return;
    }

    // TODO: At some point in the future, to support mixed-media in direct-edit mode, we will
    //       refactor DirectPhotoSourceCollection to be a MediaSourceCollection. At that point,
    //       we'll need to register DirectPhoto.global with the MediaCollectionRegistry

    DirectWindow direct_window = new DirectWindow (initial_file);
    direct_window.show_all ();

    debug ("%lf seconds to Gtk.main ()", startup_timer.elapsed ());

    Application.get_instance ().start ();

    // terminate units for direct-edit mode
    Direct.app_terminate ();
}

namespace CommandlineOptions {
    string data_dir = null;
    bool no_runtime_monitoring = false;
    bool no_startup_progress = false;
    bool show_version = false;
    bool debug_enabled = false;

    public const OptionEntry[] app_options = {
        { "datadir", 'd', 0, OptionArg.FILENAME, out data_dir, N_("Path to Photos' private data"), N_("DIRECTORY")},
        { "no-runtime-monitoring", 0, 0, OptionArg.NONE, out no_runtime_monitoring, N_("Do not monitor library directory at runtime for changes"), null},
        { "no-startup-progress", 0, 0, OptionArg.NONE, out no_startup_progress, N_("Don't display startup progress meter"), null},
        { "version", 'v', 0, OptionArg.NONE, out show_version, N_("Show the application's version"), null},
        { "debug", 'D', 0, OptionArg.NONE, out debug_enabled, N_("Show extra debugging output"), null},
        { null }
    };
}

void main (string[] args) {
    // Call AppDirs init *before* calling Gtk.init_with_args, as it will strip the
    // exec file from the array
    AppDirs.init (args[0]);

    // This has to be done before the AppWindow is created in order to ensure the XMP
    // parser is initialized in a thread-safe fashion; please see
    // http://redmine.yorba.org/issues/4120 for details.
    GExiv2.initialize ();

    // following the GIO programming guidelines at http://developer.gnome.org/gio/2.26/ch03.html,
    // set the GSETTINGS_SCHEMA_DIR environment variable to allow us to load GSettings schemas from
    // the build directory. this allows us to access local GSettings schemas without having to
    // muck with the user's XDG_... directories, which is seriously frowned upon
    if (AppDirs.get_install_dir () == null) {
        GLib.Environment.set_variable ("GSETTINGS_SCHEMA_DIR", AppDirs.get_exec_dir ().get_path () +
                                       "/misc", true);
    }

    // init GTK (valac has already called g_threads_init ())
    try {
        Gtk.init_with_args (ref args, _ ("[FILE]"), CommandlineOptions.app_options,
                            Resources.APP_GETTEXT_PACKAGE);
    } catch (Error e) {
        print (e.message + "\n");
        print (_ ("Run '%s --help' to see a full list of available command line options.\n"), args[0]);
        AppDirs.terminate ();
        return;
    }

    if (CommandlineOptions.show_version) {
        if (Resources.GIT_VERSION != null)
            print ("%s %s (%s)\n", _ (Resources.APP_TITLE), Resources.APP_VERSION, Resources.GIT_VERSION);
        else
            print ("%s %s\n", _ (Resources.APP_TITLE), Resources.APP_VERSION);

        AppDirs.terminate ();

        return;
    }

    // init debug prior to anything else (except Gtk, which it relies on, and AppDirs, which needs
    // to be set ASAP) ... since we need to know what mode we're in, examine the command-line
    // first

    // walk command-line arguments for camera mounts or filename for direct editing ... only one
    // filename supported for now, so take the first one and drop the rest ... note that URIs for
    // filenames are currently not permitted, to differentiate between mount points
    string[] mounts = new string[0];
    string filename = null;

    for (int ctr = 1; ctr < args.length; ctr++) {
        string arg = args[ctr];

        if (LibraryWindow.is_mount_uri_supported (arg)) {
            mounts += arg;
        } else if (is_string_empty (filename) && !arg.contains ("://")) {
            filename = arg;
        }
    }

    message ("Shotwell %s %s",
             is_string_empty (filename) ? Resources.APP_LIBRARY_ROLE : Resources.APP_DIRECT_ROLE,
             Resources.APP_VERSION);

    // Have a filename here?  If so, configure ourselves for direct
    // mode, otherwise, default to library mode.
    Application.init (!is_string_empty (filename));

    // set custom data directory if it's been supplied
    if (CommandlineOptions.data_dir != null)
        AppDirs.set_data_dir (CommandlineOptions.data_dir);
    else
        AppDirs.try_migrate_data ();

    // Verify the private data directory before continuing
    AppDirs.verify_data_dir ();
    AppDirs.verify_cache_dir ();

    // init internationalization with the default system locale
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain (GETTEXT_PACKAGE);

    startup_timer = new Timer ();
    startup_timer.start ();

    // set up GLib environment
    GLib.Environment.set_application_name (_ (Resources.APP_TITLE));

    // since it's possible for a mount name to be passed that's not supported (and hence an empty
    // mount list), or for nothing to be on the command-line at all, only go to direct editing if a
    // filename is spec'd
    if (is_string_empty (filename))
        library_exec (mounts);
    else
        editing_exec (filename);

    // terminate mode-inspecific modules
    Application.terminate ();
    AppDirs.terminate ();

    // Back up db on successful run so we have something to roll back to if
    // it gets corrupted in the next session.  Don't do this if another Photos
    // is open or if we're in direct mode.
    if (is_string_empty (filename) && !was_already_running) {
        string orig_path = AppDirs.get_data_subdir ("data").get_child ("photo.db").get_path ();
        string backup_path = orig_path + ".bak";
        string cmdline = "cp " + orig_path + " " + backup_path;
        Posix.system (cmdline);
        Posix.system ("sync");
    }
}
