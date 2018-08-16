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

public class LibraryPhotoPage : EditingHostPage {

    private class LibraryPhotoPageViewFilter : ViewFilter {
        public override bool predicate (DataView view) {
            return ! ((MediaSource) view.get_source ()).is_trashed ();
        }
    }

    private CollectionPage? return_page = null;
    private bool return_to_collection_on_release = false;
    private LibraryPhotoPageViewFilter filter = new LibraryPhotoPageViewFilter ();
    private Gtk.Menu open_menu;
    private Gtk.Menu open_raw_menu;
    private Gtk.MenuItem open_raw_menu_item;
    private Gtk.Menu contractor_menu;
    private Gtk.Menu item_context_menu;

    public LibraryPhotoPage () {
        base (LibraryPhoto.global, "Photo");

        // monitor view to update UI elements
        view.items_altered.connect (on_photos_altered);

        // watch for photos being destroyed or altered, either here or in other pages
        LibraryPhoto.global.item_destroyed.connect (on_photo_destroyed);
        LibraryPhoto.global.items_altered.connect (on_metadata_altered);

        // Filter out trashed files.
        view.install_view_filter (filter);
        LibraryPhoto.global.items_unlinking.connect (on_photo_unlinking);
        LibraryPhoto.global.items_relinked.connect (on_photo_relinked);
    }

    ~LibraryPhotoPage () {
        LibraryPhoto.global.item_destroyed.disconnect (on_photo_destroyed);
        LibraryPhoto.global.items_altered.disconnect (on_metadata_altered);
    }

    public override Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            base.get_toolbar ();

