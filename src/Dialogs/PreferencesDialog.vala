/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary  LLC. (https://github.com/elementary/photos)
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

public class PreferencesDialog {
    private class PathFormat {
        public PathFormat (string name, string? pattern) {
            this.name = name;
            this.pattern = pattern;
        }
        public string name;
        public string? pattern;
    }

    private static PreferencesDialog preferences_dialog;

    private Gtk.Dialog dialog;
    private Gtk.FileChooserButton library_dir_button;
    private string? lib_dir = null;
    private Gtk.ComboBoxText default_raw_developer_combo;
    private GLib.Settings file_settings;

    private PreferencesDialog () {
        file_settings = new GLib.Settings (GSettingsConfigurationEngine.FILES_PREFS_SCHEMA_NAME);

        dialog = new Gtk.Dialog ();
        dialog.width_request = 450;
        dialog.resizable = false;
        dialog.deletable = false;
        dialog.delete_event.connect (on_delete);
        dialog.map_event.connect (map_event_handler);
        dialog.set_parent_window (AppWindow.get_instance ().get_parent_window ());

        var library_header = new Granite.HeaderLabel (_("Library"));

        library_dir_button = new Gtk.FileChooserButton ("", Gtk.FileChooserAction.SELECT_FOLDER);

        var library_dir_label = new Gtk.Label.with_mnemonic (_("_Import photos to:"));
        library_dir_label.halign = Gtk.Align.END;
        library_dir_label.mnemonic_widget = library_dir_button;

        var auto_import_label = new Gtk.Label (_("Watch library for new files:"));
        auto_import_label.halign = Gtk.Align.END;

        var auto_import_switch = new Gtk.Switch ();
        auto_import_switch.halign = Gtk.Align.START;

        var lowercase_switch = new Gtk.Switch ();
        lowercase_switch.halign = Gtk.Align.START;

        var lowercase_label = new Gtk.Label.with_mnemonic (_("R_ename imported files to lowercase:"));
        lowercase_label.halign = Gtk.Align.END;
        lowercase_label.mnemonic_widget = lowercase_switch;

        var commit_metadata_switch = new Gtk.Switch ();
        commit_metadata_switch.halign = Gtk.Align.START;

        var commit_metadata_label = new Gtk.Label.with_mnemonic (_("Write _metadata to files:"));
        commit_metadata_label.halign = Gtk.Align.END;
        commit_metadata_label.mnemonic_widget = commit_metadata_switch;

        var raw_header = new Granite.HeaderLabel (_("RAW Developer"));

        default_raw_developer_combo = new Gtk.ComboBoxText ();
        default_raw_developer_combo.append_text (RawDeveloper.CAMERA.get_label ());
        default_raw_developer_combo.append_text (RawDeveloper.SHOTWELL.get_label ());
        set_raw_developer_combo (RawDeveloper.from_string (file_settings.get_string ("raw-developer-default")));
        default_raw_developer_combo.changed.connect (on_default_raw_developer_changed);

        var default_raw_developer_label = new Gtk.Label.with_mnemonic (_("De_fault:"));
        default_raw_developer_label.halign = Gtk.Align.END;
        default_raw_developer_label.mnemonic_widget = default_raw_developer_combo;

        var library_grid = new Gtk.Grid ();
        library_grid.column_spacing = 12;
        library_grid.row_spacing = 6;
        library_grid.attach (library_header, 0, 0, 2, 1);
        library_grid.attach (library_dir_label, 0, 1, 1, 1);
        library_grid.attach (library_dir_button, 1, 1, 1, 1);
        library_grid.attach (auto_import_label, 0, 2, 1, 1);
        library_grid.attach (auto_import_switch, 1, 2, 1, 1);
        library_grid.attach (lowercase_label, 0, 3, 1, 1);
        library_grid.attach (lowercase_switch, 1, 3, 1, 1);
        library_grid.attach (commit_metadata_label, 0, 4, 1, 1);
        library_grid.attach (commit_metadata_switch, 1, 4, 1, 1);
        library_grid.attach (raw_header, 0, 5, 2, 1);
        library_grid.attach (default_raw_developer_label, 0, 6, 1, 1);
        library_grid.attach (default_raw_developer_combo, 1, 6, 1, 1);

        var manifest_widget = new Plugins.ManifestWidget ();

        var stack = new Gtk.Stack ();
        stack.expand = true;
        stack.margin = 6;
        stack.add_titled (library_grid, "library", _("Library"));
        stack.add_titled (manifest_widget, "plugins", _("Plugins"));

        var switcher = new Gtk.StackSwitcher ();
        switcher.halign = Gtk.Align.CENTER;
        switcher.homogeneous = true;
        switcher.expand = true;
        switcher.margin_bottom = 6;
        switcher.stack = stack;

        var content = dialog.get_content_area () as Gtk.Box;
        content.margin = 6;
        content.margin_top = 0;
        content.add (switcher);
        content.add (stack);

        var close_button = dialog.add_button (_("_Close"), Gtk.ResponseType.CLOSE);
        ((Gtk.Button) close_button).clicked.connect (on_close);

        var file_settings = new GLib.Settings ("io.elementary.photos.preferences.files");
        file_settings.bind ("auto-import", auto_import_switch, "active", SettingsBindFlags.DEFAULT);
        file_settings.bind ("commit-metadata", commit_metadata_switch, "active", SettingsBindFlags.DEFAULT);
        file_settings.bind ("use-lowercase-filenames", lowercase_switch, "active", SettingsBindFlags.DEFAULT);
    }

    public static void show () {
        if (preferences_dialog == null) {
            preferences_dialog = new PreferencesDialog ();
        }

        preferences_dialog.dialog.show_all ();
        preferences_dialog.library_dir_button.set_current_folder (AppDirs.get_import_dir ().get_path ());

        // Ticket #3001: Cause the dialog to become active if the user chooses 'Preferences'
        // from the menus a second time.
        preferences_dialog.dialog.present ();
    }

    private void commit_on_close () {
        if (lib_dir != null) {
            AppDirs.set_import_dir (lib_dir);
        }
    }

    private bool on_delete () {
        commit_on_close ();
        return dialog.hide_on_delete (); //prevent widgets from getting destroyed
    }

    private void on_close () {
        dialog.hide ();
        commit_on_close ();
    }

    private RawDeveloper raw_developer_from_combo () {
        if (default_raw_developer_combo.get_active () == 0)
            return RawDeveloper.CAMERA;
        return RawDeveloper.SHOTWELL;
    }

    private void set_raw_developer_combo (RawDeveloper d) {
        if (d == RawDeveloper.CAMERA)
            default_raw_developer_combo.set_active (0);
        else
            default_raw_developer_combo.set_active (1);
    }

    private void on_default_raw_developer_changed () {
        file_settings.set_string ("raw-developer-default", raw_developer_from_combo ().to_string ());
    }

    private void on_current_folder_changed () {
        lib_dir = library_dir_button.get_filename ();
    }

    private bool map_event_handler () {
        // Set the signal for the lib dir button after the dialog is displayed,
        // because the FileChooserButton has a nasty habbit of selecting a
        // different folder when displayed if the provided path doesn't exist.
        // See ticket #3000 for more info.
        library_dir_button.current_folder_changed.connect (on_current_folder_changed);
        return true;
    }
}
