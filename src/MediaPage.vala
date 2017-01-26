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

public class MediaSourceItem : CheckerboardItem {
    // preserve the same constructor arguments and semantics as CheckerboardItem so that we're
    // a drop-in replacement
    public MediaSourceItem (ThumbnailSource source, Dimensions initial_pixbuf_dim, string title,
                            string? comment, bool marked_up = false, Pango.Alignment alignment = Pango.Alignment.LEFT) {
        base (source, initial_pixbuf_dim, title, comment, marked_up, alignment);
    }
}

public abstract class MediaPage : CheckerboardPage {
    public const int SORT_ORDER_ASCENDING = 0;
    public const int SORT_ORDER_DESCENDING = 1;

    // steppings should divide evenly into (Thumbnail.MAX_SCALE - Thumbnail.MIN_SCALE)
    public const int MANUAL_STEPPING = 16;
    public const int SLIDER_STEPPING = 4;

    public enum SortBy {
        MIN = 1,
        TITLE = 1,
        EXPOSURE_DATE = 2,
        MAX = 2
    }

    protected class ZoomSliderAssembly : Gtk.ToolItem {
        private Gtk.Scale slider;
        private Gtk.Adjustment adjustment;

        public signal void zoom_changed ();

        public ZoomSliderAssembly () {
            Gtk.Box zoom_group = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            Gtk.Image zoom_out = new Gtk.Image.from_icon_name (Resources.ICON_ZOOM_OUT, Gtk.IconSize.MENU);
            Gtk.EventBox zoom_out_box = new Gtk.EventBox ();
            zoom_out_box.set_above_child (true);
            zoom_out_box.set_visible_window (false);
            zoom_out_box.add (zoom_out);
            zoom_out_box.button_press_event.connect (on_zoom_out_pressed);

            zoom_group.pack_start (zoom_out_box, false, false, 0);

            // virgin ZoomSliderAssemblies are created such that they have whatever value is
            // persisted in the configuration system for the photo thumbnail scale
            int persisted_scale = Config.Facade.get_instance ().get_photo_thumbnail_scale ();
            adjustment = new Gtk.Adjustment (ZoomSliderAssembly.scale_to_slider (persisted_scale), 0,
                                             ZoomSliderAssembly.scale_to_slider (Thumbnail.MAX_SCALE), 1, 10, 0);

            slider = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, adjustment);
            slider.value_changed.connect (on_slider_changed);
            slider.set_draw_value (false);
            slider.set_size_request (200, -1);
            slider.set_tooltip_text (_ ("Adjust the size of the thumbnails"));

            zoom_group.pack_start (slider, false, false, 0);

            Gtk.Image zoom_in = new Gtk.Image.from_icon_name (Resources.ICON_ZOOM_IN, Gtk.IconSize.MENU);
            Gtk.EventBox zoom_in_box = new Gtk.EventBox ();
            zoom_in_box.set_above_child (true);
            zoom_in_box.set_visible_window (false);
            zoom_in_box.add (zoom_in);
            zoom_in_box.button_press_event.connect (on_zoom_in_pressed);

            zoom_group.pack_start (zoom_in_box, false, false, 0);

            add (zoom_group);
        }

        public static double scale_to_slider (int value) {
            assert (value >= Thumbnail.MIN_SCALE);
            assert (value <= Thumbnail.MAX_SCALE);

            return (double) ((value - Thumbnail.MIN_SCALE) / SLIDER_STEPPING);
        }

        public static int slider_to_scale (double value) {
            int res = ((int) (value * SLIDER_STEPPING)) + Thumbnail.MIN_SCALE;

            assert (res >= Thumbnail.MIN_SCALE);
            assert (res <= Thumbnail.MAX_SCALE);

            return res;
        }

        private bool on_zoom_out_pressed (Gdk.EventButton event) {
            snap_to_min ();
            return true;
        }

        private bool on_zoom_in_pressed (Gdk.EventButton event) {
            snap_to_max ();
            return true;
        }

        private void on_slider_changed () {
            zoom_changed ();
        }

        public void snap_to_min () {
            slider.set_value (scale_to_slider (Thumbnail.MIN_SCALE));
        }

        public void snap_to_max () {
            slider.set_value (scale_to_slider (Thumbnail.MAX_SCALE));
        }