            Gtk.Image start_image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            Gtk.ToolButton slideshow_button = new Gtk.ToolButton (start_image, _("S_lideshow"));
            slideshow_button.set_tooltip_text (_("Play a slideshow"));
            slideshow_button.clicked.connect (on_slideshow);
            get_toolbar ().insert (slideshow_button, 0);
        }
        return toolbar;
    }

    public override Gtk.Box get_header_buttons () {
        header_box = base.get_header_buttons ();
        LibraryWindow app = AppWindow.get_instance () as LibraryWindow;
        if (app == null)
            return header_box;

        if (return_page != null) {
            var last_name = return_page.get_back_name ();
            // Back Button
            var back_button = new Gtk.Button ();
            back_button.clicked.connect (return_to_collection);
            back_button.get_style_context ().add_class ("back-button");
            back_button.can_focus = false;
            back_button.valign = Gtk.Align.CENTER;
            back_button.vexpand = false;
            back_button.visible = false;
            back_button.label = last_name;
            header_box.pack_start (back_button);
        }

        return header_box;
    }

    public bool not_trashed_view_filter (DataView view) {
        return ! ((MediaSource) view.get_source ()).is_trashed ();
    }

    private void on_photo_unlinking (Gee.Collection<DataSource> unlinking) {
        filter.refresh ();
    }

    private void on_photo_relinked (Gee.Collection<DataSource> relinked) {
        filter.refresh ();
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry export = { "Export", null, Resources.EXPORT_MENU, "<Ctrl><Shift>E",
                                   Resources.EXPORT_MENU, on_export
                                 };
        actions += export;

        Gtk.ActionEntry print = { "Print", null, Resources.PRINT_MENU, "<Ctrl>P",
                                  Resources.PRINT_MENU, on_print
                                };
        actions += print;

        Gtk.ActionEntry publish = { "Publish", Resources.PUBLISH, Resources.PUBLISH_MENU, "<Ctrl><Shift>P",
                                    Resources.PUBLISH_TOOLTIP, on_publish
                                  };
        actions += publish;

        Gtk.ActionEntry remove_from_library = { "RemoveFromLibrary", null, Resources.REMOVE_FROM_LIBRARY_MENU,
                                                "<Shift>Delete", Resources.REMOVE_FROM_LIBRARY_MENU, on_remove_from_library
                                              };
        actions += remove_from_library;

        Gtk.ActionEntry move_to_trash = { "MoveToTrash", "user-trash-full", Resources.MOVE_TO_TRASH_MENU, "Delete",
                                          Resources.MOVE_TO_TRASH_MENU, on_move_to_trash
                                        };
        actions += move_to_trash;

        Gtk.ActionEntry view = { "ViewMenu", null, _("_View"), null, null, on_view_menu };
        actions += view;

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

        Gtk.ActionEntry rotate_right = { "RotateClockwise", Resources.CLOCKWISE, Resources.ROTATE_CW_MENU,
                                         "<Ctrl>R", Resources.ROTATE_CW_TOOLTIP, on_rotate_clockwise
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

        Gtk.ActionEntry copy_adjustments = { "CopyColorAdjustments", null, Resources.COPY_ADJUSTMENTS_MENU,
                                             "<Ctrl><Shift>C", Resources.COPY_ADJUSTMENTS_TOOLTIP, on_copy_adjustments
                                           };
        actions += copy_adjustments;

        Gtk.ActionEntry paste_adjustments = { "PasteColorAdjustments", null, Resources.PASTE_ADJUSTMENTS_MENU,
                                              "<Ctrl><Shift>V", Resources.PASTE_ADJUSTMENTS_TOOLTIP, on_paste_adjustments
                                            };
        actions += paste_adjustments;

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

        Gtk.ActionEntry flag = { "Flag", null, Resources.FLAG_MENU, "<Ctrl>G", Resources.FLAG_MENU, on_flag_unflag };
        actions += flag;

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

        Gtk.ActionEntry slideshow = { "Slideshow", null, _("S_lideshow"), "F5", _("Play a slideshow"),
                                      on_slideshow
                                    };
        actions += slideshow;

        Gtk.ActionEntry raw_developer = { "RawDeveloper", null, _("_Developer"), null, null, null };
        actions += raw_developer;

        Gtk.ActionEntry open_with = { "OpenWith", null, null, null, null, null };
        actions += open_with;

        Gtk.ActionEntry open_with_raw = { "OpenWithRaw", null, Resources.OPEN_WITH_RAW_MENU, null, null, null };
        actions += open_with_raw;

        return actions;
    }

    protected override Gtk.ToggleActionEntry[] init_collect_toggle_action_entries () {
        Gtk.ToggleActionEntry[] toggle_actions = base.init_collect_toggle_action_entries ();

        return toggle_actions;
    }

    protected override void register_radio_actions (Gtk.ActionGroup action_group) {
        // RAW developer.
        //get_config_photos_sort(out sort_order, out sort_by); // TODO: fetch default from config

        Gtk.RadioActionEntry[] developer_actions = new Gtk.RadioActionEntry[0];

        string label_shotwell = RawDeveloper.SHOTWELL.get_label ();
        Gtk.RadioActionEntry dev_shotwell = { "RawDeveloperShotwell", null, label_shotwell, null, label_shotwell,
                                              RawDeveloper.SHOTWELL
                                            };
        developer_actions += dev_shotwell;

        string label_camera = RawDeveloper.CAMERA.get_label ();
        Gtk.RadioActionEntry dev_camera = { "RawDeveloperCamera", null, label_camera, null, label_camera,
                                            RawDeveloper.CAMERA
                                          };
        developer_actions += dev_camera;

        action_group.add_radio_actions (developer_actions, RawDeveloper.SHOTWELL, on_raw_developer_changed);

        base.register_radio_actions (action_group);
    }

    protected override void update_actions (int selected_count, int count) {
        bool multiple = view.get_count () > 1;
        bool rotate_possible = has_photo () ? is_rotate_available (get_photo ()) : false;
        bool is_raw = has_photo () && get_photo ().get_master_file_format () == PhotoFileFormat.RAW;

        set_action_sensitive ("OpenWith",
                              has_photo ());

        set_action_sensitive ("Revert", has_photo () ?
                              (get_photo ().has_transformations () || get_photo ().has_editable ()) : false);

        if (has_photo () && !get_photo_missing ()) {
            update_development_menu_item_sensitivity ();
        }

        set_action_sensitive ("CopyColorAdjustments", (has_photo () && get_photo ().has_color_adjustments ()));
        set_action_sensitive ("PasteColorAdjustments", PixelTransformationBundle.has_copied_color_adjustments ());

        set_action_sensitive ("PrevPhoto", multiple);
        set_action_sensitive ("NextPhoto", multiple);
        set_action_sensitive ("RotateClockwise", rotate_possible);
        set_action_sensitive ("RotateCounterclockwise", rotate_possible);
        set_action_sensitive ("FlipHorizontally", rotate_possible);
        set_action_sensitive ("FlipVertically", rotate_possible);

        if (has_photo ()) {
            set_action_sensitive ("Crop", EditingTools.CropTool.is_available (get_photo (), Scaling.for_original ()));
            set_action_sensitive ("RedEye", EditingTools.RedeyeTool.is_available (get_photo (),
                                  Scaling.for_original ()));
        }

        update_flag_action ();
        update_enhance_action ();
        set_action_visible ("OpenWithRaw",
                            is_raw);

        base.update_actions (selected_count, count);
    }

    private void on_photos_altered () {
        set_action_sensitive ("Revert", has_photo () ?
                              (get_photo ().has_transformations () || get_photo ().has_editable ()) : false);
        update_flag_action ();
        update_enhance_action ();
    }

    private void on_raw_developer_changed (Gtk.Action action, Gtk.Action current) {
        developer_changed ((RawDeveloper) ((Gtk.RadioAction) current).get_current_value ());
    }

    protected virtual void developer_changed (RawDeveloper rd) {
        if (view.get_selected_count () != 1)
            return;

        Photo? photo = view.get_selected ().get (0).get_source () as Photo;
        if (photo == null || rd.is_equivalent (photo.get_raw_developer ()))
            return;

        // Check if any photo has edits
        // Display warning only when edits could be destroyed
        if (!photo.has_transformations () || Dialogs.confirm_warn_developer_changed (1)) {
            SetRawDeveloperCommand command = new SetRawDeveloperCommand (view.get_selected (),
                    rd);
            get_command_manager ().execute (command);

            update_development_menu_item_sensitivity ();
        }
    }

    private void update_flag_action () {
        if (has_photo ()) {
            Gtk.Action? action = get_action ("Flag");
            assert (action != null);

            bool is_flagged = ((LibraryPhoto) get_photo ()).is_flagged ();

            action.label = is_flagged ? Resources.UNFLAG_MENU : Resources.FLAG_MENU;
            action.sensitive = true;
        } else {
            set_action_sensitive ("Flag", false);
        }
    }

    // Displays a photo from a specific CollectionPage.  When the user exits this view,
    // they will be sent back to the return_page. The optional view paramters is for using
    // a ViewCollection other than the one inside return_page; this is necessary if the
    // view and return_page have different filters.
    public void display_for_collection (CollectionPage return_page, Photo photo,
                                        ViewCollection? view = null) {
        this.return_page = return_page;
        return_page.destroy.connect (on_page_destroyed);

        display_copy_of (view != null ? view : return_page.view, photo);
    }

    public void on_page_destroyed () {
        // The parent page was removed, so drop the reference to the page and
        // its view collection.
        return_page = null;
        unset_view_collection ();
    }

    public CollectionPage? get_controller_page () {
        return return_page;
    }

    public override void switched_to () {
        // since LibraryPhotoPages often rest in the background, their stored photo can be deleted by
        // another page. this checks to make sure a display photo has been established before the
        // switched_to call.
        assert (get_photo () != null);

        base.switched_to ();

        update_zoom_menu_item_sensitivity ();
    }

    protected override Gdk.Pixbuf? get_bottom_left_trinket (int scale) {
        return null;
    }

    protected override Gdk.Pixbuf? get_top_right_trinket (int scale) {
        if (!has_photo () || ! ((LibraryPhoto) get_photo ()).is_flagged ())
            return null;

        return Resources.get_flag_trinket ();
    }

    private void on_slideshow () {
        LibraryPhoto? photo = (LibraryPhoto? ) get_photo ();
        if (photo == null)
            return;

        AppWindow.get_instance ().go_fullscreen (new SlideshowPage (LibraryPhoto.global, view,
                                                photo));
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

    protected override bool on_zoom_slider_key_press (Gdk.EventKey event) {
        if (base.on_zoom_slider_key_press (event))
            return true;

        if (Gdk.keyval_name (event.keyval) == "Escape") {
            return_to_collection ();
            return true;
        } else {
            return false;
        }
    }

    protected override void update_ui (bool missing) {
        bool sensitivity = !missing;

        set_action_sensitive ("Publish", sensitivity);
        set_action_sensitive ("Print", sensitivity);
        set_action_sensitive ("CommonJumpToFile", sensitivity);

        ((SimpleAction) AppWindow.get_instance ().lookup_action (AppWindow.ACTION_UNDO)).set_enabled (sensitivity);
        ((SimpleAction) AppWindow.get_instance ().lookup_action (AppWindow.ACTION_REDO)).set_enabled (sensitivity);

        set_action_sensitive ("IncreaseSize", sensitivity);
        set_action_sensitive ("DecreaseSize", sensitivity);
        set_action_sensitive ("ZoomFit", sensitivity);
        set_action_sensitive ("Zoom100", sensitivity);
        set_action_sensitive ("Zoom200", sensitivity);
        set_action_sensitive ("Slideshow", sensitivity);

        set_action_sensitive ("RotateClockwise", sensitivity);
        set_action_sensitive ("RotateCounterclockwise", sensitivity);
        set_action_sensitive ("FlipHorizontally", sensitivity);
        set_action_sensitive ("FlipVertically", sensitivity);
        set_action_sensitive ("Enhance", sensitivity);
        set_action_sensitive ("Crop", sensitivity);
        set_action_sensitive ("RedEye", sensitivity);
        set_action_sensitive ("Adjust", sensitivity);
        set_action_sensitive ("AdjustDateTime", sensitivity);
        set_action_sensitive ("OpenWith", sensitivity);
        set_action_sensitive ("OpenWithRaw", sensitivity);
        set_action_sensitive ("Revert", sensitivity);

        set_action_sensitive ("Flag", sensitivity);

        base.update_ui (missing);
    }

    protected override void notify_photo_backing_missing (Photo photo, bool missing) {
        if (missing)
            ((LibraryPhoto) photo).mark_offline ();
        else
            ((LibraryPhoto) photo).mark_online ();

        base.notify_photo_backing_missing (photo, missing);
    }

    public override bool key_press_event (Gdk.EventKey event) {
        if (base.key_press_event != null && base.key_press_event (event) == true)
            return true;

        bool handled = true;
        switch (Gdk.keyval_name (event.keyval)) {
        case "Escape":
        case "Return":
        case "KP_Enter":
            if (! (get_container () is FullscreenWindow))
                return_to_collection ();
            break;

        case "Delete":
        case "BackSpace":
            // although bound as an accelerator in the menu, accelerators are currently
            // unavailable in fullscreen mode (a variant of #324), so we do this manually
            // here
            activate_action ("MoveToTrash");
            break;


        case "bracketright":
            activate_action ("RotateClockwise");
            break;

        case "bracketleft":
            activate_action ("RotateCounterclockwise");
            break;

        case "slash":
            activate_action ("Flag");
            break;

        default:
            handled = false;
            break;
        }

        return handled;
    }

    protected override bool on_double_click (Gdk.EventButton event) {
        if (! (get_container () is FullscreenWindow)) {
            return_to_collection_on_release = true;

            return true;
        }

        AppWindow.get_instance ().end_fullscreen ();

        return base.on_double_click (event);
    }

    protected override bool on_left_released (Gdk.EventButton event) {
        if (return_to_collection_on_release) {
            return_to_collection_on_release = false;
            return_to_collection ();

            return true;
        }

        return base.on_left_released (event);
    }

    private Gtk.Menu get_context_menu () {
        if (item_context_menu == null) {
            item_context_menu = new Gtk.Menu ();

            var metadata_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("Edit Photo In_fo"));
            var metadata_action = get_common_action ("CommonDisplayMetadataSidebar");
            metadata_action.bind_property ("active", metadata_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);

            var revert_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.REVERT_MENU);
            var revert_action = get_action ("Revert");
            revert_action.bind_property ("sensitive", revert_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            revert_menu_item.activate.connect (() => revert_action.activate ());

            var copy_color_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.COPY_ADJUSTMENTS_MENU);
            var copy_color_action = get_action ("CopyColorAdjustments");
            copy_color_action.bind_property ("sensitive", copy_color_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            copy_color_menu_item.activate.connect (() => copy_color_action.activate ());

            var paste_color_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.PASTE_ADJUSTMENTS_MENU);
            var paste_color_action = get_action ("PasteColorAdjustments");
            paste_color_action.bind_property ("sensitive", paste_color_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            paste_color_menu_item.activate.connect (() => paste_color_action.activate ());

            var flag_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.FLAG_MENU);
            var flag_action = get_action ("Flag");
            flag_action.bind_property ("sensitive", flag_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            flag_menu_item.activate.connect (() => flag_action.activate ());

            var raw_developer_app_menu_item = new Gtk.MenuItem.with_mnemonic (RawDeveloper.SHOTWELL.get_label ());
            var raw_developer_app_action = get_action ("RawDeveloperShotwell");
            raw_developer_app_action.bind_property ("sensitive", raw_developer_app_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            raw_developer_app_menu_item.activate.connect (() => raw_developer_app_action.activate ());

            var raw_developer_camera_menu_item = new Gtk.MenuItem.with_mnemonic (RawDeveloper.CAMERA.get_label ());
            var raw_developer_camera_action = get_action ("RawDeveloperCamera");
            raw_developer_camera_action.bind_property ("sensitive", raw_developer_camera_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            raw_developer_camera_menu_item.activate.connect (() => raw_developer_camera_action.activate ());

            var raw_developer_menu_item = new Gtk.MenuItem.with_mnemonic (_("_Developer"));
            var raw_developer_action = get_action ("RawDeveloper");
            raw_developer_action.bind_property ("sensitive", raw_developer_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            open_menu = new Gtk.Menu ();
            var raw_developer_menu = new Gtk.Menu ();
            raw_developer_menu.add (raw_developer_app_menu_item);
            raw_developer_menu.add (raw_developer_camera_menu_item);
            raw_developer_menu_item.set_submenu (raw_developer_menu);

            var adjust_datetime_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.ADJUST_DATE_TIME_MENU);
            var adjust_datetime_action = get_action ("AdjustDateTime");
            adjust_datetime_action.bind_property ("sensitive", adjust_datetime_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            adjust_datetime_menu_item.activate.connect (() => adjust_datetime_action.activate ());

            open_menu = new Gtk.Menu ();

            var open_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.OPEN_WITH_MENU);
            open_menu_item.set_submenu (open_menu);

            open_raw_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.OPEN_WITH_RAW_MENU);
            var open_raw_action = get_action ("OpenWithRaw");
            open_raw_action.bind_property ("sensitive", open_raw_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            open_raw_menu = new Gtk.Menu ();
            open_raw_menu_item.set_submenu (open_raw_menu);

            var jump_event_menu_item = new Gtk.MenuItem.with_mnemonic (_("View Eve_nt for Photo"));
            var jump_event_action = get_common_action ("CommonJumpToEvent");
            jump_event_action.bind_property ("sensitive", jump_event_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            jump_event_menu_item.activate.connect (() => jump_event_action.activate ());

            var print_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.PRINT_MENU);
            var print_action = get_action ("Print");
            print_action.bind_property ("sensitive", print_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            print_menu_item.activate.connect (() => print_action.activate ());

            var export_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.EXPORT_MENU);
            var export_action = get_action ("Export");
            export_action.bind_property ("sensitive", export_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            export_menu_item.activate.connect (() => export_action.activate ());

            var contractor_menu_item = new Gtk.MenuItem.with_mnemonic (_("Other Actions"));
            contractor_menu = new Gtk.Menu ();
            contractor_menu_item.set_submenu (contractor_menu);

            var remove_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.REMOVE_FROM_LIBRARY_MENU);
            var remove_action = get_action ("RemoveFromLibrary");
            remove_action.bind_property ("sensitive", remove_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            remove_menu_item.activate.connect (() => remove_action.activate ());

            var trash_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.MOVE_TO_TRASH_MENU);
            var trash_action = get_action ("MoveToTrash");
            trash_action.bind_property ("sensitive", trash_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            trash_menu_item.activate.connect (() => trash_action.activate ());

            contractor_menu.add (print_menu_item);
            contractor_menu.add (export_menu_item);

            item_context_menu.add (adjust_datetime_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (open_menu_item);
            item_context_menu.add (open_raw_menu_item);
            item_context_menu.add (contractor_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (copy_color_menu_item);
            item_context_menu.add (paste_color_menu_item);
            item_context_menu.add (revert_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (flag_menu_item);
            item_context_menu.add (raw_developer_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (jump_event_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (metadata_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (remove_menu_item);
            item_context_menu.add (trash_menu_item);
            item_context_menu.show_all ();
        }

        populate_external_app_menu (open_menu, false);

        Photo? photo = (view.get_selected_at (0).get_source () as Photo);
        if (photo != null && photo.get_master_file_format () == PhotoFileFormat.RAW) {
            populate_external_app_menu (open_raw_menu, true);
        }

        open_raw_menu_item.visible = get_action ("OpenWithRaw").sensitive;

        populate_contractor_menu (contractor_menu);
        return item_context_menu;
    }

    protected override bool on_context_buttonpress (Gdk.EventButton event) {
        popup_context_menu (get_context_menu (), event);

        return true;
    }

    protected override bool on_context_keypress () {
        popup_context_menu (get_context_menu ());

        return true;
    }

    private void populate_external_app_menu (Gtk.Menu menu, bool raw) {
        SortedList<AppInfo> external_apps;
        string[] mime_types;

        foreach (Gtk.Widget item in menu.get_children ()) {
            menu.remove (item);
        }

        // get list of all applications for the given mime types
        if (raw) {
            mime_types = PhotoFileFormat.RAW.get_mime_types ();
        } else {
            mime_types = PhotoFileFormat.get_editable_mime_types ();

            var files_appinfo = AppInfo.get_default_for_type ("inode/directory", true);

            var files_item_icon = new Gtk.Image.from_gicon (files_appinfo.get_icon (), Gtk.IconSize.MENU);
            files_item_icon.pixel_size = 16;

            var menuitem_grid = new Gtk.Grid ();
            menuitem_grid.add (files_item_icon);
            menuitem_grid.add (new Gtk.Label (files_appinfo.get_name ()));

            var jump_menu_item = new Gtk.MenuItem ();
            jump_menu_item.add (menuitem_grid);

            var jump_action = get_common_action ("CommonJumpToFile");
            jump_action.bind_property ("sensitive", jump_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            jump_menu_item.activate.connect (() => jump_action.activate ());

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

            item_app.activate.connect ( () => {
                if (raw)
                    on_open_with_raw (app.get_commandline ());
                else
                    on_open_with (app.get_commandline ());
            });
            menu.add (item_app);
        }
        menu.show_all ();
    }

    private void on_open_with (string app) {
        if (!has_photo ())
            return;

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
        if (!has_photo ())
            return;

        if (get_photo ().get_master_file_format () != PhotoFileFormat.RAW)
            return;

        try {
            AppWindow.get_instance ().set_busy_cursor ();
            get_photo ().open_with_raw_external_editor (app);
            AppWindow.get_instance ().set_normal_cursor ();
        } catch (Error err) {
            AppWindow.get_instance ().set_normal_cursor ();
            AppWindow.error_message (Resources.launch_editor_failed (err));
        }
    }

    private void return_to_collection () {
        // Return to the previous page if it exists.
        if (null != return_page)
            LibraryWindow.get_app ().switch_to_page (return_page);
        else
            LibraryWindow.get_app ().switch_to_library_page ();
    }

    private void on_remove_from_library () {
        LibraryPhoto photo = (LibraryPhoto) get_photo ();

        Gee.Collection<LibraryPhoto> photos = new Gee.ArrayList<LibraryPhoto> ();
        photos.add (photo);

        remove_from_app (photos, _ ("Remove From Library"), _ ("Removing Photo From Library"), false);
    }

    private void on_move_to_trash () {
        if (!has_photo ())
            return;

        // Temporarily prevent the application from switching pages if we're viewing
        // the current photo from within an Event page.  This is needed because the act of
        // trashing images from an Event causes it to be renamed, which causes it to change
        // positions in the sidebar, and the selection moves with it, causing the app to
        // inappropriately switch to the Event page.
        if (return_page is EventPage) {
            LibraryWindow.get_app ().set_page_switching_enabled (false);
        }

        LibraryPhoto photo = (LibraryPhoto) get_photo ();

        Gee.Collection<LibraryPhoto> photos = new Gee.ArrayList<LibraryPhoto> ();
        photos.add (photo);

        // move on to next photo before executing
        on_next_photo ();

        // this indicates there is only one photo in the controller, or about to be zero, so switch
        // to the library page, which is guaranteed to be there when this disappears
        if (photo.equals (get_photo ())) {
            // If this is the last photo in an Event, then trashing it
            // _should_ cause us to switch pages, so re-enable it here.
            LibraryWindow.get_app ().set_page_switching_enabled (true);

            if (get_container () is FullscreenWindow)
                ((FullscreenWindow) get_container ()).close ();

            LibraryWindow.get_app ().switch_to_library_page ();
        }

        get_command_manager ().execute (new TrashUntrashPhotosCommand (photos, true));
        LibraryWindow.get_app ().set_page_switching_enabled (true);
    }

    private void on_flag_unflag () {
        if (has_photo ()) {
            var photo_list = new Gee.ArrayList<MediaSource> ();
            photo_list.add (get_photo ());
            get_command_manager ().execute (new FlagUnflagCommand (photo_list,
                                           ! ((LibraryPhoto) get_photo ()).is_flagged ()));
        }
    }

    private void on_photo_destroyed (DataSource source) {
        on_photo_removed ((LibraryPhoto) source);
    }

    private void on_photo_removed (LibraryPhoto photo) {
        // only interested in current photo
        if (photo == null || !photo.equals (get_photo ()))
            return;

        // move on to the next one in the collection
        on_next_photo ();
        if (photo.equals (get_photo ())) {
            // this indicates there is only one photo in the controller, or now zero, so switch
            // to the Photos page, which is guaranteed to be there
            LibraryWindow.get_app ().switch_to_library_page ();
        }
    }

    private void on_print () {
        if (view.get_selected_count () > 0) {
            PrintManager.get_instance ().spool_photo (
                (Gee.Collection<Photo>) view.get_selected_sources_of_type (typeof (Photo)));
        }
    }

    private void on_export () {
        if (!has_photo ())
            return;

        ExportDialog export_dialog = new ExportDialog (_ ("Export Photo"));

        int scale;
        ScaleConstraint constraint;
        ExportFormatParameters export_params = ExportFormatParameters.last ();
        if (!export_dialog.execute (out scale, out constraint, ref export_params))
            return;

        File save_as =
            ExportUI.choose_file (get_photo ().get_export_basename_for_parameters (export_params));
        if (save_as == null)
            return;

        Scaling scaling = Scaling.for_constraint (constraint, scale, false);

        try {
            get_photo ().export (save_as, scaling, export_params.quality,
                                get_photo ().get_export_format_for_parameters (export_params),
                                export_params.mode == ExportFormatMode.UNMODIFIED, export_params.export_metadata);
        } catch (Error err) {
            AppWindow.error_message (_ ("Unable to export %s: %s").printf (save_as.get_path (), err.message));
        }
    }

    private void on_publish () {
        if (view.get_count () > 0)
            PublishingUI.PublishingDialog.go (
                (Gee.Collection<MediaSource>) view.get_selected_sources ());
    }

    private void on_view_menu () {
        update_zoom_menu_item_sensitivity ();
    }

    private void update_development_menu_item_sensitivity () {
        PhotoFileFormat format = get_photo ().get_master_file_format () ;
        set_action_sensitive ("RawDeveloper", format == PhotoFileFormat.RAW);

        if (format == PhotoFileFormat.RAW) {
            // Set which developers are available.
            set_action_sensitive ("RawDeveloperShotwell",
                                  get_photo ().is_raw_developer_available (RawDeveloper.SHOTWELL));
            set_action_sensitive ("RawDeveloperCamera",
                                  get_photo ().is_raw_developer_available (RawDeveloper.EMBEDDED) ||
                                  get_photo ().is_raw_developer_available (RawDeveloper.CAMERA));;

            // Set active developer in menu.
            switch (get_photo ().get_raw_developer ()) {
            case RawDeveloper.SHOTWELL:
                activate_action ("RawDeveloperShotwell");
                break;

            case RawDeveloper.CAMERA:
            case RawDeveloper.EMBEDDED:
                activate_action ("RawDeveloperCamera");
                break;

            default:
                assert_not_reached ();
            }
        }
    }

    private void on_metadata_altered (Gee.Map<DataObject, Alteration> map) {
        if (has_photo ())
            update_enhance_action ();
        if (map.has_key (get_photo ()) && map.get (get_photo ()).has_subject ("metadata"))
            repaint ();
    }
}
