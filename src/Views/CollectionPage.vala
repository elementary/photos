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

public abstract class CollectionPage : MediaPage {
    private const double DESKTOP_SLIDESHOW_TRANSITION_SEC = 2.0;

    private enum TargetType {
        GNOME_COPIED_FILES,
        TEXT_URI_LIST
    }

    private const Gtk.TargetEntry [] COPY_TARGETS = {
        {"x-special/gnome-copied-files", Gtk.TargetFlags.OTHER_APP, TargetType.GNOME_COPIED_FILES},
        {"text/uri-list", Gtk.TargetFlags.OTHER_APP, TargetType.TEXT_URI_LIST}
    };

    private static List<Photo> copied_photos = null;
    private static Gtk.Clipboard? clipboard = null;

    protected class CollectionSearchViewFilter : DefaultSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.FLAG |
                   SearchFilterCriteria.MEDIA;
        }
    }

    private ExporterUI exporter = null;
    private CollectionSearchViewFilter search_filter = new CollectionSearchViewFilter ();
    private Gtk.ToggleButton? enhance_button = null;
    private Gtk.Menu item_context_menu;
    private Gtk.Menu contractor_submenu;
    private Gtk.Button rotate_button;
    private Gtk.Button flip_button;

    protected CollectionPage (string page_name) {
        Object (page_name: page_name);
    }

    static construct {
        clipboard = Gtk.Clipboard.get_for_display (Gdk.Display.get_default (), Gdk.SELECTION_CLIPBOARD);
    }

    construct {
        get_view ().items_altered.connect (on_photos_altered);

        show_all ();
    }

    public override void add_toolbar_widgets (Gtk.ActionBar toolbar) {
        var slideshow_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic",
                                                              Gtk.IconSize.LARGE_TOOLBAR);
        slideshow_button.tooltip_text = _("Play a slideshow");
        slideshow_button.clicked.connect (on_slideshow);

        rotate_button = new Gtk.Button.from_icon_name (Resources.CLOCKWISE, Gtk.IconSize.LARGE_TOOLBAR);
        rotate_button.tooltip_text = Resources.ROTATE_CW_TOOLTIP; // Will be used be screen reader if no label
        rotate_button.clicked.connect (on_rotate_clockwise);

        var rotate_action = get_action ("RotateClockwise");
        rotate_action.bind_property ("sensitive", rotate_button, "sensitive", BindingFlags.SYNC_CREATE);

        flip_button = new Gtk.Button.from_icon_name (Resources.HFLIP, Gtk.IconSize.LARGE_TOOLBAR);
        flip_button.tooltip_text = Resources.HFLIP_TOOLTIP;
        flip_button.clicked.connect (on_flip_horizontally);

        var flip_action = get_action ("FlipHorizontally");
        flip_action.bind_property ("sensitive", flip_button, "sensitive", BindingFlags.SYNC_CREATE);

        enhance_button = new Gtk.ToggleButton ();
        enhance_button.image = new Gtk.Image.from_icon_name (Resources.ENHANCE, Gtk.IconSize.LARGE_TOOLBAR);
        enhance_button.tooltip_text = Resources.ENHANCE_TOOLTIP;
        enhance_button.clicked.connect (on_enhance);

        var zoom_assembly = new SliderAssembly (Thumbnail.MIN_SCALE,
                                                Thumbnail.MAX_SCALE,
                                                MediaPage.MANUAL_STEPPING, 0);

        connect_slider (zoom_assembly);

        show_sidebar_button = MediaPage.create_sidebar_button ();
        show_sidebar_button.clicked.connect (on_show_sidebar);

        toolbar.pack_start (slideshow_button);
        toolbar.pack_start (rotate_button);
        toolbar.pack_start (flip_button);
        toolbar.pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        toolbar.pack_start (enhance_button);
        toolbar.pack_end (show_sidebar_button);
        toolbar.pack_end (zoom_assembly);

        var app = AppWindow.get_instance () as LibraryWindow;
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
        base.add_toolbar_widgets (toolbar);
    }

    public override Gtk.Menu? get_item_context_menu () {
        if (item_context_menu == null) {
            item_context_menu = new Gtk.Menu () {
                attach_widget = this
            };

            var copy_images_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.COPY_IMAGE_LABEL);
            var copy_images_action = get_action ("CopyImages");
            copy_images_menu_item.activate.connect (() => copy_images_action.activate ());

            var metadata_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("Edit Photo In_fo"));
            var metadata_action = get_common_action ("CommonDisplayMetadataSidebar");
            metadata_action.bind_property ("active", metadata_menu_item, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

            var revert_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.REVERT_MENU);
            var revert_action = get_action ("Revert");
            revert_action.bind_property ("sensitive", revert_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            revert_menu_item.activate.connect (() => revert_action.activate ());

            var duplicate_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.DUPLICATE_PHOTO_MENU);
            var duplicate_action = get_action ("Duplicate");
            duplicate_action.bind_property ("sensitive", duplicate_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            duplicate_menu_item.activate.connect (() => duplicate_action.activate ());

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

            var raw_developer_menu = new Gtk.Menu ();
            raw_developer_menu.add (raw_developer_app_menu_item);
            raw_developer_menu.add (raw_developer_camera_menu_item);
            raw_developer_menu_item.set_submenu (raw_developer_menu);

            var adjust_datetime_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.ADJUST_DATE_TIME_MENU);
            var adjust_datetime_action = get_action ("AdjustDateTime");
            adjust_datetime_action.bind_property ("sensitive", adjust_datetime_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            adjust_datetime_menu_item.activate.connect (() => adjust_datetime_action.activate ());

            var open_menu_item = new Gtk.MenuItem.with_label (_("Show in Files")) {
                action_name = AppWindow.ACTION_PREFIX + AppWindow.ACTION_JUMP_TO_FILE
            };

            var new_event_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.NEW_EVENT_MENU);
            var new_event_action = get_action ("NewEvent");
            new_event_action.bind_property ("sensitive", new_event_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            new_event_menu_item.activate.connect (() => new_event_action.activate ());

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

            var remove_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.REMOVE_FROM_LIBRARY_MENU);
            var remove_action = get_action ("RemoveFromLibrary");
            remove_action.bind_property ("sensitive", remove_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            remove_menu_item.activate.connect (() => remove_action.activate ());

            var trash_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.MOVE_TO_TRASH_MENU);
            var trash_action = get_action ("MoveToTrash");
            trash_action.bind_property ("sensitive", trash_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            trash_menu_item.activate.connect (() => trash_action.activate ());

            var contractor_menu_item = new Gtk.MenuItem.with_mnemonic (_("Other Actions"));
            contractor_submenu = new Gtk.Menu ();
            contractor_menu_item.set_submenu (contractor_submenu);
            contractor_submenu.add (print_menu_item);
            contractor_submenu.add (export_menu_item);

            var source = get_view ().get_selected_at (0).source;
            if (source != null && source is Photo) {
                var file = ((Photo) source).get_file ();
                if (file != null) {
                    var wallpaper_menuitem = new Gtk.MenuItem.with_label (_("Set as Wallpaper")) {
                        action_name = AppWindow.ACTION_PREFIX + AppWindow.ACTION_SET_WALLPAPER,
                        action_target = new Variant.string (file.get_uri ())
                    };
                    contractor_submenu.add (wallpaper_menuitem);
                }
            }

            item_context_menu.add (copy_images_menu_item);
            item_context_menu.add (adjust_datetime_menu_item);
            item_context_menu.add (duplicate_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (open_menu_item);
            item_context_menu.add (contractor_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (copy_color_menu_item);
            item_context_menu.add (paste_color_menu_item);
            item_context_menu.add (revert_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (flag_menu_item);
            item_context_menu.add (raw_developer_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (new_event_menu_item);
            item_context_menu.add (jump_event_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (metadata_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (remove_menu_item);
            item_context_menu.add (trash_menu_item);
            item_context_menu.show_all ();
        }

        populate_contractor_menu (contractor_submenu);
        return item_context_menu;
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry print = { "Print", null, null, "<Ctrl>P", null, on_print };
        Gtk.ActionEntry rotate_right = { "RotateClockwise", null, null, "<Ctrl>R", null, on_rotate_clockwise };
        Gtk.ActionEntry rotate_left = { "RotateCounterclockwise", null, null, "<Ctrl><Shift>R", null, on_rotate_counterclockwise };
        Gtk.ActionEntry hflip = { "FlipHorizontally", null, null, null, null, on_flip_horizontally };
        Gtk.ActionEntry vflip = { "FlipVertically", null, null, null, null, on_flip_vertically };
        Gtk.ActionEntry copy_adjustments = { "CopyColorAdjustments", null, null, "<Ctrl><Shift>C", null, on_copy_adjustments };
        Gtk.ActionEntry paste_adjustments = { "PasteColorAdjustments", null, null, "<Ctrl><Shift>V", null, on_paste_adjustments };
        Gtk.ActionEntry revert = { "Revert", null, null, null, null, on_revert };
        Gtk.ActionEntry duplicate = { "Duplicate", null, null, "<Ctrl>D", null, on_duplicate_photo };
        Gtk.ActionEntry adjust_date_time = { "AdjustDateTime", null, null, null, null, on_adjust_date_time };
        Gtk.ActionEntry open_with = { "OpenWith", null, null, null, null, null };
        Gtk.ActionEntry open_with_raw = { "OpenWithRaw", null, null, null, null, null };
        Gtk.ActionEntry enhance = { "Enhance", null, null, "<Ctrl>E", null, on_enhance };
        Gtk.ActionEntry slideshow = { "Slideshow", null, null, "F5", null, on_slideshow };
        Gtk.ActionEntry copy = { "CopyImages", null, null, "<Ctrl>C", null, on_copy_images };

        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();
        actions += copy;
        actions += print;
        actions += rotate_right;
        actions += rotate_left;
        actions += hflip;
        actions += vflip;
        actions += copy_adjustments;
        actions += paste_adjustments;
        actions += revert;
        actions += duplicate;
        actions += adjust_date_time;
        actions += open_with;
        actions += open_with_raw;
        actions += enhance;
        actions += slideshow;

        return actions;
    }

    public void set_action_details (string name, string? label, string? tooltip, bool sensitive) {
        Gtk.Action? action = get_action (name);
        if (action == null)
            return;

        if (label != null)
            action.label = label;

        if (tooltip != null)
            action.tooltip = tooltip;

        action.sensitive = sensitive;
    }

    // Default behaviour for "Copy" action from Collection (thumbnail) view.
    public static void get_image_data_for_clipboard (Gtk.Clipboard cb,
                                                     Gtk.SelectionData sd,
                                                     uint info,
                                                     void* parent) {
        if (copied_photos == null) { // Should not happen
            critical ("Attempt to copy image but data for clipboard is null");
            return;
        }

        switch (info) {
            case TargetType.GNOME_COPIED_FILES: /* Pasting into a file handler */
                var sb = new StringBuilder ("copy "); // Only support copying for now
                // Note the original file will be copied (may not include transformations);
                foreach (var photo in copied_photos) {
                    sb.append ("\r\n");
                    sb.append (photo.get_file ().get_uri ());
                }
                sd.@set (sd.get_target (), 8, sb.data);
                break;

            case TargetType.TEXT_URI_LIST:
                string[] uris = {};
                foreach (var photo in copied_photos) {
                    uris += photo.get_file ().get_uri ();
                }

                sd.set_uris (uris); // GitHub requests this but only uses the first uri for some reason.
                break;

            default:
                warning ("Unknown target type");
                break;
        }
    }

    public static void clear_data_for_clipboard (Gtk.Clipboard cb, void* parent) {
        copied_photos = null;
    }

    private void on_copy_images () {
        clipboard.clear ();

        foreach (DataSource source in get_view ().get_selected_sources ()) {
            Photo? photo = source as Photo;
            if (photo != null) {
                copied_photos.append (photo);
            }
        }

        if (copied_photos == null) {
            return;
        }

        clipboard.set_with_owner (COPY_TARGETS, get_image_data_for_clipboard, clear_data_for_clipboard, this);
    }

    private bool selection_has_video () {
        return MediaSourceCollection.has_video ((Gee.Collection<MediaSource>) get_view ().get_selected_sources ());
    }

    private bool page_has_photo () {
        return MediaSourceCollection.has_photo ((Gee.Collection<MediaSource>) get_view ().get_sources ());
    }

    private bool selection_has_photo () {
        return MediaSourceCollection.has_photo ((Gee.Collection<MediaSource>) get_view ().get_selected_sources ());
    }

    protected override void init_actions (int selected_count, int count) {
        base.init_actions (selected_count, count);
    }

    protected override void update_actions (int selected_count, int count) {
        base.update_actions (selected_count, count);

        bool one_selected = selected_count == 1;
        bool has_selected = selected_count > 0;

        bool primary_is_video = false;
        if (has_selected)
            if (get_view ().get_selected_at (0).source is Video)
                primary_is_video = true;

        bool selection_has_videos = selection_has_video ();
        bool page_has_photos = page_has_photo ();

        // don't allow duplication of the selection if it contains a video -- videos are huge and
        // and they're not editable anyway, so there seems to be no use case for duplicating them
        set_action_sensitive ("Duplicate", has_selected && (!selection_has_videos));
        set_action_visible ("OpenWith", (!primary_is_video));
        set_action_sensitive ("OpenWith", one_selected);
        set_action_visible ("OpenWithRaw",
                            one_selected && (!primary_is_video)
                            && ((Photo) get_view ().get_selected_at (0).source).get_master_file_format () ==
                            PhotoFileFormat.RAW);
        set_action_sensitive ("Revert", (!selection_has_videos) && can_revert_selected ());
        set_action_sensitive ("Enhance", (!selection_has_videos) && has_selected);
        set_action_sensitive ("CopyColorAdjustments", (!selection_has_videos) && one_selected &&
                              ((Photo) get_view ().get_selected_at (0).source).has_color_adjustments ());
        set_action_sensitive ("PasteColorAdjustments", (!selection_has_videos) && has_selected &&
                              PixelTransformationBundle.has_copied_color_adjustments ());
        set_action_sensitive ("RotateClockwise", (!selection_has_videos) && has_selected);
        set_action_sensitive ("RotateCounterclockwise", (!selection_has_videos) && has_selected);
        set_action_sensitive ("FlipHorizontally", (!selection_has_videos) && has_selected);
        set_action_sensitive ("FlipVertically", (!selection_has_videos) && has_selected);

        // Allow changing of exposure time, even if there's a video in the current
        // selection.
        set_action_sensitive ("AdjustDateTime", has_selected);

        set_action_sensitive ("NewEvent", has_selected);
        set_action_sensitive ("Slideshow", page_has_photos && (!primary_is_video));
        set_action_sensitive ("Print", (!selection_has_videos) && has_selected);
        if (enhance_button != null) {
            enhance_button.sensitive = (!selection_has_videos) && has_selected;
            update_enhance_toggled ();
        }
    }

    private void on_photos_altered (Gee.Map<DataObject, Alteration> altered) {
        // only check for revert if the media object is a photo and its image has changed in some
        // way and it's in the selection
        foreach (DataObject object in altered.keys) {
            DataView view = (DataView) object;

            if (!view.is_selected () || !altered.get (view).has_subject ("image"))
                continue;

            LibraryPhoto? photo = view.source as LibraryPhoto;
            if (photo == null)
                continue;

            // since the photo can be altered externally to Photos now, need to make the revert
            // command available appropriately, even if the selection doesn't change
            set_action_sensitive ("Revert", can_revert_selected ());
            set_action_sensitive ("CopyColorAdjustments", photo.has_color_adjustments ());
            update_enhance_toggled ();
            break;
        }
    }

    private void update_enhance_toggled () {
        bool toggled = false;
        foreach (DataView view in get_view ().get_selected ()) {
            Photo photo = view.source as Photo;
            if (photo != null && !photo.is_enhanced ()) {
                toggled = false;
                break;
            }
            else if (photo != null)
                toggled = true;
        }

        enhance_button.clicked.disconnect (on_enhance);
        enhance_button.active = toggled;
        enhance_button.clicked.connect (on_enhance);

        Gtk.Action? action = get_action ("Enhance");
        assert (action != null);
        action.label = toggled ? Resources.UNENHANCE_MENU : Resources.ENHANCE_MENU;

    }

    private void on_print () {
        if (get_view ().get_selected_count () > 0) {
            PrintManager.get_instance ().spool_photo (
                (Gee.Collection<Photo>) get_view ().get_selected_sources_of_type (typeof (Photo)));
        }
    }

    // see #2020
    // double clcik = switch to photo page
    // Super + double click = open in external editor
    // Enter = switch to PhotoPage
    // Ctrl + Enter = open in external editor (handled with accelerators)
    // Shift + Ctrl + Enter = open in external RAW editor (handled with accelerators)
    protected override void on_item_activated (CheckerboardItem item) {
        Thumbnail thumbnail = (Thumbnail) item;

        // none of the fancy Super, Ctrl, Shift, etc., keyboard accelerators apply to videos,
        // since they can't be RAW files or be opened in an external editor, etc., so if this is
        // a video, just play it and do a short-circuit return
        if (thumbnail.get_media_source () is Video) {
            on_play_video ();
            return;
        }

        LibraryPhoto? photo = thumbnail.get_media_source () as LibraryPhoto;
        if (photo == null)
            return;

        debug ("activating %s", photo.to_string ());
        LibraryWindow.get_app ().switch_to_photo_page (this, photo);
    }

    protected override bool on_app_key_pressed (Gdk.EventKey event) {
        bool handled = true;

        if (match_keycode (Gdk.Key.c, event.hardware_keycode)) {
            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 &&
                (event.state & Gdk.ModifierType.SHIFT_MASK) == 0) {

                activate_action ("CopyImages");
            }
        }

        switch (Gdk.keyval_name (event.keyval)) {
        case "Page_Up":
        case "KP_Page_Up":
        case "Page_Down":
        case "KP_Page_Down":
        case "Home":
        case "KP_Home":
        case "End":
        case "KP_End":
            key_press_event (event);
            break;
        case "bracketright":
            activate_action ("RotateClockwise");
            break;

        case "bracketleft":
            activate_action ("RotateCounterclockwise");
            break;

        default:
            handled = false;
            break;
        }

        return handled ? true : base.on_app_key_pressed (event);
    }

    protected override void on_export () {
        if (exporter != null)
            return;

        Gee.Collection<MediaSource> export_list =
            (Gee.Collection<MediaSource>) get_view ().get_selected_sources ();
        if (export_list.size == 0)
            return;

        bool has_some_photos = selection_has_photo ();
        bool has_some_videos = selection_has_video ();
        assert (has_some_photos || has_some_videos);

        // if we don't have any photos, then everything is a video, so skip displaying the Export
        // dialog and go right to the video export operation
        if (!has_some_photos) {
            exporter = Video.export_many ((Gee.Collection<Video>) export_list, on_export_completed);
            return;
        }

        string title = null;
        if (has_some_videos)
            title = ngettext ("Export Photo/Video", "Export Photos/Videos", export_list.size);
        else
            title = ngettext ("Export Photo", "Export Photos", export_list.size);

        ExportDialog export_dialog = new ExportDialog (title);

        // Setting up the parameters object requires a bit of thinking about what the user wants.
        // If the selection contains only photos, then we do what we've done in previous versions
        // of Photos -- we use whatever settings the user selected on his last export operation
        // (the thinking here being that if you've been exporting small PNGs for your blog
        // for the last n export operations, then it's likely that for your (n + 1)-th export
        // operation you'll also be exporting a small PNG for your blog). However, if the selection
        // contains any videos, then we set the parameters to the "Current" operating mode, since
        // videos can't be saved as PNGs (or any other specific photo format).
        ExportFormatParameters export_params = (has_some_videos) ? ExportFormatParameters.current () :
                                               ExportFormatParameters.last ();

        int scale;
        ScaleConstraint constraint;
        if (!export_dialog.execute (out scale, out constraint, ref export_params))
            return;

        Scaling scaling = Scaling.for_constraint (constraint, scale, false);

        // handle the single-photo case, which is treated like a Save As file operation
        if (export_list.size == 1) {
            LibraryPhoto photo = null;
            foreach (LibraryPhoto p in (Gee.Collection<LibraryPhoto>) export_list) {
                photo = p;
                break;
            }

            File save_as =
                ExportUI.choose_file (photo.get_export_basename_for_parameters (export_params));
            if (save_as == null)
                return;

            try {
                AppWindow.get_instance ().set_busy_cursor ();
                photo.export (save_as, scaling, export_params.quality,
                              photo.get_export_format_for_parameters (export_params), export_params.mode ==
                              ExportFormatMode.UNMODIFIED, export_params.export_metadata);
                AppWindow.get_instance ().set_normal_cursor ();
            } catch (Error err) {
                AppWindow.get_instance ().set_normal_cursor ();
                export_error_dialog (save_as, false);
            }

            return;
        }

        // multiple photos or videos
        File export_dir = ExportUI.choose_dir (title);
        if (export_dir == null)
            return;

        exporter = new ExporterUI (new Exporter (export_list, export_dir, scaling, export_params));
        exporter.export (on_export_completed);
    }

    private void on_export_completed () {
        exporter = null;
    }

    private bool can_revert_selected () {
        foreach (DataSource source in get_view ().get_selected_sources ()) {
            LibraryPhoto? photo = source as LibraryPhoto;
            if (photo != null && (photo.has_transformations () || photo.has_editable ()))
                return true;
        }

        return false;
    }

    private bool can_revert_editable_selected () {
        foreach (DataSource source in get_view ().get_selected_sources ()) {
            LibraryPhoto? photo = source as LibraryPhoto;
            if (photo != null && photo.has_editable ())
                return true;
        }

        return false;
    }

    private void on_show_sidebar () {
        var app = AppWindow.get_instance () as LibraryWindow;
        app.set_metadata_sidebar_visible (!app.is_metadata_sidebar_visible ());
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
    }

    private void on_rotate_clockwise () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.CLOCKWISE, Resources.ROTATE_CW_FULL_LABEL, Resources.ROTATE_CW_TOOLTIP,
                _ ("Rotating"), _ ("Undoing Rotate"));
        get_command_manager ().execute (command);
    }

    private void on_rotate_counterclockwise () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.COUNTERCLOCKWISE, Resources.ROTATE_CCW_FULL_LABEL, Resources.ROTATE_CCW_TOOLTIP,
                _ ("Rotating"), _ ("Undoing Rotate"));
        get_command_manager ().execute (command);
    }

    private void on_flip_horizontally () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.MIRROR, Resources.HFLIP_LABEL, "", _ ("Flipping Horizontally"),
                _ ("Undoing Flip Horizontally"));
        get_command_manager ().execute (command);
    }

    private void on_flip_vertically () {
        if (get_view ().get_selected_count () == 0)
            return;

        RotateMultipleCommand command = new RotateMultipleCommand (get_view ().get_selected (),
                Rotation.UPSIDE_DOWN, Resources.VFLIP_LABEL, "", _ ("Flipping Vertically"),
                _ ("Undoing Flip Vertically"));
        get_command_manager ().execute (command);
    }

    private void on_revert () {
        if (get_view ().get_selected_count () == 0)
            return;

        if (can_revert_editable_selected ()) {
            if (!revert_editable_dialog (AppWindow.get_instance (),
                                         (Gee.Collection<Photo>) get_view ().get_selected_sources ())) {
                return;
            }

            foreach (DataObject object in get_view ().get_selected_sources ())
                ((Photo) object).revert_to_master ();
        }

        RevertMultipleCommand command = new RevertMultipleCommand (get_view ().get_selected ());
        get_command_manager ().execute (command);
    }

    public void on_copy_adjustments () {
        if (get_view ().get_selected_count () != 1)
            return;
        Photo photo = (Photo) get_view ().get_selected_at (0).source;
        PixelTransformationBundle.set_copied_color_adjustments (photo.get_color_adjustments ());
        set_action_sensitive ("PasteColorAdjustments", true);
    }

    public void on_paste_adjustments () {
        PixelTransformationBundle? copied_adjustments = PixelTransformationBundle.get_copied_color_adjustments ();
        if (get_view ().get_selected_count () == 0 || copied_adjustments == null)
            return;

        AdjustColorsMultipleCommand command = new AdjustColorsMultipleCommand (get_view ().get_selected (),
                copied_adjustments, Resources.PASTE_ADJUSTMENTS_LABEL, Resources.PASTE_ADJUSTMENTS_TOOLTIP);
        get_command_manager ().execute (command);
    }

    private void on_enhance () {
        if (get_view ().get_selected_count () == 0) {
            return;
        }

        /* If one photo in the selection is unenhanced, set the enhance button to untoggled.
          We also just want to execute the enhance command on the unenhanced photo so that
          we can unenhance properly those that were previously enhanced. We also need to sort out non photos */
        Gee.ArrayList<DataView> unenhanced_list = new Gee.ArrayList<DataView> ();
        Gee.ArrayList<DataView> enhanced_list = new Gee.ArrayList<DataView> ();
        foreach (DataView view in get_view ().get_selected ()) {
            Photo photo = view.source as Photo;
            if (photo != null && !photo.is_enhanced ())
                unenhanced_list.add (view);
            else if (photo != null)
                enhanced_list.add (view);
        }

        if (enhanced_list.size == 0 && unenhanced_list.size == 0)
            return;

        if (unenhanced_list.size == 0) {
            // Just undo if last on stack was enhance
            EnhanceMultipleCommand cmd = get_command_manager ().get_undo_command () as EnhanceMultipleCommand;
            if (cmd != null && cmd.get_sources () == get_view ().get_selected_sources ())
                get_command_manager ().undo ();
            else {
                UnEnhanceMultipleCommand command = new UnEnhanceMultipleCommand (enhanced_list);
                get_command_manager ().execute (command);
            }
            foreach (DataView view in enhanced_list) {
                Photo photo = view.source as Photo;
                photo.set_enhanced (false);
            }
        } else {
            // Just undo if last on stack was unenhance
            UnEnhanceMultipleCommand cmd = get_command_manager ().get_undo_command () as UnEnhanceMultipleCommand;
            if (cmd != null && cmd.get_sources () == get_view ().get_selected_sources ())
                get_command_manager ().undo ();
            else {
                EnhanceMultipleCommand command = new EnhanceMultipleCommand (unenhanced_list);
                get_command_manager ().execute (command);
            }
            foreach (DataView view in enhanced_list) {
                Photo photo = view.source as Photo;
                photo.set_enhanced (true);
            }
        }
        update_enhance_toggled ();
    }

    private void on_duplicate_photo () {
        if (get_view ().get_selected_count () == 0)
            return;

        DuplicateMultiplePhotosCommand command = new DuplicateMultiplePhotosCommand (
            get_view ().get_selected ());
        get_command_manager ().execute (command);
    }

    private void on_adjust_date_time () {
        if (get_view ().get_selected_count () == 0)
            return;

        bool selected_has_videos = false;
        bool only_videos_selected = true;

        foreach (DataView dv in get_view ().get_selected ()) {
            if (dv.source is Video)
                selected_has_videos = true;
            else
                only_videos_selected = false;
        }

        Dateable photo_source = (Dateable) get_view ().get_selected_at (0).source;

        AdjustDateTimeDialog dialog = new AdjustDateTimeDialog (photo_source,
                get_view ().get_selected_count (), true, selected_has_videos, only_videos_selected);

        int64 time_shift;
        bool keep_relativity, modify_originals;
        if (dialog.execute (out time_shift, out keep_relativity, out modify_originals)) {
            AdjustDateTimePhotosCommand command = new AdjustDateTimePhotosCommand (
                get_view ().get_selected (), time_shift, keep_relativity, modify_originals);
            get_command_manager ().execute (command);
        }
    }

    private void on_slideshow () {
        if (get_view ().get_count () == 0)
            return;

        // use first selected photo, else use first photo
        Gee.List<DataSource>? sources = (get_view ().get_selected_count () > 0)
                                        ? get_view ().get_selected_sources_of_type (typeof (LibraryPhoto))
                                        : get_view ().get_sources_of_type (typeof (LibraryPhoto));
        if (sources == null || sources.size == 0)
            return;

        Thumbnail? thumbnail = (Thumbnail? ) get_view ().get_view_for_source (sources[0]);
        if (thumbnail == null)
            return;

        LibraryPhoto? photo = thumbnail.get_media_source () as LibraryPhoto;
        if (photo == null)
            return;

        AppWindow.get_instance ().go_fullscreen (new SlideshowPage (LibraryPhoto.global, get_view (),
                                                photo));
    }

    protected override bool on_ctrl_pressed (Gdk.EventKey? event) {
        flip_button.image = new Gtk.Image.from_icon_name (Resources.VFLIP, Gtk.IconSize.LARGE_TOOLBAR);
        flip_button.tooltip_text = Resources.VFLIP_TOOLTIP;
        rotate_button.image = new Gtk.Image.from_icon_name (Resources.COUNTERCLOCKWISE, Gtk.IconSize.LARGE_TOOLBAR);
        rotate_button.tooltip_text = Resources.ROTATE_CCW_TOOLTIP;
        flip_button.clicked.disconnect (on_flip_horizontally);
        flip_button.clicked.connect (on_flip_vertically);
        rotate_button.clicked.disconnect (on_rotate_clockwise);
        rotate_button.clicked.connect (on_rotate_counterclockwise);

        return base.on_ctrl_pressed (event);
    }

    protected override bool on_ctrl_released (Gdk.EventKey? event) {
        flip_button.image = new Gtk.Image.from_icon_name (Resources.HFLIP, Gtk.IconSize.LARGE_TOOLBAR);
        flip_button.tooltip_text = Resources.HFLIP_TOOLTIP;
        rotate_button.image = new Gtk.Image.from_icon_name (Resources.CLOCKWISE, Gtk.IconSize.LARGE_TOOLBAR);
        rotate_button.tooltip_text = Resources.ROTATE_CW_TOOLTIP;
        flip_button.clicked.disconnect (on_flip_vertically);
        flip_button.clicked.connect (on_flip_horizontally);
        rotate_button.clicked.disconnect (on_rotate_counterclockwise);
        rotate_button.clicked.connect (on_rotate_clockwise);

        return base.on_ctrl_released (event);
    }

    protected override string get_view_empty_message () {
        var window = AppWindow.get_instance () as LibraryWindow;
        warn_if_fail (window != null);
        if (window != null)
            window.toggle_welcome_page (true, "", _ ("No photos/videos"));
        return _ ("No photos/videos");
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}
