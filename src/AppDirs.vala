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

class AppDirs {
    private const string DEFAULT_DATA_DIR = "pantheon-photos";

    private static File exec_dir;
    private static File data_dir = null;
    private static File tmp_dir = null;
    private static File libexec_dir = null;

    // Because this is called prior to Debug.init (), this function cannot do any logging calls
    public static void init (string arg0) {
        File exec_file = File.new_for_path (Posix.realpath (Environment.find_program_in_path (arg0)));
        exec_dir = exec_file.get_parent ();
    }

    // Because this *may* be called prior to Debug.init (), this function cannot do any logging
    // calls
    public static void terminate () {
    }

    public static File get_home_dir () {
        return File.new_for_path (Environment.get_home_dir ());
    }

    public static File get_cache_dir () {
        return ((data_dir == null) ?
                File.new_for_path (Environment.get_user_cache_dir ()).get_child (DEFAULT_DATA_DIR) :
                data_dir);
    }

    public static void try_migrate_data () {
        File new_dir = get_data_dir ();
        File old_dir = get_home_dir ().get_child (".shotwell");
        if (new_dir.query_exists () || !old_dir.query_exists ())
            return;

        File cache_dir = get_cache_dir ();
        Posix.mode_t mask = Posix.umask (0700);
        if (!cache_dir.query_exists ()) {
            try {
                cache_dir.make_directory_with_parents (null);
            } catch (Error err) {
                AppWindow.panic (_ ("Unable to create cache directory %s: %s").printf (cache_dir.get_path (),
                                 err.message));
            }
        }
        GLib.FileUtils.rename (old_dir.get_child ("thumbs").get_path (), cache_dir.get_child ("thumbs").get_path ());

        if (!new_dir.get_parent ().query_exists ()) {
            try {
                new_dir.get_parent ().make_directory_with_parents (null);
            } catch (Error err) {
                AppWindow.panic (_ ("Unable to create data directory %s: %s").printf (new_dir.get_parent ().get_path (),
                                 err.message));
            }
        }
        GLib.FileUtils.rename (old_dir.get_path (), new_dir.get_path ());
        GLib.FileUtils.chmod (new_dir.get_path (), 0700);

        Posix.umask (mask);
    }

    // This can only be called once, and it better be called at startup
    public static void set_data_dir (string user_data_dir) requires (!is_string_empty (user_data_dir)) {
        assert (data_dir == null);

        // fix up to absolute path
        string path = strip_pretty_path (user_data_dir);
        if (!Path.is_absolute (path))
            data_dir = get_home_dir ().get_child (path);
        else
            data_dir = File.new_for_path (path);

        message ("Setting private data directory to %s", data_dir.get_path ());
    }

    public static void verify_data_dir () {
        File data_dir = get_data_dir ();
        try {
            if (!data_dir.query_exists (null))
                data_dir.make_directory_with_parents (null);
        } catch (Error err) {
            AppWindow.panic (_ ("Unable to create data directory %s: %s").printf (data_dir.get_path (),
                             err.message));
        }
    }

    public static void verify_cache_dir () {
        File cache_dir = get_cache_dir ();
        try {
            if (!cache_dir.query_exists (null))
                cache_dir.make_directory_with_parents (null);
        } catch (Error err) {
            AppWindow.panic (_ ("Unable to create cache directory %s: %s").printf (cache_dir.get_path (),
                             err.message));
        }
    }

    /**
     * @brief Returns the build directory if not installed yet, or a path
     * to where any helper applets we need will live if installed.
     */
    public static File get_libexec_dir () {
        if (libexec_dir == null) {
            if (get_install_dir () == null) {
                // not installed yet - use wherever we were run from
                libexec_dir = get_exec_dir ();
            } else {
                libexec_dir = File.new_for_path (Resources.LIBEXECDIR);
            }
        }

        return libexec_dir;
    }

    // Return the directory in which Shotwell is installed, or null if uninstalled.
    public static File? get_install_dir () {
        return get_sys_install_dir (exec_dir);
    }

    public static File get_data_dir () {
        return (data_dir == null) ? File.new_for_path (Environment.get_user_data_dir ()).get_child (DEFAULT_DATA_DIR) : data_dir;
    }

