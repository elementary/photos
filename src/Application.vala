/*
* Copyright (c) 2010-2013 Yorba Foundation
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

public class Application : Granite.Application {
    private static Application instance = null;
    private int system_app_run_retval = 0;
    private bool direct;

    public bool debugging_enabled {
        set {
            DEBUG = value;
        }
    }

    public virtual signal void starting () {
    }

    public virtual signal void exiting (bool panicked) {
    }

    public virtual signal void init_done () {
    }

    private bool fixup_raw_thumbs = false;

    public void set_raw_thumbs_fix_required (bool should_fixup) {
        fixup_raw_thumbs = should_fixup;
    }

    public bool get_raw_thumbs_fix_required () {
        return fixup_raw_thumbs;
    }

    private bool running = false;
    private bool exiting_fired = false;

    construct {
        build_release_name = _("Photos");
        build_version = Resources.APP_VERSION;

        program_name = _(build_release_name);
        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/org/pantheon/photos/icons");
    }

    private Application (bool is_direct) {
        if (is_direct) {
            // we allow multiple instances of ourself in direct mode, so DON'T
            // attempt to be unique.  We don't request any command-line handling
            // here because this is processed elsewhere, and we don't need to handle
            // command lines from remote instances, since we don't care about them.

            exec_name = GETTEXT_PACKAGE;
            application_id = "org.pantheon.photos-direct";
            app_launcher = "org.pantheon.photos-viewer.desktop";
            program_name = _("Photo Viewer");
            Gtk.Settings.get_default().set("gtk-application-prefer-dark-theme", true);
            flags = GLib.ApplicationFlags.HANDLES_OPEN | GLib.ApplicationFlags.NON_UNIQUE;
        } else {
            // we've been invoked in library mode; set up for uniqueness and handling
            // of incoming command lines from remote instances (needed for getting
            // storage device and camera mounts).

            exec_name = GETTEXT_PACKAGE;
            application_id = "org.pantheon.photos";
            app_launcher = "org.pantheon.photos.desktop";
            program_name = _(build_release_name);
            flags = GLib.ApplicationFlags.HANDLES_OPEN | GLib.ApplicationFlags.HANDLES_COMMAND_LINE;
        }

        // GLib will assert if we don't do this...
        try {
            register ();
        } catch (Error e) {
            panic ();
        }

        direct = is_direct;

        if (!direct) {
            command_line.connect (on_command_line);
        }

        activate.connect (on_activated);
        startup.connect (on_activated);
    }

    /**
     * @brief This is a helper for library mode that should only be
     * called if we've gotten a camera mount and are _not_ the primary
     * instance.
     */
    public static void send_to_primary_instance (string[]? argv) {
        get_instance ().run (argv);
    }

    /**
     * @brief A helper for library mode that tells the primary
     * instance to bring its window to the foreground.  This
     * should only be called if we are _not_ the primary instance.
     */
    public static void present_primary_instance () {
        get_instance ().activate ();
    }

    public static bool app_get_is_remote () {
        return get_instance ().get_is_remote ();
    }

    public static bool app_get_is_direct () {
        return get_instance ().direct;
    }

    /**
     * @brief Signal handler for GApplication's 'command-line' signal.
     *
     * The most likely scenario for this to be fired is if the user
     * either tried to run us twice in library mode, or we've just gotten
     * a camera/removeable-storage mount; in either case, the remote instance
     * will trigger this and exit, and we'll need to bring the window back up...
     */
    public static void on_activated () {
        get_instance ();

        LibraryWindow lw = AppWindow.get_instance () as LibraryWindow;
        if ((lw != null) && (!app_get_is_direct ())) {
            LibraryWindow.get_app ().present ();
        }
    }

    /**
     * @brief Signal handler for GApplication's 'command-line' signal.
     *
     * Gets fired whenever a remote instance tries to run, usually
     * with an incoming camera connection.
     *
     * @note This does _not_ get called in direct-edit mode.
     */
    public static int on_command_line (ApplicationCommandLine acl) {
        string[]? argv = acl.get_arguments ();

        if (argv != null) {
            foreach (string s in argv) {
                LibraryWindow lw = AppWindow.get_instance () as LibraryWindow;
                if (lw != null) {
                    lw.mounted_camera_shell_notification (s, false);
                }
            }
        }
        on_activated ();
        return 0;
    }

    /**
     * @brief Initializes the Shotwell application object and prepares
     * it for use.
     *
     * @param is_direct Whether the application was invoked in direct
     * or in library mode; defaults to FALSE, that is, library mode.
     *
     * @note This MUST be called prior to calling get_instance (), as the
     * application needs to know what mode it was brought up in; failure to
     * call this first will lead to an assertion.
     */
    public static void init (bool is_direct = false) {
        if (instance == null)
            instance = new Application (is_direct);
    }

    public static void terminate () {
        get_instance ().exit ();
    }

    public static Application get_instance () {
        assert (instance != null);

        return instance;
    }

    public void start (string[]? argv = null) {
        if (running)
            return;

        running = true;

        starting ();

        assert (AppWindow.get_instance () != null);
        add_window (AppWindow.get_instance ());
        system_app_run_retval = run (argv);

        if (!direct) {
            command_line.disconnect (on_command_line);
        }

        activate.disconnect (on_activated);
        startup.disconnect (on_activated);

        running = false;
    }

    public void exit () {
        // only fire this once, but thanks to terminate (), it will be fired at least once (even
        // if start () is not called and "starting" is not fired)
        if (exiting_fired || !running)
            return;

        exiting_fired = true;
        exiting (false);
        release ();
    }

    // This will fire the exiting signal with panicked set to true, but only if exit () hasn't
    // already been called.  This call will immediately halt the application.
    public void panic () {
        if (!exiting_fired) {
            exiting_fired = true;
            exiting (true);
        }

        Posix.exit (1);
    }

    /**
     * @brief Allows the caller to ask for some part of the desktop session's functionality to
     * be prevented from running; wrapper for Gtk.Application.inhibit ().
     *
     * @note The return value is a 'cookie' that needs to be passed to 'uninhibit' to turn
     * off a requested inhibition and should be saved by the caller.
     */
    public uint app_inhibit (Gtk.ApplicationInhibitFlags what, string? reason = "none given") {
        return inhibit (AppWindow.get_instance (), what, reason);
    }

    /**
     * @brief Turns off a previously-requested inhibition. Wrapper for
     * Gtk.Application.uninhibit ().
     */
    public void app_uninhibit (uint cookie) {
        uninhibit (cookie);
    }

    public int get_run_return_value () {
        return system_app_run_retval;
    }
}
