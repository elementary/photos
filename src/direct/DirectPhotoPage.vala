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

public class DirectPhotoPage : EditingHostPage {
    private File initial_file;
    private DirectViewCollection? view_controller = null;
    private File current_save_dir;
    private bool drop_if_dirty = false;

    public DirectPhotoPage (File file) {
        base (DirectPhoto.global, file.get_basename ());

        if (!check_editable_file (file)) {
            Application.get_instance ().panic ();

            return;
        }

        initial_file = file;
        view_controller = new DirectViewCollection ();
        current_save_dir = file.get_parent ();
        DirectPhoto.global.items_altered.connect (on_photos_altered);

        get_view ().selection_group_altered.connect (on_selection_group_altered);
        Gtk.Toolbar toolbar = get_toolbar ();
        toolbar.remove (show_sidebar_button);
    }

    ~DirectPhotoPage () {
        DirectPhoto.global.items_altered.disconnect (on_photos_altered);
    }

    protected override void init_collect_ui_filenames (Gee.List<string> ui_filenames) {
        base.init_collect_ui_filenames (ui_filenames);

        ui_filenames.add ("direct_context.ui");
        ui_filenames.add ("direct.ui");
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry file = { "FileMenu", null, _("_File"), null, null, null };
        actions += file;

        Gtk.ActionEntry save = { "Save", "document-save", _("_Save"), "<Ctrl>S", _("Save photo"),
                                 on_save
                               };
        actions += save;

        Gtk.ActionEntry save_as = { "SaveAs", "document-save-as", _("Save _As..."),
                                    "<Ctrl><Shift>S", _("Save photo with a different name"), on_save_as
                                  };
        actions += save_as;

        Gtk.ActionEntry print = { "Print", null, Resources.PRINT_MENU, "<Ctrl>P",
                                  _("Print the photo to a printer connected to your computer"), on_print
                                };
        actions += print;

        Gtk.ActionEntry edit = { "EditMenu", null, _("_Edit"), null, null, null };
        actions += edit;

        Gtk.ActionEntry photo = { "PhotoMenu", null, _("_Photo"), null, null, null };
        actions += photo;

        Gtk.ActionEntry tools = { "Tools", null, _("T_ools"), null, null, null };
        actions += tools;

        Gtk.ActionEntry prev = { "PrevPhoto", null, _("_Previous Photo"), null,
                                 _("Previous Photo"), on_previous_photo
                               };
        actions += prev;

        Gtk.ActionEntry next = { "NextPhoto", null, _("_Next Photo"), null,
                                 _("Next Photo"), on_next_photo
                               };
        actions += next;

        Gtk.ActionEntry rotate_right = { "RotateClockwise", Resources.CLOCKWISE,
                                         Resources.ROTATE_CW_MENU, "<Ctrl>R", Resources.ROTATE_CCW_TOOLTIP, on_rotate_clockwise
                                       };
        actions += rotate_right;

        Gtk.ActionEntry rotate_left = { "RotateCounterclockwise", Resources.COUNTERCLOCKWISE,
                                        Resources.ROTATE_CCW_MENU, "<Ctrl><Shift>R", Resources.ROTATE_CCW_TOOLTIP, on_rotate_counterclockwise
                                      };
        actions += rotate_left;

        Gtk.ActionEntry hflip = { "FlipHorizontally", Resources.HFLIP, Resources.HFLIP_MENU, null,
                                  Resources.HFLIP_MENU, on_flip_horizontally
                                };
        actions += hflip;

        Gtk.ActionEntry vflip = { "FlipVertically", Resources.VFLIP, Resources.VFLIP_MENU, null,
                                  Resources.VFLIP_MENU, on_flip_vertically
                                };
        actions += vflip;

        Gtk.ActionEntry enhance = { "Enhance", Resources.ENHANCE, Resources.ENHANCE_MENU, "<Ctrl>E",
                                    Resources.ENHANCE_TOOLTIP, on_enhance
                                  };
        actions += enhance;

        Gtk.ActionEntry crop = { "Crop", Resources.CROP, Resources.CROP_MENU, "<Ctrl>O",
                                 Resources.CROP_TOOLTIP, toggle_crop
                               };
        actions += crop;

        Gtk.ActionEntry straighten = { "Straighten", null, Resources.STRAIGHTEN_MENU, "<Ctrl>A",
                                       Resources.STRAIGHTEN_TOOLTIP, toggle_straighten
                                     };
        actions += straighten;

        Gtk.ActionEntry red_eye = { "RedEye", Resources.REDEYE, Resources.RED_EYE_MENU, "<Ctrl>Y",
                                    Resources.RED_EYE_TOOLTIP, toggle_redeye
                                  };
        actions += red_eye;

        Gtk.ActionEntry adjust = { "Adjust", Resources.ADJUST, Resources.ADJUST_MENU, "<Ctrl>D",
                                   Resources.ADJUST_TOOLTIP, toggle_adjust
                                 };
        actions += adjust;

        Gtk.ActionEntry revert = { "Revert", null, Resources.REVERT_MENU,
                                   null, Resources.REVERT_MENU, on_revert
                                 };
        actions += revert;

        Gtk.ActionEntry adjust_date_time = { "AdjustDateTime", null, Resources.ADJUST_DATE_TIME_MENU, null,
                                             Resources.ADJUST_DATE_TIME_MENU, on_adjust_date_time
                                           };
        actions += adjust_date_time;

        Gtk.ActionEntry view = { "ViewMenu", null, _("_View"), null, null, null };
        actions += view;

        Gtk.ActionEntry help = { "HelpMenu", null, _("_Help"), null, null, null };
        actions += help;

        Gtk.ActionEntry increase_size = { "IncreaseSize", null, _("Zoom _In"),
                                          "<Ctrl>plus", _("Increase the magnification of the photo"), on_increase_size
                                        };
        actions += increase_size;

        Gtk.ActionEntry decrease_size = { "DecreaseSize", null, _("Zoom _Out"),
                                          "<Ctrl>minus", _("Decrease the magnification of the photo"), on_decrease_size
                                        };
        actions += decrease_size;

        Gtk.ActionEntry best_fit = { "ZoomFit", null, _("Fit to _Page"),
                                     "<Ctrl>0", _("Zoom the photo to fit on the screen"), snap_zoom_to_min
                                   };
        actions += best_fit;

        /// xgettext:no-c-format
        Gtk.ActionEntry actual_size = { "Zoom100", null, _("Zoom _100%"),
                                        "<Ctrl>1", _("Zoom the photo to 100% magnification"), snap_zoom_to_isomorphic
                                      };
        actions += actual_size;

        /// xgettext:no-c-format
        Gtk.ActionEntry max_size = { "Zoom200", null, _("Zoom _200%"),
                                     "<Ctrl>2", _("Zoom the photo to 200% magnification"), snap_zoom_to_max
                                   };
        actions += max_size;

        return actions;
    }

