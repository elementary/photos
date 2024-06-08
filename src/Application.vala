/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Photos.Application : Gtk.Application {
    public const string ACTION_PREFIX = "app.";
    public const string ACTION_REJECT = "action-reject";
    public const string ACTION_SET_WALLPAPER = "action-set-wallpaper";
    public const string ACTION_QUIT = "action-quit";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_REJECT, action_reject },
        { ACTION_SET_WALLPAPER, action_set_wallpaper, "s" },
        { ACTION_QUIT, quit }
    };

    public Application () {
        Object (
            application_id: "io.elementary.photos",
            flags: ApplicationFlags.HANDLES_OPEN
        );
    }

    construct {
        GLib.Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, Constants.LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (Constants.GETTEXT_PACKAGE);
    }

    protected override void startup () {
        base.startup ();

        Granite.init ();

        add_action_entries (ACTION_ENTRIES, this);

        ((SimpleAction) lookup_action (ACTION_REJECT)).set_enabled (false);
        ((SimpleAction) lookup_action (ACTION_SET_WALLPAPER)).set_enabled (false);

        set_accels_for_action("app.action-quit", {"<Control>q"});

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_icon_theme_name = "elementary";
        gtk_settings.gtk_theme_name = "io.elementary.stylesheet.grape";

        gtk_settings.gtk_application_prefer_dark_theme = (
            granite_settings.prefers_color_scheme == DARK
        );

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = (
                granite_settings.prefers_color_scheme == DARK
            );
        });
    }

    protected override void activate () {
        if (active_window != null) {
            active_window.present ();
            return;
        }

        var main_window = new Photos.MainWindow () {
            title = _("Photos")
        };
        main_window.present ();

        add_window (main_window);

        /*
        * This is very finicky. Bind size after present else set_titlebar gives us bad sizes
        * Set maximize after height/width else window is min size on unmaximize
        * Bind maximize as SET else get get bad sizes
        */
        var settings = new Settings ("io.elementary.photos");
        settings.bind ("window-height", main_window, "default-height", SettingsBindFlags.DEFAULT);
        settings.bind ("window-width", main_window, "default-width", SettingsBindFlags.DEFAULT);

        if (settings.get_boolean ("window-maximized")) {
            main_window.maximize ();
        }

        settings.bind ("window-maximized", main_window, "maximized", SettingsBindFlags.SET);
    }

    private void action_reject () {
        // Something to mark the current as rejected
    }

    private void action_set_wallpaper () {
        // Use Portal to set user wallpaper
    }

    public static int main (string[] args) {
        return new Photos.Application ().run (args);
    }
}