        public void increase_step () {
            int new_scale = compute_zoom_scale_increase (get_scale ());

            if (get_scale () == new_scale)
                return;

            slider.set_value (scale_to_slider (new_scale));
        }

        public void decrease_step () {
            int new_scale = compute_zoom_scale_decrease (get_scale ());

            if (get_scale () == new_scale)
                return;

            slider.set_value (scale_to_slider (new_scale));
        }

        public int get_scale () {
            return slider_to_scale (slider.get_value ());
        }

        public void set_scale (int scale) {
            if (get_scale () == scale)
                return;

            slider.set_value (scale_to_slider (scale));
        }
    }

    private ZoomSliderAssembly? connected_slider = null;
    private DragAndDropHandler dnd_handler = null;
    private MediaViewTracker tracker;

    public MediaPage (string page_name) {
        base (page_name);

        tracker = new MediaViewTracker (get_view ());
        init_page_context_menu ("/MediaViewMenu");
        get_view ().items_altered.connect (on_media_altered);

        get_view ().freeze_notifications ();
        get_view ().set_property (CheckerboardItem.PROP_SHOW_TITLES,
                                 Config.Facade.get_instance ().get_display_photo_titles ());
        get_view ().set_property (CheckerboardItem.PROP_SHOW_COMMENTS,
                                 Config.Facade.get_instance ().get_display_photo_comments ());
        get_view ().set_property (Thumbnail.PROP_SHOW_TAGS,
                                 Config.Facade.get_instance ().get_display_photo_tags ());
        get_view ().set_property (Thumbnail.PROP_SIZE, get_thumb_size ());

        get_view ().thaw_notifications ();

        // enable drag-and-drop export of media
        dnd_handler = new DragAndDropHandler (this);
    }

    private static int compute_zoom_scale_increase (int current_scale) {
        int new_scale = current_scale + MANUAL_STEPPING;
        return new_scale.clamp (Thumbnail.MIN_SCALE, Thumbnail.MAX_SCALE);
    }

    private static int compute_zoom_scale_decrease (int current_scale) {
        int new_scale = current_scale - MANUAL_STEPPING;
        return new_scale.clamp (Thumbnail.MIN_SCALE, Thumbnail.MAX_SCALE);
    }

    protected override void init_collect_ui_filenames (Gee.List<string> ui_filenames) {
        base.init_collect_ui_filenames (ui_filenames);

        ui_filenames.add ("media.ui");
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry export = { "Export", null, TRANSLATABLE, "<Ctrl><Shift>E",
                                   TRANSLATABLE, on_export
                                 };
        export.label = Resources.EXPORT_MENU;
        actions += export;

        Gtk.ActionEntry remove_from_library = { "RemoveFromLibrary", null, TRANSLATABLE,
                                                "<Shift>Delete", TRANSLATABLE, on_remove_from_library
                                              };
        remove_from_library.label = Resources.REMOVE_FROM_LIBRARY_MENU;
        actions += remove_from_library;

        Gtk.ActionEntry move_to_trash = { "MoveToTrash", "user-trash-full", TRANSLATABLE, "Delete",
                                          TRANSLATABLE, on_move_to_trash
                                        };
        move_to_trash.label = Resources.MOVE_TO_TRASH_MENU;
        actions += move_to_trash;

        Gtk.ActionEntry new_event = { "NewEvent", null, TRANSLATABLE, "<Ctrl>N",
                                      TRANSLATABLE, on_new_event
                                    };
        new_event.label = Resources.NEW_EVENT_MENU;
        actions += new_event;

        Gtk.ActionEntry increase_size = { "IncreaseSize", null, TRANSLATABLE,
                                          "<Ctrl>plus", TRANSLATABLE, on_increase_size
                                        };
        increase_size.label = _ ("Zoom _In");
        increase_size.tooltip = _ ("Increase the magnification of the thumbnails");
        actions += increase_size;

        Gtk.ActionEntry decrease_size = { "DecreaseSize", null, TRANSLATABLE,
                                          "<Ctrl>minus", TRANSLATABLE, on_decrease_size
                                        };
        decrease_size.label = _ ("Zoom _Out");
        decrease_size.tooltip = _ ("Decrease the magnification of the thumbnails");
        actions += decrease_size;

        Gtk.ActionEntry flag = { "Flag", null, TRANSLATABLE, "<Ctrl>G", TRANSLATABLE, on_flag_unflag };
        flag.label = Resources.FLAG_MENU;
        actions += flag;

        Gtk.ActionEntry sort_photos = { "SortPhotos", null, TRANSLATABLE, null, null, null };
        sort_photos.label = _ ("Sort _Photos");
        actions += sort_photos;

        Gtk.ActionEntry filter_photos = { "FilterPhotos", null, TRANSLATABLE, null, null, null };
        filter_photos.label = Resources.FILTER_PHOTOS_MENU;
        actions += filter_photos;

        Gtk.ActionEntry raw_developer = { "RawDeveloper", null, TRANSLATABLE, null, null, null };
        raw_developer.label = _ ("_Developer");
        actions += raw_developer;

        // RAW developers.

        Gtk.ActionEntry dev_shotwell = { "RawDeveloperShotwell", null, TRANSLATABLE, null, TRANSLATABLE,
                                         on_raw_developer_shotwell
                                       };
        dev_shotwell.label = _ ("Shotwell");
        actions += dev_shotwell;

        Gtk.ActionEntry dev_camera = { "RawDeveloperCamera", null, TRANSLATABLE, null, TRANSLATABLE,
                                       on_raw_developer_camera
                                     };
        dev_camera.label = _ ("Camera");
        actions += dev_camera;

        return actions;
    }

    protected override Gtk.ToggleActionEntry[] init_collect_toggle_action_entries () {
        Gtk.ToggleActionEntry[] toggle_actions = base.init_collect_toggle_action_entries ();

        Gtk.ToggleActionEntry titles = { "ViewTitle", null, TRANSLATABLE, "<Ctrl><Shift>T",
                                         TRANSLATABLE, on_display_titles, Config.Facade.get_instance ().get_display_photo_titles ()
                                       };
        titles.label = _ ("_Titles");
        titles.tooltip = _ ("Display the title of each photo");
        toggle_actions += titles;

        Gtk.ToggleActionEntry comments = { "ViewComment", null, TRANSLATABLE, "<Ctrl><Shift>C",
                                           TRANSLATABLE, on_display_comments, Config.Facade.get_instance ().get_display_photo_comments ()
                                         };
        comments.label = _ ("_Comments");
        comments.tooltip = _ ("Display the comment of each photo");
        toggle_actions += comments;

        Gtk.ToggleActionEntry tags = { "ViewTags", null, TRANSLATABLE, "<Ctrl><Shift>G",
                                       TRANSLATABLE, on_display_tags, Config.Facade.get_instance ().get_display_photo_tags ()
                                     };
        tags.label = _ ("Ta_gs");
        tags.tooltip = _ ("Display each photo's tags");
        toggle_actions += tags;

        return toggle_actions;
    }

    protected override void register_radio_actions (Gtk.ActionGroup action_group) {
        bool sort_order;
        int sort_by;
        get_config_photos_sort (out sort_order, out sort_by);

        // Sort criteria.
        Gtk.RadioActionEntry[] sort_crit_actions = new Gtk.RadioActionEntry[0];

        Gtk.RadioActionEntry by_title = { "SortByTitle", null, TRANSLATABLE, null, TRANSLATABLE,
                                          SortBy.TITLE
                                        };
        by_title.label = _ ("By _Title");
        by_title.tooltip = _ ("Sort photos by title");
        sort_crit_actions += by_title;

        Gtk.RadioActionEntry by_date = { "SortByExposureDate", null, TRANSLATABLE, null,
                                         TRANSLATABLE, SortBy.EXPOSURE_DATE
                                       };
        by_date.label = _ ("By Exposure _Date");
        by_date.tooltip = _ ("Sort photos by exposure date");
        sort_crit_actions += by_date;

        action_group.add_radio_actions (sort_crit_actions, sort_by, on_sort_changed);

        // Sort order.
        Gtk.RadioActionEntry[] sort_order_actions = new Gtk.RadioActionEntry[0];

        Gtk.RadioActionEntry ascending = { "SortAscending", null,
                                           TRANSLATABLE, null, TRANSLATABLE, SORT_ORDER_ASCENDING
                                         };
        ascending.label = _ ("_Ascending");
        ascending.tooltip = _ ("Sort photos in an ascending order");
        sort_order_actions += ascending;

        Gtk.RadioActionEntry descending = { "SortDescending", null,
                                            TRANSLATABLE, null, TRANSLATABLE, SORT_ORDER_DESCENDING
                                          };
        descending.label = _ ("D_escending");
        descending.tooltip = _ ("Sort photos in a descending order");
        sort_order_actions += descending;

        action_group.add_radio_actions (sort_order_actions,
                                        sort_order ? SORT_ORDER_ASCENDING : SORT_ORDER_DESCENDING, on_sort_changed);

        base.register_radio_actions (action_group);
    }

    protected override void update_actions (int selected_count, int count) {
        set_action_sensitive ("Export", selected_count > 0);
        set_action_sensitive ("IncreaseSize", get_thumb_size () < Thumbnail.MAX_SCALE);
        set_action_sensitive ("DecreaseSize", get_thumb_size () > Thumbnail.MIN_SCALE);
        set_action_sensitive ("RemoveFromLibrary", selected_count > 0);
        set_action_sensitive ("MoveToTrash", selected_count > 0);

        set_action_sensitive ("Rate", selected_count > 0);

        update_development_menu_item_sensitivity ();

        update_flag_action (selected_count);

        base.update_actions (selected_count, count);
    }

    private void on_media_altered (Gee.Map<DataObject, Alteration> altered) {
        foreach (DataObject object in altered.keys) {
            if (altered.get (object).has_detail ("metadata", "flagged")) {
                update_flag_action (get_view ().get_selected_count ());

                break;
            }
        }
    }

    private void update_development_menu_item_sensitivity () {
        if (get_view ().get_selected ().size == 0) {
            set_action_sensitive ("RawDeveloper", false);
            return;
        }

        // Collect some stats about what's selected.
        bool avail_shotwell = false; // True if Shotwell developer is available.
        bool avail_camera = false;   // True if camera developer is available.
        bool is_raw = false;    // True if any RAW photos are selected
        foreach (DataView view in get_view ().get_selected ()) {
            Photo? photo = ((Thumbnail) view).get_media_source () as Photo;
            if (photo != null && photo.get_master_file_format () == PhotoFileFormat.RAW) {
                is_raw = true;

                if (!avail_shotwell && photo.is_raw_developer_available (RawDeveloper.SHOTWELL))
                    avail_shotwell = true;

                if (!avail_camera && (photo.is_raw_developer_available (RawDeveloper.CAMERA) ||
                                      photo.is_raw_developer_available (RawDeveloper.EMBEDDED)))
                    avail_camera = true;

                if (avail_shotwell && avail_camera)
                    break; // optimization: break out of loop when all options available

            }
        }

        // Enable/disable menu.
        set_action_sensitive ("RawDeveloper", is_raw);

        if (is_raw) {
            // Set which developers are available.
            set_action_sensitive ("RawDeveloperShotwell", avail_shotwell);
            set_action_sensitive ("RawDeveloperCamera", avail_camera);
        }
    }

    private void update_flag_action (int selected_count) {
        set_action_sensitive ("Flag", selected_count > 0);

        string flag_label = Resources.FLAG_MENU;

        if (selected_count > 0) {
            bool all_flagged = true;
            foreach (DataSource source in get_view ().get_selected_sources ()) {
                Flaggable? flaggable = source as Flaggable;
                if (flaggable != null && !flaggable.is_flagged ()) {
                    all_flagged = false;

                    break;
                }
            }

            if (all_flagged) {
                flag_label = Resources.UNFLAG_MENU;
            }
        }

        Gtk.Action? flag_action = get_action ("Flag");
        if (flag_action != null) {
            flag_action.label = flag_label;
        }
    }

    public override Core.ViewTracker? get_view_tracker () {
        return tracker;
    }

    public ZoomSliderAssembly create_zoom_slider_assembly () {
        return new ZoomSliderAssembly ();
    }

    protected override bool on_mousewheel_up (Gdk.EventScroll event) {
        if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            increase_zoom_level ();
            return true;
        } else {
            return base.on_mousewheel_up (event);
        }
    }

    protected override bool on_mousewheel_down (Gdk.EventScroll event) {
        if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            decrease_zoom_level ();
            return true;
        } else {
            return base.on_mousewheel_down (event);
        }
    }

    protected void on_play_video () {
        if (get_view ().get_selected_count () != 1)
            return;

        Video? video = get_view ().get_selected_at (0).get_source () as Video;
        if (video == null)
            return;

        try {
            AppInfo.launch_default_for_uri (video.get_file ().get_uri (), null);
        } catch (Error e) {
            AppWindow.error_message (_ ("Shotwell was unable to play the selected video:\n%s").printf (
                                         e.message));
        }
    }

    protected override bool on_app_key_pressed (Gdk.EventKey event) {
        bool handled = true;
        switch (Gdk.keyval_name (event.keyval)) {
        case "equal":
        case "plus":
        case "KP_Add":
            activate_action ("IncreaseSize");
            break;

        case "minus":
        case "underscore":
        case "KP_Subtract":
            activate_action ("DecreaseSize");
            break;

        case "slash":
            activate_action ("Flag");
            break;

        default:
            handled = false;
            break;
        }

        return handled ? true : base.on_app_key_pressed (event);
    }

    public override void switched_to () {
        base.switched_to ();

        // set display options to match Configuration toggles (which can change while switched away)
        get_view ().freeze_notifications ();
        set_display_titles (Config.Facade.get_instance ().get_display_photo_titles ());
        set_display_comments (Config.Facade.get_instance ().get_display_photo_comments ());
        set_display_tags (Config.Facade.get_instance ().get_display_photo_tags ());
        get_view ().thaw_notifications ();

        sync_sort ();
    }

    public override void switching_from () {
        disconnect_slider ();

        base.switching_from ();
    }

    protected void connect_slider (ZoomSliderAssembly slider) {
        connected_slider = slider;
        connected_slider.zoom_changed.connect (on_zoom_changed);
        load_persistent_thumbnail_scale ();
    }

    private void save_persistent_thumbnail_scale () {
        if (connected_slider == null)
            return;

        Config.Facade.get_instance ().set_photo_thumbnail_scale (connected_slider.get_scale ());
    }

    private void load_persistent_thumbnail_scale () {
        if (connected_slider == null)
            return;

        int persistent_scale = Config.Facade.get_instance ().get_photo_thumbnail_scale ();

        connected_slider.set_scale (persistent_scale);
        set_thumb_size (persistent_scale);
    }

    protected void disconnect_slider () {
        if (connected_slider == null)
            return;

        connected_slider.zoom_changed.disconnect (on_zoom_changed);
        connected_slider = null;
    }

    protected virtual void on_zoom_changed () {
        if (connected_slider != null)
            set_thumb_size (connected_slider.get_scale ());

        save_persistent_thumbnail_scale ();
    }

    protected abstract void on_export ();

    protected virtual void on_increase_size () {
        increase_zoom_level ();
    }

    protected virtual void on_decrease_size () {
        decrease_zoom_level ();
    }

    private void set_display_tags (bool display) {
        get_view ().freeze_notifications ();
        get_view ().set_property (Thumbnail.PROP_SHOW_TAGS, display);
        get_view ().thaw_notifications ();

        Gtk.ToggleAction? action = get_action ("ViewTags") as Gtk.ToggleAction;
        if (action != null)
            action.set_active (display);
    }

    private void on_new_event () {
        if (get_view ().get_selected_count () > 0)
            get_command_manager ().execute (new NewEventCommand (get_view ().get_selected ()));
    }

    private void on_flag_unflag () {
        if (get_view ().get_selected_count () == 0)
            return;

        Gee.Collection<MediaSource> sources =
            (Gee.Collection<MediaSource>) get_view ().get_selected_sources_of_type (typeof (MediaSource));

        // If all are flagged, then unflag, otherwise flag
        bool flag = false;
        foreach (MediaSource source in sources) {
            Flaggable? flaggable = source as Flaggable;
            if (flaggable != null && !flaggable.is_flagged ()) {
                flag = true;

                break;
            }
        }

        get_command_manager ().execute (new FlagUnflagCommand (sources, flag));
    }

    private void on_remove_from_library () {
        remove_photos_from_library ((Gee.Collection<LibraryPhoto>) get_view ().get_selected_sources ());
    }

    protected virtual void on_move_to_trash () {
        CheckerboardItem? restore_point = null;

        if (cursor != null) {
            restore_point = get_view ().get_next (cursor) as CheckerboardItem;
        }

        if (get_view ().get_selected_count () > 0) {
            get_command_manager ().execute (new TrashUntrashPhotosCommand (
                                               (Gee.Collection<MediaSource>) get_view ().get_selected_sources (), true));
        }

        if ((restore_point != null) && (get_view ().contains (restore_point))) {
            set_cursor (restore_point);
        }
    }

    protected virtual void on_display_titles (Gtk.Action action) {
        bool display = ((Gtk.ToggleAction) action).get_active ();

        set_display_titles (display);

        Config.Facade.get_instance ().set_display_photo_titles (display);
    }

    protected virtual void on_display_comments (Gtk.Action action) {
        bool display = ((Gtk.ToggleAction) action).get_active ();

        set_display_comments (display);

        Config.Facade.get_instance ().set_display_photo_comments (display);
    }

    protected virtual void on_display_tags (Gtk.Action action) {
        bool display = ((Gtk.ToggleAction) action).get_active ();

        set_display_tags (display);

        Config.Facade.get_instance ().set_display_photo_tags (display);
    }

    protected abstract void get_config_photos_sort (out bool sort_order, out int sort_by);

    protected abstract void set_config_photos_sort (bool sort_order, int sort_by);

    public virtual void on_sort_changed () {
        int sort_by = get_menu_sort_by ();
        bool sort_order = get_menu_sort_order ();

        set_view_comparator (sort_by, sort_order);
        set_config_photos_sort (sort_order, sort_by);
    }

    public void on_raw_developer_shotwell (Gtk.Action action) {
        developer_changed (RawDeveloper.SHOTWELL);
    }

    public void on_raw_developer_camera (Gtk.Action action) {
        developer_changed (RawDeveloper.CAMERA);
    }

    protected virtual void developer_changed (RawDeveloper rd) {
        if (get_view ().get_selected_count () == 0)
            return;

        // Check if any photo has edits

        // Display warning only when edits could be destroyed
        bool need_warn = false;

        // Make a list of all photos that need their developer changed.
        Gee.ArrayList<DataView> to_set = new Gee.ArrayList<DataView> ();
        foreach (DataView view in get_view ().get_selected ()) {
            Photo? p = view.get_source () as Photo;
            if (p != null && (!rd.is_equivalent (p.get_raw_developer ()))) {
                to_set.add (view);

                if (p.has_transformations ()) {
                    need_warn = true;
                }
            }
        }

        if (!need_warn || Dialogs.confirm_warn_developer_changed (to_set.size)) {
            SetRawDeveloperCommand command = new SetRawDeveloperCommand (to_set, rd);
            get_command_manager ().execute (command);

            update_development_menu_item_sensitivity ();
        }
    }

    protected override void set_display_titles (bool display) {
        base.set_display_titles (display);

        Gtk.ToggleAction? action = get_action ("ViewTitle") as Gtk.ToggleAction;
        if (action != null)
            action.set_active (display);
    }

    protected override void set_display_comments (bool display) {
        base.set_display_comments (display);

        Gtk.ToggleAction? action = get_action ("ViewComment") as Gtk.ToggleAction;
        if (action != null)
            action.set_active (display);
    }

    private Gtk.RadioAction sort_by_title_action () {
        Gtk.RadioAction action = (Gtk.RadioAction) get_action ("SortByTitle");
        assert (action != null);
        return action;
    }

    private Gtk.RadioAction sort_ascending_action () {
        Gtk.RadioAction action = (Gtk.RadioAction) get_action ("SortAscending");
        assert (action != null);
        return action;
    }

    protected int get_menu_sort_by () {
        // any member of the group knows the current value
        return sort_by_title_action ().get_current_value ();
    }

    protected void set_menu_sort_by (int val) {
        sort_by_title_action ().set_current_value (val);
    }

    protected bool get_menu_sort_order () {
        // any member of the group knows the current value
        return sort_ascending_action ().get_current_value () == SORT_ORDER_ASCENDING;
    }

    protected void set_menu_sort_order (bool ascending) {
        sort_ascending_action ().set_current_value (
            ascending ? SORT_ORDER_ASCENDING : SORT_ORDER_DESCENDING);
    }

    void set_view_comparator (int sort_by, bool ascending) {
        Comparator comparator;
        ComparatorPredicate predicate;

        switch (sort_by) {
        case SortBy.TITLE:
            if (ascending)
                comparator = Thumbnail.title_ascending_comparator;
            else comparator = Thumbnail.title_descending_comparator;
            predicate = Thumbnail.title_comparator_predicate;
            break;

        case SortBy.EXPOSURE_DATE:
            if (ascending)
                comparator = Thumbnail.exposure_time_ascending_comparator;
            else comparator = Thumbnail.exposure_time_desending_comparator;
            predicate = Thumbnail.exposure_time_comparator_predicate;
            break;

        default:
            debug ("Unknown sort criteria: %s", get_menu_sort_by ().to_string ());
            comparator = Thumbnail.title_descending_comparator;
            predicate = Thumbnail.title_comparator_predicate;
            break;
        }

        get_view ().set_comparator (comparator, predicate);
    }

    protected string get_sortby_path (int sort_by) {
        switch (sort_by) {
        case SortBy.TITLE:
            return "/MediaViewMenu/SortPhotos/SortByTitle";

        case SortBy.EXPOSURE_DATE:
            return "/MediaViewMenu/SortPhotos/SortByExposureDate";

        default:
            debug ("Unknown sort criteria: %d", sort_by);
            return "/MediaViewMenu/SortPhotos/SortByTitle";
        }
    }

    protected void sync_sort () {
        // It used to be that the config and UI could both agree on what
        // sort order and criteria were selected, but the sorting wouldn't
        // match them, due to the current view's comparator not actually
        // being set to match, and since there was a check to see if the
        // config and UI matched that would frequently succeed in this case,
        // the sorting was often wrong until the user went in and changed
        // it.  Because there is no tidy way to query the current view's
        // comparator, we now set it any time we even think the sorting
        // might have changed to force them to always stay in sync.
        //
        // Although this means we pay for a re-sort every time, in practice,
        // this isn't terribly expensive - it _might_ take as long as .5 sec.
        // with a media page containing over 15000 items on a modern CPU.

        bool sort_ascending;
        int sort_by;
        get_config_photos_sort (out sort_ascending, out sort_by);

        set_menu_sort_by (sort_by);
        set_menu_sort_order (sort_ascending);

        set_view_comparator (sort_by, sort_ascending);
    }

    public override void destroy () {
        disconnect_slider ();

        base.destroy ();
    }

    public void increase_zoom_level () {
        if (connected_slider != null) {
            connected_slider.increase_step ();
        } else {
            int new_scale = compute_zoom_scale_increase (get_thumb_size ());
            save_persistent_thumbnail_scale ();
            set_thumb_size (new_scale);
        }
    }

    public void decrease_zoom_level () {
        if (connected_slider != null) {
            connected_slider.decrease_step ();
        } else {
            int new_scale = compute_zoom_scale_decrease (get_thumb_size ());
            save_persistent_thumbnail_scale ();
            set_thumb_size (new_scale);
        }
    }

    public virtual DataView create_thumbnail (DataSource source) {
        return new Thumbnail ((MediaSource) source, get_thumb_size ());
    }

    // this is a view-level operation on this page only; it does not affect the persistent global
    // thumbnail scale
    public void set_thumb_size (int new_scale) {
        if (get_thumb_size () == new_scale || !is_in_view ())
            return;

        new_scale = new_scale.clamp (Thumbnail.MIN_SCALE, Thumbnail.MAX_SCALE);
        get_checkerboard_layout ().set_scale (new_scale);

        // when doing mass operations on LayoutItems, freeze individual notifications
        get_view ().freeze_notifications ();
        get_view ().set_property (Thumbnail.PROP_SIZE, new_scale);
        get_view ().thaw_notifications ();

        set_action_sensitive ("IncreaseSize", new_scale < Thumbnail.MAX_SCALE);
        set_action_sensitive ("DecreaseSize", new_scale > Thumbnail.MIN_SCALE);
    }

    public int get_thumb_size () {
        if (get_checkerboard_layout ().get_scale () <= 0)
            get_checkerboard_layout ().set_scale (Config.Facade.get_instance ().get_photo_thumbnail_scale ());

        return get_checkerboard_layout ().get_scale ();
    }

    public static Gtk.ToolButton create_sidebar_button () {
        var show_sidebar_button = new Gtk.ToolButton (null,null);
        show_sidebar_button.set_icon_name (Resources.SHOW_PANE);
        show_sidebar_button.set_label (Resources.TOGGLE_METAPANE_LABEL);
        show_sidebar_button.set_tooltip_text (Resources.TOGGLE_METAPANE_TOOLTIP);
        show_sidebar_button.is_important = true;
        return show_sidebar_button;
    }
}
