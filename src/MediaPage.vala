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

public abstract class MediaPage : CheckerboardPage {
    private const int SORT_ORDER_ASCENDING = 0;
    private const int SORT_ORDER_DESCENDING = 1;
    public const int MANUAL_STEPPING = 16;

    private enum SortBy {
        MIN = 1,
        TITLE = 1,
        EXPOSURE_DATE = 2,
        MAX = 2
    }

    private SliderAssembly? connected_slider = null;
    private DragAndDropHandler dnd_handler = null;
    private MediaViewTracker tracker;
    private Gtk.Menu page_context_menu;
    protected GLib.Settings ui_settings;

    public MediaPage (string page_name) {
        Object (page_name: page_name);
    }

    construct {
        ui_settings = new GLib.Settings (GSettingsConfigurationEngine.UI_PREFS_SCHEMA_NAME);

        tracker = new MediaViewTracker (get_view ());
        get_view ().items_altered.connect (on_media_altered);

        get_view ().freeze_notifications ();
        get_view ().set_property (CheckerboardItem.PROP_SHOW_TITLES, ui_settings.get_boolean ("display-photo-titles"));
        get_view ().set_property (CheckerboardItem.PROP_SHOW_COMMENTS, ui_settings.get_boolean ("display-photo-comments"));
        get_view ().set_property (Thumbnail.PROP_SHOW_TAGS, ui_settings.get_boolean ("display-photo-tags"));
        get_view ().set_property (Thumbnail.PROP_SIZE, get_thumb_size ());

        get_view ().thaw_notifications ();

        // enable drag-and-drop export of media
        dnd_handler = new DragAndDropHandler (this);
    }

    public override Gtk.Menu? get_page_context_menu () {
        if (page_context_menu == null) {
            page_context_menu = new Gtk.Menu ();

            var sidebar_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("S_idebar"));
            var sidebar_action = get_common_action ("CommonDisplaySidebar");
            sidebar_action.bind_property ("active", sidebar_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);

            var metadata_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("Edit Photo In_fo"));
            var metadata_action = get_common_action ("CommonDisplayMetadataSidebar");
            metadata_action.bind_property ("active", metadata_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);