    // The "import directory" is the same as the library directory, and are often used
    // interchangeably throughout the code.
    public static File get_import_dir () {
        string path = Config.Facade.get_instance ().get_import_dir ();
        if (!is_string_empty (path)) {
            // tilde -> home directory
            path = strip_pretty_path (path);

            // if non-empty and relative, make it relative to the user's home directory
            if (!Path.is_absolute (path))
                return get_home_dir ().get_child (path);

            // non-empty and absolute, it's golden
            return File.new_for_path (path);
        }

        // Empty path, use XDG Pictures directory
        path = Environment.get_user_special_dir (UserDirectory.PICTURES);
        if (!is_string_empty (path))
            return File.new_for_path (path);

        // If XDG yarfed, use ~/Pictures
        return get_home_dir ().get_child (_ ("Pictures"));
    }

    // Library folder + photo folder, based on user's preferred directory pattern.
    public static File get_baked_import_dir (time_t tm) {
        string? pattern = Config.Facade.get_instance ().get_directory_pattern ();
        if (is_string_empty (pattern))
            pattern = Config.Facade.get_instance ().get_directory_pattern_custom ();
        if (is_string_empty (pattern))
            pattern = "%Y" + Path.DIR_SEPARATOR_S + "%m" + Path.DIR_SEPARATOR_S + "%d"; // default

        DateTime date = new DateTime.from_unix_local (tm);
        return File.new_for_path (get_import_dir ().get_path () + Path.DIR_SEPARATOR_S + date.format (pattern));
    }

    // Returns true if the File is in or is equal to the library/import directory.
    public static bool is_in_import_dir (File file) {
        File import_dir = get_import_dir ();

        return file.has_prefix (import_dir) || file.equal (import_dir);
    }

    public static void set_import_dir (string path) {
        Config.Facade.get_instance ().set_import_dir (path);
    }

    public static File get_exec_dir () {
        return exec_dir;
    }

    public static File get_temp_dir () {
        if (tmp_dir == null) {
            tmp_dir = File.new_for_path (DirUtils.mkdtemp (Environment.get_tmp_dir () + "/pantheon-photos-XXXXXX"));

            try {
                if (!tmp_dir.query_exists (null))
                    tmp_dir.make_directory_with_parents (null);
            } catch (Error err) {
                AppWindow.panic (_ ("Unable to create temporary directory %s: %s").printf (
                                     tmp_dir.get_path (), err.message));
            }
        }

        return tmp_dir;
    }

    public static File get_data_subdir (string name, string? subname = null) {
        File subdir = get_data_dir ().get_child (name);
        if (subname != null)
            subdir = subdir.get_child (subname);

        try {
            if (!subdir.query_exists (null))
                subdir.make_directory_with_parents (null);
        } catch (Error err) {
            AppWindow.panic (_ ("Unable to create data subdirectory %s: %s").printf (subdir.get_path (),
                             err.message));
        }

        return subdir;
    }

    public static File get_cache_subdir (string name, string? subname = null) {
        File subdir = get_cache_dir ().get_child (name);
        if (subname != null)
            subdir = subdir.get_child (subname);

        try {
            if (!subdir.query_exists (null))
                subdir.make_directory_with_parents (null);
        } catch (Error err) {
            AppWindow.panic (_ ("Unable to create data subdirectory %s: %s").printf (subdir.get_path (),
                             err.message));
        }

        return subdir;
    }

    public static File get_resources_dir () {
        File? install_dir = get_install_dir ();

        return (install_dir != null) ? install_dir.get_child ("share").get_child ("pantheon-photos")
               : get_exec_dir ();
    }

    public static File get_lib_dir () {
        File? install_dir = get_install_dir ();

        return (install_dir != null) ? install_dir.get_child (Resources.LIB).get_child ("pantheon-photos")
               : get_exec_dir ();
    }

    public static File get_system_plugins_dir () {
        return get_lib_dir ().get_child ("plugins");
    }

    public static File get_user_plugins_dir () {
        return get_home_dir ().get_child (".gnome2").get_child ("pantheon-photos").get_child ("plugins");
    }

    public static File get_thumbnailer_bin () {
        const string filename = "video-thumbnailer";
        File f = File.new_for_path (AppDirs.get_libexec_dir ().get_path () + "/thumbnailer/" + filename);
        if (!f.query_exists ()) {
            // If we're running installed.
            f = File.new_for_path (AppDirs.get_libexec_dir ().get_path () + "/" + filename);
        }
        return f;
    }
}

