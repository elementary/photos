/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2018 elementary LLC. (https://elementary.io)
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

public class DirectPhotoPage : EditingHostPage {
    private File initial_file;
    private DirectViewCollection? view_controller = null;
    private File current_save_dir;
    private bool drop_if_dirty = false;
    private Gtk.Menu open_menu;
    private Gtk.Menu open_raw_menu;
    private Gtk.MenuItem open_raw_menu_item;
    private Gtk.Menu contractor_menu;
    private Gtk.Menu context_menu;
    private bool fullscreen;

    public DirectPhotoPage (File file, bool fullscreen = false) {
        base (DirectPhoto.global, file.get_basename ());
        this.fullscreen = fullscreen;

        if (!check_editable_file (file)) {
            ((Photos.Application) GLib.Application.get_default ()).panic ();

            return;
        }

        initial_file = file;
        view_controller = new DirectViewCollection ();
        current_save_dir = file.get_parent ();
        DirectPhoto.global.items_altered.connect (on_photos_altered);

        get_view ().selection_group_altered.connect (on_selection_group_altered);
    }

    ~DirectPhotoPage () {
        DirectPhoto.global.items_altered.disconnect (on_photos_altered);
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry save = { "Save", null, null, "<Ctrl>S", null, on_save };
        Gtk.ActionEntry save_as = { "SaveAs", null, null, "<Ctrl><Shift>S", null, on_save_as };
        Gtk.ActionEntry print = { "Print", null, null, "<Ctrl>P", null, on_print };
        Gtk.ActionEntry rotate_right = { "RotateClockwise", null, null, "<Ctrl>R", null, on_rotate_clockwise };
        Gtk.ActionEntry rotate_left = { "RotateCounterclockwise", null, null, "<Ctrl><Shift>R", null, on_rotate_counterclockwise };
        Gtk.ActionEntry enhance = { "Enhance", null, null, "<Ctrl>E", null, on_enhance };
        Gtk.ActionEntry crop = { "Crop", null, null, "<Ctrl>O", null, toggle_crop };
        Gtk.ActionEntry straighten = { "Straighten", null, null, "<Ctrl>A", null, toggle_straighten };
        Gtk.ActionEntry red_eye = { "RedEye", null, null, "<Ctrl>Y", null, toggle_redeye };
        Gtk.ActionEntry adjust = { "Adjust", null, null, "<Ctrl>D", null, toggle_adjust };
        Gtk.ActionEntry revert = { "Revert", null, null, null, null, on_revert };
        Gtk.ActionEntry adjust_date_time = { "AdjustDateTime", null, null, null, null, on_adjust_date_time };
        Gtk.ActionEntry increase_size = { "IncreaseSize", null, null, "<Ctrl>plus", null, on_increase_size };
        Gtk.ActionEntry decrease_size = { "DecreaseSize", null, null, "<Ctrl>minus", null, on_decrease_size };
        Gtk.ActionEntry best_fit = { "ZoomFit", null, null, "<Ctrl>0", null, snap_zoom_to_min };
        Gtk.ActionEntry actual_size = { "Zoom100", null, null, "<Ctrl>1", null, snap_zoom_to_isomorphic };
        Gtk.ActionEntry max_size = { "Zoom200", null, null, "<Ctrl>2", null, snap_zoom_to_max };

        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();
        actions += save;
        actions += save_as;
        actions += print;
        actions += rotate_right;
        actions += rotate_left;
        actions += enhance;
        actions += crop;
        actions += straighten;
        actions += red_eye;
        actions += adjust;
        actions += revert;
        actions += adjust_date_time;
        actions += increase_size;
        actions += decrease_size;
        actions += best_fit;
        actions += actual_size;
        actions += max_size;

        return actions;
    }

    private static bool check_editable_file (File file) {
        if (!FileUtils.test (file.get_path (), FileTest.EXISTS))
            AppWindow.error_message (_ ("%s does not exist.").printf (file.get_path ()));
        else if (!FileUtils.test (file.get_path (), FileTest.IS_REGULAR))
            AppWindow.error_message (_ ("%s is not a file.").printf (file.get_path ()));
        else if (!PhotoFileFormat.is_file_supported (file))
            AppWindow.error_message (_ ("%s does not support the file format of\n%s.").printf (
                                         _ (Resources.APP_TITLE), file.get_path ()));
        else
            return true;

        return false;
    }

    public override void realize () {
        if (base.realize != null)
            base.realize ();

        DirectPhoto? photo = DirectPhoto.global.get_file_source (initial_file);

        display_mirror_of (view_controller, photo);
        initial_file = null;
    }

    protected override void photo_changing (Photo new_photo) {
        ((DirectPhoto) new_photo).demand_load ();
    }

    public File get_current_file () {
        return get_photo ().get_file ();
    }

    protected override bool on_context_buttonpress (Gdk.EventButton event) {
        if (context_menu == null) {
            context_menu = new Gtk.Menu ();

            var revert_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.REVERT_MENU);
            var revert_action = get_action ("Revert");
            revert_action.bind_property ("sensitive", revert_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            revert_menu_item.activate.connect (() => revert_action.activate ());

            var adjust_datetime_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.ADJUST_DATE_TIME_MENU);
            var adjust_datetime_action = get_action ("AdjustDateTime");
            adjust_datetime_action.bind_property ("sensitive", adjust_datetime_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            adjust_datetime_menu_item.activate.connect (() => adjust_datetime_action.activate ());

            context_menu.add (revert_menu_item);
            context_menu.add (new Gtk.SeparatorMenuItem ());
            context_menu.add (adjust_datetime_menu_item);

            if (fullscreen == false) {
                open_menu = new Gtk.Menu ();

                var open_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.OPEN_WITH_MENU);
                open_menu_item.set_submenu (open_menu);

                open_raw_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.OPEN_WITH_RAW_MENU);
                var open_raw_action = get_action ("OpenWithRaw");
                open_raw_action.bind_property ("sensitive", open_raw_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
                open_raw_menu = new Gtk.Menu ();
                open_raw_menu_item.set_submenu (open_raw_menu);

                var print_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.PRINT_MENU);
                var print_action = get_action ("Print");
                print_action.bind_property ("sensitive", print_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
                print_menu_item.activate.connect (() => print_action.activate ());

                var contractor_menu_item = new Gtk.MenuItem.with_mnemonic (_("Other Actions"));
                contractor_menu = new Gtk.Menu ();
                contractor_menu.add (print_menu_item);
                contractor_menu_item.set_submenu (contractor_menu);

                context_menu.add (new Gtk.SeparatorMenuItem ());
                context_menu.add (open_menu_item);
                context_menu.add (open_raw_menu_item);
                context_menu.add (contractor_menu_item);
            }

            context_menu.show_all ();

            Photo? photo = (get_view ().get_selected_at (0).source as Photo);
            if (photo != null) {
                unowned PhotoFileFormat photo_file_format = photo.get_master_file_format ();
                populate_external_app_menu (open_menu, photo_file_format, false);
    
                if (photo_file_format == PhotoFileFormat.RAW) {
                    populate_external_app_menu (open_raw_menu, PhotoFileFormat.RAW, true);
                }
            }

            open_raw_menu_item.visible = get_action ("OpenWithRaw").sensitive;
        }

        populate_contractor_menu (contractor_menu);
        popup_context_menu (context_menu, event);

        return true;
    }

    private void populate_external_app_menu (Gtk.Menu menu, PhotoFileFormat file_format, bool raw) {
        SortedList<AppInfo> external_apps;
        string[] mime_types;

        foreach (Gtk.Widget item in menu.get_children ()) {
            menu.remove (item);
        }

        // get list of all applications for the given mime types
        mime_types = file_format.get_mime_types ();

        if (!raw) {
            var files_appinfo = AppInfo.get_default_for_type ("inode/directory", true);

            var files_item_icon = new Gtk.Image.from_gicon (files_appinfo.get_icon (), Gtk.IconSize.MENU);
            files_item_icon.pixel_size = 16;

            var menuitem_grid = new Gtk.Grid ();
            menuitem_grid.add (files_item_icon);
            menuitem_grid.add (new Gtk.Label (files_appinfo.get_name ()));

            var jump_menu_item = new Gtk.MenuItem ();
            jump_menu_item.add (menuitem_grid);

            var jump_menu_action = AppWindow.get_instance ().lookup_action (AppWindow.ACTION_JUMP_TO_FILE);
            jump_menu_action.bind_property ("enabled", jump_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            jump_menu_item.activate.connect (() => jump_menu_action.activate (null));

            menu.add (jump_menu_item);
        }

        assert (mime_types.length != 0);
        external_apps = DesktopIntegration.get_apps_for_mime_types (mime_types);

        foreach (AppInfo app in external_apps) {
            var menu_item_icon = new Gtk.Image.from_gicon (app.get_icon (), Gtk.IconSize.MENU);
            menu_item_icon.pixel_size = 16;

            var menuitem_grid = new Gtk.Grid ();
            menuitem_grid.add (menu_item_icon);
            menuitem_grid.add (new Gtk.Label (app.get_name ()));

            var item_app = new Gtk.MenuItem ();
            item_app.add (menuitem_grid);

            item_app.activate.connect (() => {
                if (raw) {
                    on_open_with_raw (app.get_commandline ());
                } else {
                    on_open_with (app.get_commandline ());
                }
            });
            menu.add (item_app);
        }
        menu.show_all ();
    }

    private void on_open_with (string app) {
        if (!has_photo ()) {
            return;
        }

        try {
            AppWindow.get_instance ().set_busy_cursor ();
            get_photo ().open_with_external_editor (app);
            AppWindow.get_instance ().set_normal_cursor ();
        } catch (Error err) {
            AppWindow.get_instance ().set_normal_cursor ();
            open_external_editor_error_dialog (err, get_photo ());
        }
    }

    private void on_open_with_raw (string app) {
        if (!has_photo ()) {
            return;
        }

        if (get_photo ().get_master_file_format () != PhotoFileFormat.RAW) {
            return;
        }

        try {
            AppWindow.get_instance ().set_busy_cursor ();
            get_photo ().open_with_raw_external_editor (app);
            AppWindow.get_instance ().set_normal_cursor ();
        } catch (Error err) {
            AppWindow.get_instance ().set_normal_cursor ();
            AppWindow.error_message (Resources.launch_editor_failed (err));
        }
    }

    private void update_zoom_menu_item_sensitivity () {
        set_action_sensitive ("IncreaseSize", !get_zoom_state ().is_max () && !get_photo_missing ());
        set_action_sensitive ("DecreaseSize", !get_zoom_state ().is_default () && !get_photo_missing ());
    }

    protected override void on_increase_size () {
        base.on_increase_size ();

        update_zoom_menu_item_sensitivity ();
    }

    protected override void on_decrease_size () {
        base.on_decrease_size ();

        update_zoom_menu_item_sensitivity ();
    }

    private void on_photos_altered (Gee.Map<DataObject, Alteration> map) {
        bool contains = false;
        if (has_photo ()) {
            Photo photo = get_photo ();
            foreach (DataObject object in map.keys) {
                if (((Photo) object) == photo) {
                    contains = true;

                    break;
                }
            }
        }

        bool sensitive = has_photo () && !get_photo_missing ();
        if (sensitive)
            sensitive = contains;

        set_action_sensitive ("Save", sensitive && get_photo ().get_file_format ().can_write ());
        set_action_sensitive ("Revert", sensitive);
    }

    private void on_selection_group_altered () {
        // On EditingHostPage, the displayed photo is always selected, so this signal is fired
        // whenever a new photo is displayed (which even happens on an in-place save; the changes
        // are written and a new DirectPhoto is loaded into its place).
        //
        // In every case, reset the CommandManager, as the command stack is not valid against this
        // new file.
        get_command_manager ().reset ();
    }

    protected override bool on_double_click (Gdk.EventButton event) {
        if (AppWindow.get_fullscreen () != null) {
            AppWindow.get_instance ().end_fullscreen ();
        } else {
            File file = get_current_file ();
            AppWindow.get_instance ().go_fullscreen (new DirectPhotoPage (file, true));
        }
        return true;
    }

    protected override void update_ui (bool missing) {
        bool sensitivity = !missing;
        set_action_sensitive ("Save", sensitivity);
        set_action_sensitive ("SaveAs", sensitivity);
        set_action_sensitive ("Publish", sensitivity);
        set_action_sensitive ("Print", sensitivity);
        ((SimpleAction) AppWindow.get_instance ().lookup_action (AppWindow.ACTION_JUMP_TO_FILE)).set_enabled (sensitivity);

        ((SimpleAction) AppWindow.get_instance ().lookup_action (AppWindow.ACTION_UNDO)).set_enabled (sensitivity);
        ((SimpleAction) AppWindow.get_instance ().lookup_action (AppWindow.ACTION_REDO)).set_enabled (sensitivity);

        set_action_sensitive ("IncreaseSize", sensitivity);
        set_action_sensitive ("DecreaseSize", sensitivity);
        set_action_sensitive ("ZoomFit", sensitivity);
        set_action_sensitive ("Zoom100", sensitivity);
        set_action_sensitive ("Zoom200", sensitivity);

        set_action_sensitive ("RotateClockwise", sensitivity);
        set_action_sensitive ("RotateCounterclockwise", sensitivity);
        set_action_sensitive ("FlipHorizontally", sensitivity);
        set_action_sensitive ("FlipVertically", sensitivity);
        set_action_sensitive ("Enhance", sensitivity);
        set_action_sensitive ("Crop", sensitivity);
        set_action_sensitive ("Straighten", sensitivity);
        set_action_sensitive ("RedEye", sensitivity);
        set_action_sensitive ("Adjust", sensitivity);
        set_action_sensitive ("Revert", sensitivity);
        set_action_sensitive ("AdjustDateTime", sensitivity);
        set_action_sensitive ("Fullscreen", sensitivity);

        base.update_ui (missing);
    }

    protected override void update_actions (int selected_count, int count) {
        bool multiple = get_view ().get_count () > 1;
        bool revert_possible = has_photo () ? get_photo ().has_transformations ()
            && !get_photo_missing () : false;
        bool rotate_possible = has_photo () ? is_rotate_available (get_photo ()) : false;
        bool enhance_possible = has_photo () ? is_enhance_available (get_photo ()) : false;

        set_action_sensitive ("PrevPhoto", multiple);
        set_action_sensitive ("NextPhoto", multiple);
        set_action_sensitive ("RotateClockwise", rotate_possible);
        set_action_sensitive ("RotateCounterclockwise", rotate_possible);
        set_action_sensitive ("FlipHorizontally", rotate_possible);
        set_action_sensitive ("FlipVertically", rotate_possible);
        set_action_sensitive ("Revert", revert_possible);
        set_action_sensitive ("Enhance", enhance_possible);

        set_action_sensitive ("SetBackground", has_photo ());

        if (has_photo ()) {
            set_action_sensitive ("Crop", EditingTools.CropTool.is_available (get_photo (), Scaling.for_original ()));
            set_action_sensitive ("RedEye", EditingTools.RedeyeTool.is_available (get_photo (),
                Scaling.for_original ()));
        }

        // can't write to raws, and trapping the output JPEG here is tricky,
        // so don't allow date/time changes here.
        if (get_photo () != null) {
            set_action_sensitive ("AdjustDateTime", (get_photo ().get_file_format () != PhotoFileFormat.RAW));
        } else {
            set_action_sensitive ("AdjustDateTime", false);
        }

        base.update_actions (selected_count, count);
        rotate_button.sensitive = rotate_possible;
    }

    private bool check_ok_to_close_photo (Photo photo) {
        if (!photo.has_alterations ())
            return true;

        if (drop_if_dirty) {
            // need to remove transformations, or else they stick around in memory (reappearing
            // if the user opens the file again)
            photo.remove_all_transformations ();

            return true;
        }

        bool is_writeable = get_photo ().can_write_file () && get_photo ().get_file_format ().can_write ();
        string save_option = is_writeable ? _ ("_Save") : _ ("_Save a Copy");

        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Lose changes to %s?").printf (photo.get_basename ()),
            "",
            "dialog-question",
            Gtk.ButtonsType.NONE
        );
        dialog.transient_for = AppWindow.get_instance ();

        var no_save_button = (Gtk.Button) dialog.add_button (_("Close _without Saving"), Gtk.ResponseType.YES);
        no_save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        dialog.add_buttons (_("_Cancel"), Gtk.ResponseType.CANCEL, save_option, Gtk.ResponseType.NO);

        int response = dialog.run ();

        dialog.destroy ();

        if (response == Gtk.ResponseType.YES)
            photo.remove_all_transformations ();
        else if (response == Gtk.ResponseType.NO) {
            if (is_writeable)
                return save (photo.get_file (), 0, ScaleConstraint.ORIGINAL, Jpeg.Quality.HIGH,
                      get_photo ().get_file_format ());
            else
                return do_save_as ();
        } else if ((response == Gtk.ResponseType.CANCEL) || (response == Gtk.ResponseType.DELETE_EVENT) ||
                   (response == Gtk.ResponseType.CLOSE)) {
            return false;
        }

        return true;
    }

    public bool check_quit () {
        return check_ok_to_close_photo (get_photo ());
    }

    protected override bool confirm_replace_photo (Photo? old_photo, Photo new_photo) {
        return (old_photo != null) ? check_ok_to_close_photo (old_photo) : true;
    }

    private bool save (File dest, int scale, ScaleConstraint constraint, Jpeg.Quality quality,
                       PhotoFileFormat format, bool copy_unmodified = false, bool save_metadata = true) {
        Scaling scaling = Scaling.for_constraint (constraint, scale, false);

        try {
            get_photo ().export (dest, scaling, quality, format, copy_unmodified, save_metadata);
        } catch (Error err) {
            AppWindow.error_message (_ ("Error while saving to %s: %s").printf (dest.get_path (),
                                     err.message));

            return false;
        }

        // Fetch the DirectPhoto and reimport.
        DirectPhoto photo;
        DirectPhoto.global.fetch (dest, out photo, true);

        DirectView tmp_view = new DirectView (photo);
        view_controller.add (tmp_view);

        DirectPhoto.global.reimport_photo (photo);
        display_mirror_of (view_controller, photo);

        return true;
    }

    private void on_save () {
        if (!get_photo ().has_alterations () || !get_photo ().get_file_format ().can_write () ||
                get_photo_missing ())
            return;

        // save full-sized version right on top of the current file
        save (get_photo ().get_file (), 0, ScaleConstraint.ORIGINAL, Jpeg.Quality.HIGH,
              get_photo ().get_file_format ());
    }

    private bool do_save_as () {
        ExportDialog export_dialog = new ExportDialog (_ ("Save As"));

        int scale;
        ScaleConstraint constraint;
        ExportFormatParameters export_params = ExportFormatParameters.last ();
        if (!export_dialog.execute (out scale, out constraint, ref export_params))
            return false;

        string filename = get_photo ().get_export_basename_for_parameters (export_params);
        PhotoFileFormat effective_export_format =
            get_photo ().get_export_format_for_parameters (export_params);

        string[] output_format_extensions =
            effective_export_format.get_properties ().get_known_extensions ();
        Gtk.FileFilter output_format_filter = new Gtk.FileFilter ();
        foreach (string extension in output_format_extensions) {
            string uppercase_extension = extension.up ();
            output_format_filter.add_pattern ("*." + extension);
            output_format_filter.add_pattern ("*." + uppercase_extension);
        }

        var save_as_dialog = new Gtk.FileChooserNative (
            _("Save As"),
            AppWindow.get_instance (),
            Gtk.FileChooserAction.SAVE,
            _("Save"),
            _("Cancel")
        );
        save_as_dialog.set_select_multiple (false);
        save_as_dialog.set_current_name (filename);
        save_as_dialog.set_current_folder (current_save_dir.get_path ());
        save_as_dialog.add_filter (output_format_filter);
        save_as_dialog.set_do_overwrite_confirmation (true);
        save_as_dialog.set_local_only (false);

        int response = save_as_dialog.run ();
        bool save_successful = false;
        if (response == Gtk.ResponseType.ACCEPT) {
            // flag to prevent asking user about losing changes to the old file (since they'll be
            // loaded right into the new one)
            drop_if_dirty = true;
            save_successful = save (File.new_for_uri (save_as_dialog.get_uri ()), scale, constraint, export_params.quality,
                  effective_export_format, export_params.mode == ExportFormatMode.UNMODIFIED,
                  export_params.export_metadata);
            drop_if_dirty = false;

            current_save_dir = File.new_for_path (save_as_dialog.get_current_folder ());
        }

        save_as_dialog.destroy ();
        return save_successful;
    }

    private void on_save_as () {
        do_save_as ();
    }

    /**
     * Returns true if the code parameter matches the keycode of the keyval parameter for
     * any keyboard group or level (in order to allow for non-QWERTY keyboards)
     */
#if VALA_0_42
    protected bool match_keycode (uint keyval, uint code) {
#else
    protected bool match_keycode (int keyval, uint code) {
#endif
        Gdk.KeymapKey [] keys;
        Gdk.Keymap keymap = Gdk.Keymap.get_default ();
        if (keymap.get_entries_for_keyval (keyval, out keys)) {
            foreach (var key in keys) {
                if (code == key.keycode)
                    return true;
            }
        }
        return false;
    }

    protected override bool on_app_key_pressed (Gdk.EventKey event) {
        uint keycode = event.hardware_keycode;

        if (match_keycode (Gdk.Key.s, keycode)) {
            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                    on_save_as ();
                } else {
                    on_save ();
                }
                return true;
            }
        }

        if (match_keycode (Gdk.Key.bracketright, keycode)) {
            activate_action ("RotateClockwise");
            return true;
        }

        if (match_keycode (Gdk.Key.bracketleft, keycode)) {
            activate_action ("RotateCounterclockwise");
            return true;
        }

        return base.on_app_key_pressed (event);
    }

    private void on_print () {
        if (get_view ().get_selected_count () > 0) {
            PrintManager.get_instance ().spool_photo (
                (Gee.Collection<Photo>) get_view ().get_selected_sources_of_type (typeof (Photo)));
        }
    }

    protected override DataView create_photo_view (DataSource source) {
        return new DirectView ((DirectPhoto) source);
    }
}