            var title_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("_Titles"));
            var title_action = get_action ("ViewTitle");
            title_action.bind_property ("active", title_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);

            var comment_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("_Comments"));
            var comment_action = get_action ("ViewComment");
            comment_action.bind_property ("active", comment_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);

            var tags_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("Ta_gs"));
            var tags_action = get_action ("ViewTags");
            tags_action.bind_property ("active", tags_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);

            var sort_photos_menu_item = new Gtk.MenuItem.with_mnemonic (_("Sort _Photos"));

            var by_title_menu_item = new Gtk.RadioMenuItem.with_mnemonic (null, _("By _Title"));
            var by_title_action = get_action ("SortByTitle");
            by_title_action.bind_property ("active", by_title_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
            by_title_menu_item.activate.connect (() => {
                if (by_title_menu_item.active) {
                    by_title_action.activate ();
                }
            });

            var by_exposure_menu_item = new Gtk.RadioMenuItem.with_mnemonic_from_widget (by_title_menu_item, _("By Exposure _Date"));
            var by_exposure_action = get_action ("SortByExposureDate");
            by_exposure_action.bind_property ("active", by_exposure_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
            by_exposure_menu_item.activate.connect (() => {
                if (by_exposure_menu_item.active) {
                    by_exposure_action.activate ();
                }
            });

            var ascending_photos_menu_item = new Gtk.RadioMenuItem.with_mnemonic (null, _("_Ascending"));
            var ascending_photos_action = get_action ("SortAscending");
            ascending_photos_action.bind_property ("active", ascending_photos_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
            ascending_photos_menu_item.activate.connect (() => {
                if (ascending_photos_menu_item.active) {
                    ascending_photos_action.activate ();
                }
            });

            var descending_photos_menu_item = new Gtk.RadioMenuItem.with_mnemonic_from_widget (ascending_photos_menu_item, _("D_escending"));
            var descending_photos_action = get_action ("SortDescending");
            descending_photos_action.bind_property ("active", descending_photos_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
            descending_photos_menu_item.activate.connect (() => {
                if (descending_photos_menu_item.active) {
                    descending_photos_action.activate ();
                }
            });

            var sort_photos_menu = new Gtk.Menu ();
            sort_photos_menu.add (by_title_menu_item);
            sort_photos_menu.add (by_exposure_menu_item);
            sort_photos_menu.add (new Gtk.SeparatorMenuItem ());
            sort_photos_menu.add (ascending_photos_menu_item);
            sort_photos_menu.add (descending_photos_menu_item);
            sort_photos_menu_item.set_submenu (sort_photos_menu);

            var sort_menu_item = new Gtk.MenuItem.with_mnemonic (_("Sort _Events"));

            var ascending_menu_item = new Gtk.RadioMenuItem.with_mnemonic (null, _("_Ascending"));
            var ascending_action = get_common_action ("CommonSortEventsAscending");
            ascending_action.bind_property ("active", ascending_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
            ascending_menu_item.activate.connect (() => {
                if (ascending_menu_item.active) {
                    ascending_action.activate ();
                }
            });

            var descending_menu_item = new Gtk.RadioMenuItem.with_mnemonic_from_widget (ascending_menu_item, _("D_escending"));
            var descending_action = get_common_action ("CommonSortEventsDescending");
            descending_action.bind_property ("active", descending_menu_item, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
            descending_menu_item.activate.connect (() => {
                if (descending_menu_item.active) {
                    descending_action.activate ();
                }
            });

            var sort_menu = new Gtk.Menu ();
            sort_menu.add (ascending_menu_item);
            sort_menu.add (descending_menu_item);
            sort_menu_item.set_submenu (sort_menu);

            var fullscreen_menu_item = new Gtk.MenuItem.with_mnemonic (_("Fulls_creen"));

            var fullscreen_action = AppWindow.get_instance ().lookup_action (AppWindow.ACTION_FULLSCREEN);
            fullscreen_action.bind_property ("enabled", fullscreen_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            fullscreen_menu_item.activate.connect (() => fullscreen_action.activate (null));

            var select_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.SELECT_ALL_MENU);

            var select_action = AppWindow.get_instance ().lookup_action (AppWindow.ACTION_SELECT_ALL);
            select_action.bind_property ("enabled", select_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            select_menu_item.activate.connect (() => select_action.activate (null));

            page_context_menu.add (sidebar_menu_item);
            page_context_menu.add (metadata_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (title_menu_item);
            page_context_menu.add (comment_menu_item);
            page_context_menu.add (tags_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (sort_photos_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (sort_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (fullscreen_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (select_menu_item);
            page_context_menu.show_all ();
        }

        return page_context_menu;
    }

    private static int compute_zoom_scale_increase (int current_scale) {
        int new_scale = current_scale + MANUAL_STEPPING;
        return new_scale.clamp (Thumbnail.MIN_SCALE, Thumbnail.MAX_SCALE);
    }

    private static int compute_zoom_scale_decrease (int current_scale) {
        int new_scale = current_scale - MANUAL_STEPPING;
        return new_scale.clamp (Thumbnail.MIN_SCALE, Thumbnail.MAX_SCALE);
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry export = { "Export", null, Resources.EXPORT_MENU, "<Ctrl><Shift>E",
                                   Resources.EXPORT_MENU, on_export
                                 };
        actions += export;

        Gtk.ActionEntry remove_from_library = { "RemoveFromLibrary", null, Resources.REMOVE_FROM_LIBRARY_MENU,
                                                "<Shift>Delete", Resources.REMOVE_FROM_LIBRARY_MENU, on_remove_from_library
                                              };
        actions += remove_from_library;

        Gtk.ActionEntry move_to_trash = { "MoveToTrash", "user-trash-full", Resources.MOVE_TO_TRASH_MENU, "Delete",
                                          Resources.MOVE_TO_TRASH_MENU, on_move_to_trash
                                        };
        actions += move_to_trash;

        Gtk.ActionEntry new_event = { "NewEvent", null, Resources.NEW_EVENT_MENU, "<Ctrl>N",
                                      Resources.NEW_EVENT_MENU, on_new_event
                                    };
        actions += new_event;

        Gtk.ActionEntry increase_size = { "IncreaseSize", null, _("Zoom _In"),
                                          "<Ctrl>plus",  _("Increase the magnification of the thumbnails"), on_increase_size
                                        };
        actions += increase_size;

        Gtk.ActionEntry decrease_size = { "DecreaseSize", null, _("Zoom _Out"),
                                          "<Ctrl>minus", _("Decrease the magnification of the thumbnails"), on_decrease_size
                                        };
        actions += decrease_size;

        Gtk.ActionEntry flag = { "Flag", null, Resources.FLAG_MENU, "<Ctrl>G", Resources.FLAG_MENU, on_flag_unflag };
        actions += flag;

        Gtk.ActionEntry sort_photos = { "SortPhotos", null, _("Sort _Photos"), null, null, null };
        actions += sort_photos;

        Gtk.ActionEntry filter_photos = { "FilterPhotos", null, Resources.FILTER_PHOTOS_MENU, null, null, null };
        actions += filter_photos;

        Gtk.ActionEntry raw_developer = { "RawDeveloper", null, _("_Developer"), null, null, null };
        actions += raw_developer;

        // RAW developers.

        Gtk.ActionEntry dev_shotwell = { "RawDeveloperShotwell", null, _("Shotwell"), null, _("Shotwell"),
                                         on_raw_developer_shotwell
                                       };
        actions += dev_shotwell;

        Gtk.ActionEntry dev_camera = { "RawDeveloperCamera", null, _("Camera"), null, _("Camera"),
                                       on_raw_developer_camera
                                     };
        actions += dev_camera;

        return actions;
    }

    protected override Gtk.ToggleActionEntry[] init_collect_toggle_action_entries () {
        Gtk.ToggleActionEntry[] toggle_actions = base.init_collect_toggle_action_entries ();

        Gtk.ToggleActionEntry titles = { "ViewTitle", null, _("_Titles"), "<Ctrl><Shift>T",
                                         _("Display the title of each photo"), on_display_titles,
                                         ui_settings.get_boolean ("display-photo-titles")
                                       };
        toggle_actions += titles;

        Gtk.ToggleActionEntry comments = { "ViewComment", null, _("_Comments"), "<Ctrl><Shift>C",
                                           _("Display the comment of each photo"), on_display_comments,
                                           ui_settings.get_boolean ("display-photo-comments")
                                         };
        toggle_actions += comments;

        Gtk.ToggleActionEntry tags = { "ViewTags", null, _("Ta_gs"), "<Ctrl><Shift>G",
                                       _("Display each photo's tags"), on_display_tags,
                                       ui_settings.get_boolean ("display-photo-tags")
                                     };
        toggle_actions += tags;

        return toggle_actions;
    }

    protected override void register_radio_actions (Gtk.ActionGroup action_group) {
        bool sort_order;
        int sort_by;
        get_config_photos_sort (out sort_order, out sort_by);

        // Sort criteria.
        Gtk.RadioActionEntry[] sort_crit_actions = new Gtk.RadioActionEntry[0];

        Gtk.RadioActionEntry by_title = { "SortByTitle", null, _("By _Title"), null, _("Sort photos by title"),
                                          SortBy.TITLE
                                        };
        sort_crit_actions += by_title;

        Gtk.RadioActionEntry by_date = { "SortByExposureDate", null, _("By Exposure _Date"), null,
                                         _("Sort photos by exposure date"), SortBy.EXPOSURE_DATE
                                       };
        sort_crit_actions += by_date;

        action_group.add_radio_actions (sort_crit_actions, sort_by, on_sort_changed);

        // Sort order.
        Gtk.RadioActionEntry[] sort_order_actions = new Gtk.RadioActionEntry[0];

        Gtk.RadioActionEntry ascending = { "SortAscending", null,
                                           _("_Ascending"), null, _("Sort photos in an ascending order"), SORT_ORDER_ASCENDING
                                         };
        sort_order_actions += ascending;

        Gtk.RadioActionEntry descending = { "SortDescending", null,
                                            _("D_escending"), null, _("Sort photos in a descending order"), SORT_ORDER_DESCENDING
                                          };
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
        bool avail_shotwell = false; // True if Photos developer is available.
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
            AppWindow.error_message (_ ("Photos was unable to play the selected video:\n%s").printf (
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
        set_display_titles (ui_settings.get_boolean ("display-photo-titles"));
        set_display_comments (ui_settings.get_boolean ("display-photo-comments"));
        set_display_tags (ui_settings.get_boolean ("display-photo-tags"));
        get_view ().thaw_notifications ();

        sync_sort ();
    }

    public override void switching_from () {
        disconnect_slider ();

        base.switching_from ();
    }

    protected void connect_slider (SliderAssembly slider) {
        connected_slider = slider;
        connected_slider.value_changed.connect (on_zoom_changed);
        load_persistent_thumbnail_scale ();
    }

    private void save_persistent_thumbnail_scale () {
        if (connected_slider == null)
            return;

        ui_settings.set_int ("photo-thumbnail-scale", (int)connected_slider.slider_value);
    }

    private void load_persistent_thumbnail_scale () {
        if (connected_slider == null)
            return;

        int persistent_scale = ui_settings.get_int ("photo-thumbnail-scale");

        connected_slider.slider_value = persistent_scale;
        set_thumb_size (persistent_scale);
    }

    protected void disconnect_slider () {
        if (connected_slider == null)
            return;

        connected_slider.value_changed.disconnect (on_zoom_changed);
        connected_slider = null;
    }

    protected virtual void on_zoom_changed () {
        if (connected_slider != null)
            set_thumb_size ((int)connected_slider.slider_value);

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

        ui_settings.set_boolean ("display-photo-titles", display);
    }

    protected virtual void on_display_comments (Gtk.Action action) {
        bool display = ((Gtk.ToggleAction) action).get_active ();

        set_display_comments (display);

        ui_settings.set_boolean ("display-photo-comments", display);
    }

    protected virtual void on_display_tags (Gtk.Action action) {
        bool display = ((Gtk.ToggleAction) action).get_active ();

        set_display_tags (display);

        ui_settings.set_boolean ("display-photo-tags", display);
    }

    protected virtual void get_config_photos_sort (out bool sort_order, out int sort_by) {
        sort_order = ui_settings.get_boolean ("library-photos-sort-ascending");
        sort_by = ui_settings.get_int ("library-photos-sort-by");
    }

    protected virtual void set_config_photos_sort (bool sort_order, int sort_by) {
        ui_settings.set_boolean ("library-photos-sort-ascending", sort_order);
        ui_settings.set_int ("library-photos-sort-by", sort_by);
    }

    public virtual void on_sort_changed () {
        int sort_by = get_menu_sort_by ();
        bool sort_order = get_menu_sort_order ();

        set_view_comparator (sort_by, sort_order);
        set_config_photos_sort (sort_order, sort_by);
    }

    private void on_raw_developer_shotwell (Gtk.Action action) {
        developer_changed (RawDeveloper.SHOTWELL);
    }

    private void on_raw_developer_camera (Gtk.Action action) {
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

    private void increase_zoom_level () {
        if (connected_slider != null) {
            connected_slider.increase_step ();
        } else {
            int new_scale = compute_zoom_scale_increase (get_thumb_size ());
            save_persistent_thumbnail_scale ();
            set_thumb_size (new_scale);
        }
    }

    private void decrease_zoom_level () {
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
    private void set_thumb_size (int new_scale) {
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

    private int get_thumb_size () {
        if (get_checkerboard_layout ().get_scale () <= 0)
            get_checkerboard_layout ().set_scale (ui_settings.get_int ("photo-thumbnail-scale"));

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
