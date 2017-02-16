/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary  LLC. (https://launchpad.net/pantheon-photos)
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
    private Gtk.Builder builder;
    private Gtk.FileChooserButton library_dir_button;
    private string? lib_dir = null;
    private Gtk.Switch lowercase;
    private Gtk.Button close_button;
    private Plugins.ManifestWidgetMediator plugins_mediator = new Plugins.ManifestWidgetMediator ();
    private Gtk.ComboBoxText default_raw_developer_combo;

    private PreferencesDialog () {
        builder = AppWindow.create_builder ();

        // Preferences dialog window settings
        dialog = new Gtk.Dialog ();
        dialog.width_request = 450;
        dialog.resizable = false;
        dialog.deletable = false;
        dialog.delete_event.connect (on_delete);
        dialog.map_event.connect (map_event_handler);
        dialog.set_parent_window (AppWindow.get_instance ().get_parent_window ());

        // Create our stack container and load in each preference container from shotwell.ui
        Gtk.Stack container = new Gtk.Stack ();
        container.expand = true;
        container.add_titled (builder.get_object ("preferences_library") as Gtk.Box, "library", _ ("Library"));
        container.add_titled (builder.get_object ("preferences_plugins") as Gtk.Box, "plugins", _ ("Plugins"));

        Gtk.StackSwitcher switcher = new Gtk.StackSwitcher ();
        switcher.stack = container;
        switcher.expand = true;
        switcher.halign = Gtk.Align.CENTER;
        switcher.margin_bottom = 6;
        
        // Add the switcher, stack container and button container to the window
        Gtk.Box content = dialog.get_content_area () as Gtk.Box;
        content.margin_bottom = 6;
        content.margin_start = 6;
        content.margin_end = 6;
        content.add (switcher);
        content.add (container);

        // Add close button to window
        close_button = new Gtk.Button.with_mnemonic (_ ("_Close"));
        close_button.clicked.connect (on_close);

        Gtk.Box button_container = dialog.get_action_area () as Gtk.Box;
        button_container.add (close_button);

        library_dir_button = builder.get_object ("library_dir_button") as Gtk.FileChooserButton;

        close_button = builder.get_object ("close_button") as Gtk.Button;

        lowercase = builder.get_object ("lowercase") as Gtk.Switch;
        lowercase.notify["active"].connect (on_lowercase_toggled);

        Gtk.Bin plugin_manifest_container = builder.get_object ("plugin-manifest-bin") as Gtk.Bin;
        plugin_manifest_container.add (plugins_mediator.widget);

        populate_preference_options ();


        Gtk.Switch auto_import_button = builder.get_object ("autoimport") as Gtk.Switch;
        auto_import_button.set_active (Config.Facade.get_instance ().get_auto_import_from_library ());

        Gtk.Switch commit_metadata_button = builder.get_object ("write_metadata") as Gtk.Switch;
        commit_metadata_button.set_active (Config.Facade.get_instance ().get_commit_metadata_to_masters ());

        default_raw_developer_combo = builder.get_object ("default_raw_developer") as Gtk.ComboBoxText;
        default_raw_developer_combo.append_text (RawDeveloper.CAMERA.get_label ());
        default_raw_developer_combo.append_text (RawDeveloper.SHOTWELL.get_label ());
        set_raw_developer_combo (Config.Facade.get_instance ().get_default_raw_developer ());
        default_raw_developer_combo.changed.connect (on_default_raw_developer_changed);
    }

    public void populate_preference_options () {

        lowercase.set_active (Config.Facade.get_instance ().get_use_lowercase_filenames ());
    }

    public static void show () {
        if (preferences_dialog == null)
            preferences_dialog = new PreferencesDialog ();

        preferences_dialog.populate_preference_options ();
        preferences_dialog.dialog.show_all ();
        preferences_dialog.library_dir_button.set_current_folder (AppDirs.get_import_dir ().get_path ());

        // Ticket #3001: Cause the dialog to become active if the user chooses 'Preferences'
        // from the menus a second time.
        preferences_dialog.dialog.present ();
    }

    // For items that should only be committed when the dialog is closed, not as soon as the change
    // is made.
    private void commit_on_close () {

        Gtk.Switch? autoimport = builder.get_object ("autoimport") as Gtk.Switch;
        if (autoimport != null)
            Config.Facade.get_instance ().set_auto_import_from_library (autoimport.active);

        Gtk.Switch? commit_metadata = builder.get_object ("write_metadata") as Gtk.Switch;
        if (commit_metadata != null)
            Config.Facade.get_instance ().set_commit_metadata_to_masters (commit_metadata.active);

        if (lib_dir != null)
            AppDirs.set_import_dir (lib_dir);

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
        Config.Facade.get_instance ().set_default_raw_developer (raw_developer_from_combo ());
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

    private void on_lowercase_toggled () {
        Config.Facade.get_instance ().set_use_lowercase_filenames (lowercase.get_active ());
    }
}