    protected override InjectionGroup[] init_collect_injection_groups () {
        InjectionGroup[] groups = base.init_collect_injection_groups ();

        InjectionGroup print_group = new InjectionGroup ("/DirectContextMenu/PrintPlaceholder");
        print_group.add_menu_item ("Print");
        groups += print_group;

        return groups;
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
        Gtk.Menu context_menu = (Gtk.Menu) ui.get_widget ("/DirectContextMenu");
        populate_contractor_menu (context_menu, "/DirectContextMenu/ContractorPlaceholder");
        popup_context_menu (context_menu, event);

        return true;
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
            AppWindow.get_instance ().go_fullscreen (new DirectFullscreenPhotoPage (file));
        }
        return true;
    }

    protected override void update_ui (bool missing) {
        bool sensitivity = !missing;
        set_action_sensitive ("Save", sensitivity);
        set_action_sensitive ("SaveAs", sensitivity);
        set_action_sensitive ("Publish", sensitivity);
        set_action_sensitive ("Print", sensitivity);
        set_action_sensitive ("CommonJumpToFile", sensitivity);

        set_action_sensitive ("CommonUndo", sensitivity);
        set_action_sensitive ("CommonRedo", sensitivity);

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

        bool is_writeable = get_photo ().get_file_format ().can_write ();
        string save_option = is_writeable ? _ ("_Save") : _ ("_Save a Copy");

        Gtk.ResponseType response = AppWindow.affirm_cancel_negate_question (
                                        _("Lose changes to %s?").printf (photo.get_basename ()),
                                        _("Close _without Saving"),
                                        save_option);

        if (response == Gtk.ResponseType.YES)
            photo.remove_all_transformations ();
        else if (response == Gtk.ResponseType.NO) {
            if (is_writeable)
                save (photo.get_file (), 0, ScaleConstraint.ORIGINAL, Jpeg.Quality.HIGH,
                      get_photo ().get_file_format ());
            else
                on_save_as ();
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

    private void save (File dest, int scale, ScaleConstraint constraint, Jpeg.Quality quality,
                       PhotoFileFormat format, bool copy_unmodified = false, bool save_metadata = true) {
        Scaling scaling = Scaling.for_constraint (constraint, scale, false);

        try {
            get_photo ().export (dest, scaling, quality, format, copy_unmodified, save_metadata);
        } catch (Error err) {
            AppWindow.error_message (_ ("Error while saving to %s: %s").printf (dest.get_path (),
                                     err.message));

            return;
        }

        // Fetch the DirectPhoto and reimport.
        DirectPhoto photo;
        DirectPhoto.global.fetch (dest, out photo, true);

        DirectView tmp_view = new DirectView (photo);
        view_controller.add (tmp_view);

        DirectPhoto.global.reimport_photo (photo);
        display_mirror_of (view_controller, photo);
    }

    private void on_save () {
        if (!get_photo ().has_alterations () || !get_photo ().get_file_format ().can_write () ||
                get_photo_missing ())
            return;

        // save full-sized version right on top of the current file
        save (get_photo ().get_file (), 0, ScaleConstraint.ORIGINAL, Jpeg.Quality.HIGH,
              get_photo ().get_file_format ());
    }

    private void on_save_as () {
        ExportDialog export_dialog = new ExportDialog (_ ("Save As"));

        int scale;
        ScaleConstraint constraint;
        ExportFormatParameters export_params = ExportFormatParameters.last ();
        if (!export_dialog.execute (out scale, out constraint, ref export_params))
            return;

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

        Gtk.FileChooserDialog save_as_dialog = new Gtk.FileChooserDialog (_ ("Save As"),
                AppWindow.get_instance (), Gtk.FileChooserAction.SAVE, _("Cancel"),
                Gtk.ResponseType.CANCEL, _("Save"), Gtk.ResponseType.OK);
        save_as_dialog.set_select_multiple (false);
        save_as_dialog.set_current_name (filename);
        save_as_dialog.set_current_folder (current_save_dir.get_path ());
        save_as_dialog.add_filter (output_format_filter);
        save_as_dialog.set_do_overwrite_confirmation (true);
        save_as_dialog.set_local_only (false);

        int response = save_as_dialog.run ();
        if (response == Gtk.ResponseType.OK) {
            // flag to prevent asking user about losing changes to the old file (since they'll be
            // loaded right into the new one)
            drop_if_dirty = true;
            save (File.new_for_uri (save_as_dialog.get_uri ()), scale, constraint, export_params.quality,
                  effective_export_format, export_params.mode == ExportFormatMode.UNMODIFIED,
                  export_params.export_metadata);
            drop_if_dirty = false;

            current_save_dir = File.new_for_path (save_as_dialog.get_current_folder ());
        }

        save_as_dialog.destroy ();
    }

    /** Returns true if the code parameter matches the keycode of the keyval parameter for
    * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
    protected bool match_keycode (int keyval, uint code) {
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

public class DirectFullscreenPhotoPage : DirectPhotoPage {
    public DirectFullscreenPhotoPage (File file) {
        base (file);
    }

    protected override void init_collect_ui_filenames (Gee.List<string> ui_filenames) {
        // We intentionally avoid calling the base class implementation since we don't want
        // direct.ui.
        ui_filenames.add ("direct_context.ui");
    }
}
