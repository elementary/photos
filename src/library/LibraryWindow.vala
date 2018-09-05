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

public class LibraryWindow : AppWindow {
    public const int SIDEBAR_MIN_WIDTH = 96;
    public const int SIDEBAR_MAX_WIDTH = 320;
    public const int METADATA_SIDEBAR_MIN_WIDTH = 150;
    public static int PAGE_MIN_WIDTH {
        get {
            return Thumbnail.MAX_SCALE + (CheckerboardLayout.COLUMN_GUTTER_PADDING * 2);
        }
    }

    public const int SORT_EVENTS_ORDER_ASCENDING = 0;
    public const int SORT_EVENTS_ORDER_DESCENDING = 1;

    private const string[] SUPPORTED_MOUNT_SCHEMES = {
        "gphoto2:",
        "disk:",
        "file:"
    };


    // If we're not operating on at least this many files, don't display the progress
    // bar at all; otherwise, it'll go by too quickly, giving the appearance of a glitch.
    const int MIN_PROGRESS_BAR_FILES = 20;

    // these values reflect the priority various background operations have when reporting
    // progress to the LibraryWindow progress bar ... higher values give priority to those reports
    private const int STARTUP_SCAN_PROGRESS_PRIORITY =      35;
    private const int REALTIME_UPDATE_PROGRESS_PRIORITY =   40;
    private const int REALTIME_IMPORT_PROGRESS_PRIORITY =   50;
    private const int METADATA_WRITER_PROGRESS_PRIORITY =   30;

    // This lists the order of the toplevel items in the sidebar.  New toplevel items should be
    // added here in the position they should appear in the sidebar.  To re-order, simply move
    // the item in this list to a new position.  These numbers should *not* persist anywhere
    // outside the app.
    private enum SidebarRootPosition {
        LIBRARY,
        CAMERAS,
        SAVED_SEARCH,
        EVENTS,
        TAGS,
    }

    public enum TargetType {
        URI_LIST,
        MEDIA_LIST,
        TAG_PATH
    }

    public const string TAG_PATH_MIME_TYPE = "shotwell/tag-path";
    public const string MEDIA_LIST_MIME_TYPE = "shotwell/media-id-atom";

    public const Gtk.TargetEntry[] DND_TARGET_ENTRIES = {
        { "text/uri-list", Gtk.TargetFlags.OTHER_APP, TargetType.URI_LIST },
        { MEDIA_LIST_MIME_TYPE, Gtk.TargetFlags.SAME_APP, TargetType.MEDIA_LIST },
        { TAG_PATH_MIME_TYPE, Gtk.TargetFlags.SAME_WIDGET, TargetType.TAG_PATH }
    };

    // In fullscreen mode, want to use LibraryPhotoPage, but fullscreen has different requirements,
    // esp. regarding when the widget is realized and when it should first try and throw them image
    // on the page.  This handles this without introducing lots of special cases in
    // LibraryPhotoPage.
    private class FullscreenPhotoPage : LibraryPhotoPage {
        private CollectionPage collection;
        private Photo start;
        private ViewCollection? view;

        public FullscreenPhotoPage (CollectionPage collection, Photo start, ViewCollection? view) {
            this.collection = collection;
            this.start = start;
            this.view = view;
        }

        public override void switched_to () {
            display_for_collection (collection, start, view);

            base.switched_to ();
        }

    }

    private string import_dir = Environment.get_home_dir ();

    private Gtk.Paned sidebar_paned;
    private Gtk.Paned client_paned;
    private Gtk.Paned right_client_paned;
    private MetadataView metadata_sidebar = new MetadataView ();

    private Gtk.ActionGroup common_action_group = new Gtk.ActionGroup ("LibraryWindowGlobalActionGroup");

    private OneShotScheduler properties_scheduler = null;
    private bool notify_library_is_home_dir = true;

    // Sidebar tree and roots (ordered by SidebarRootPosition)
    private Granite.Widgets.Welcome welcome_page;
    private Gtk.Frame right_frame;
    private Sidebar.Tree sidebar_tree;
    private Library.Branch library_branch = new Library.Branch ();
    private Tags.Branch tags_branch = new Tags.Branch ();
    private Events.Branch events_branch = new Events.Branch ();
    private Camera.Branch camera_branch = new Camera.Branch ();
    private Searches.Branch saved_search_branch = new Searches.Branch ();
    private bool page_switching_enabled = true;

    private Gee.HashMap<Page, Sidebar.Entry> page_map = new Gee.HashMap<Page, Sidebar.Entry> ();

    private LibraryPhotoPage photo_page = null;
    // this is to keep track of cameras which initiate the app
    private static Gee.HashSet<string> initial_camera_uris = new Gee.HashSet<string> ();

    // Want to instantiate this in the constructor rather than here because the search bar has its
    // own UIManager which will suck up the accelerators, and we want them to be associated with
    // AppWindows instead.
    private SearchFilterEntry search_entry;

    private Gtk.Box page_header_box;

    private TopDisplay top_display;

    private Gtk.Notebook notebook = new Gtk.Notebook ();
    private Gtk.Box right_vbox;

    private GLib.Settings ui_settings;

    construct {
        ui_settings = new GLib.Settings (GSettingsConfigurationEngine.UI_PREFS_SCHEMA_NAME);

        set_default_size (
            window_settings.get_int ("library-width"),
            window_settings.get_int ("library-height")
        );

        if (window_settings.get_boolean ("library-maximize")) {
            maximize ();
        }
        
        top_display = new TopDisplay ();

        var import_menu_item = new Gtk.MenuItem ();
        import_menu_item.related_action = get_common_action ("CommonFileImport");
        import_menu_item.label = _("_Import From Folder…");

        var preferences_menu_item = new Gtk.MenuItem ();
        preferences_menu_item.related_action = get_common_action ("CommonPreferences");
        preferences_menu_item.label = _("_Preferences");

        var settings_menu = new Gtk.Menu ();
        settings_menu.add (import_menu_item);
        settings_menu.add (new Gtk.SeparatorMenuItem ());
        settings_menu.add (preferences_menu_item);
        settings_menu.show_all ();

        var settings = new Gtk.MenuButton ();
        settings.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        settings.tooltip_text = _("Settings");
        settings.popup = settings_menu;
        settings.show_all ();

        header.pack_end (settings);
        header.set_custom_title (top_display);

        bind_property ("title", top_display, "title");
    }

    public LibraryWindow (ProgressMonitor progress_monitor) {
        ThumbnailCache.scale_factor = get_scale_factor ();

        // prep sidebar and add roots
        sidebar_tree = new Sidebar.Tree (DND_TARGET_ENTRIES, Gdk.DragAction.ASK,
                                         external_drop_handler);

        sidebar_tree.page_created.connect (on_page_created);
        sidebar_tree.destroying_page.connect (on_destroying_page);
        sidebar_tree.entry_selected.connect (on_sidebar_entry_selected);
        sidebar_tree.selected_entry_removed.connect (on_sidebar_selected_entry_removed);

        sidebar_tree.graft (library_branch, SidebarRootPosition.LIBRARY);
        sidebar_tree.graft (tags_branch, SidebarRootPosition.TAGS);
        sidebar_tree.graft (events_branch, SidebarRootPosition.EVENTS);
        sidebar_tree.graft (camera_branch, SidebarRootPosition.CAMERAS);
        sidebar_tree.graft (saved_search_branch, SidebarRootPosition.SAVED_SEARCH);

        properties_scheduler = new OneShotScheduler ("LibraryWindow properties",
                on_update_properties_now);

        // setup search bar and add its accelerators to the window
        search_entry = new SearchFilterEntry ();
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.activate.connect (() => {get_current_page ().grab_focus (); });

        header.pack_end (search_entry);

        // create the main layout & start at the Library page
        create_layout (library_branch.photos_entry.get_page ());

        // settings that should persist between sessions
        load_configuration ();

        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ()) {
            media_sources.items_altered.connect (on_media_altered);
        }

        // set up main window as a drag-and-drop destination (rather than each page; assume
        // a drag and drop is for general library import, which means it goes to library_page)
        Gtk.TargetEntry[] main_window_dnd_targets = {
            DND_TARGET_ENTRIES[TargetType.URI_LIST],
            DND_TARGET_ENTRIES[TargetType.MEDIA_LIST]
            /* the main window accepts URI lists and media lists but not tag paths -- yet; we
               might wish to support dropping tags onto photos at some future point */
        };
        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, main_window_dnd_targets,
                           Gdk.DragAction.COPY | Gdk.DragAction.LINK | Gdk.DragAction.ASK);

        MetadataWriter.get_instance ().progress.connect (on_metadata_writer_progress);

        LibraryMonitor? monitor = LibraryMonitorPool.get_instance ().get_monitor ();
        if (monitor != null)
            on_library_monitor_installed (monitor);

        LibraryMonitorPool.get_instance ().monitor_installed.connect (on_library_monitor_installed);
        LibraryMonitorPool.get_instance ().monitor_destroyed.connect (on_library_monitor_destroyed);

        CameraTable.get_instance ().camera_added.connect (on_camera_added);
    }

    ~LibraryWindow () {
        sidebar_tree.page_created.disconnect (on_page_created);
        sidebar_tree.destroying_page.disconnect (on_destroying_page);
        sidebar_tree.entry_selected.disconnect (on_sidebar_entry_selected);
        sidebar_tree.selected_entry_removed.disconnect (on_sidebar_selected_entry_removed);

        unsubscribe_from_basic_information (get_current_page ());

        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ()) {
            media_sources.items_altered.disconnect (on_media_altered);
        }

        MetadataWriter.get_instance ().progress.disconnect (on_metadata_writer_progress);

        LibraryMonitor? monitor = LibraryMonitorPool.get_instance ().get_monitor ();
        if (monitor != null)
            on_library_monitor_destroyed (monitor);

        LibraryMonitorPool.get_instance ().monitor_installed.disconnect (on_library_monitor_installed);
        LibraryMonitorPool.get_instance ().monitor_destroyed.disconnect (on_library_monitor_destroyed);

        CameraTable.get_instance ().camera_added.disconnect (on_camera_added);
    }

    private void on_library_monitor_installed (LibraryMonitor monitor) {
        debug ("on_library_monitor_installed: %s", monitor.get_root ().get_path ());

        monitor.discovery_started.connect (on_library_monitor_discovery_started);
        monitor.discovery_completed.connect (on_library_monitor_discovery_completed);
        monitor.closed.connect (on_library_monitor_discovery_completed);
        monitor.auto_update_progress.connect (on_library_monitor_auto_update_progress);
        monitor.auto_import_preparing.connect (on_library_monitor_auto_import_preparing);
        monitor.auto_import_progress.connect (on_library_monitor_auto_import_progress);
    }

    private void on_library_monitor_destroyed (LibraryMonitor monitor) {
        debug ("on_library_monitor_destroyed: %s", monitor.get_root ().get_path ());

        monitor.discovery_started.disconnect (on_library_monitor_discovery_started);
        monitor.discovery_completed.disconnect (on_library_monitor_discovery_completed);
        monitor.closed.disconnect (on_library_monitor_discovery_completed);
        monitor.auto_update_progress.disconnect (on_library_monitor_auto_update_progress);
        monitor.auto_import_preparing.disconnect (on_library_monitor_auto_import_preparing);
        monitor.auto_import_progress.disconnect (on_library_monitor_auto_import_progress);
    }

    private Gtk.ActionEntry[] create_common_actions () {
        Gtk.ActionEntry import = { "CommonFileImport", null, null, "<Ctrl>I", null, on_file_import };
        Gtk.ActionEntry sort = { "CommonSortEvents", null,  _("Sort _Events"), null, null, null };
        Gtk.ActionEntry preferences = { "CommonPreferences", null, null, null, null, on_preferences };
        Gtk.ActionEntry jump_to_event = { "CommonJumpToEvent", null, _("View Eve_nt for Photo"), null, null, on_jump_to_event };
        Gtk.ActionEntry find = { "CommonFind", null, null, null, null, on_find };

        // add the common action for the FilterPhotos submenu (the submenu contains items from
        // SearchFilterActions)
        Gtk.ActionEntry filter_photos = { "CommonFilterPhotos", null, Resources.FILTER_PHOTOS_MENU, null, null, null };
        Gtk.ActionEntry new_search = { "CommonNewSearch", null, _("New Smart Album…"), "<Ctrl>S", null, on_new_search };

        Gtk.ActionEntry[] actions = new Gtk.ActionEntry[0];
        actions += import;
        actions += sort;
        actions += preferences;
        actions += jump_to_event;
        actions += find;
        actions += filter_photos;
        actions += new_search;

        return actions;
    }

    private Gtk.ToggleActionEntry[] create_common_toggle_actions () {
        Gtk.ToggleActionEntry[] actions = new Gtk.ToggleActionEntry[0];

        Gtk.ToggleActionEntry searchbar = { "CommonDisplaySearchbar", null, TRANSLATABLE,
                                            "<Ctrl>F", TRANSLATABLE, on_focus_search_entry, true
                                          };
        actions += searchbar;

        Gtk.ToggleActionEntry sidebar = { "CommonDisplaySidebar", null, _("S_idebar"),
                                          "F9", _("Display the sidebar"), on_display_sidebar, is_sidebar_visible ()
                                        };
        actions += sidebar;

        Gtk.ToggleActionEntry meta_sidebar = { "CommonDisplayMetadataSidebar", null, _("Edit Photo In_fo"),
                                               "F10", _("Edit Photo In_fo"), on_display_metadata_sidebar, is_metadata_sidebar_visible ()
                                             };
        actions += meta_sidebar;

        return actions;
    }

    private void add_common_radio_actions (Gtk.ActionGroup group) {
        Gtk.RadioActionEntry[] actions = new Gtk.RadioActionEntry[0];

        Gtk.RadioActionEntry ascending = { "CommonSortEventsAscending",
                                           null, _("_Ascending"), null, _("Sort photos in an ascending order"),
                                           SORT_EVENTS_ORDER_ASCENDING
                                         };
        actions += ascending;

        Gtk.RadioActionEntry descending = { "CommonSortEventsDescending",
                                            null, _("D_escending"), null, _("Sort photos in a descending order"),
                                            SORT_EVENTS_ORDER_DESCENDING
                                          };
        actions += descending;

        group.add_radio_actions (actions, SORT_EVENTS_ORDER_ASCENDING, on_events_sort_changed);
    }

    protected override Gtk.ActionGroup[] create_common_action_groups () {
        Gtk.ActionGroup[] groups = base.create_common_action_groups ();

        common_action_group.add_actions (create_common_actions (), this);
        common_action_group.add_toggle_actions (create_common_toggle_actions (), this);
        add_common_radio_actions (common_action_group);

        Gtk.Action? action = common_action_group.get_action ("CommonDisplaySearchbar");
        if (action != null) {
            action.short_label = Resources.FIND_LABEL;
            action.is_important = true;
        }

        groups += common_action_group;

        return groups;
    }

    protected override void switched_pages (Page? old_page, Page? new_page) {
        base.switched_pages (old_page, new_page);

        // monitor when the ViewFilter is changed in any page
        if (old_page != null) {
            old_page.get_view ().view_filter_installed.disconnect (on_view_filter_installed);
            old_page.get_view ().view_filter_removed.disconnect (on_view_filter_removed);
        }

        if (new_page != null) {
            new_page.get_view ().view_filter_installed.connect (on_view_filter_installed);
            new_page.get_view ().view_filter_removed.connect (on_view_filter_removed);
        }
    }

    private void on_view_filter_installed (ViewFilter filter) {
        filter.refresh.connect (on_view_filter_refreshed);
    }

    private void on_view_filter_removed (ViewFilter filter) {
        filter.refresh.disconnect (on_view_filter_refreshed);
    }

    private void on_view_filter_refreshed () {
        // if view filter is reset to show all items, do nothing (leave searchbar in current
        // state)
        if (!get_current_page ().get_view ().are_items_filtered_out ())
            return;

        // always show the searchbar when items are filtered
        Gtk.ToggleAction? display_searchbar = get_common_action ("CommonDisplaySearchbar")
                                              as Gtk.ToggleAction;
        if (display_searchbar != null)
            display_searchbar.active = true;
    }

    // show_all () may make visible certain items we wish to keep programmatically hidden
    public override void show_all () {
        base.show_all ();

        // Make sure rejected pictures are not being displayed on startup
        CheckerboardPage? current_page = get_current_page () as CheckerboardPage;
        if (current_page != null)
            init_view_filter (current_page);

        // Sidebar
        set_sidebar_visible (is_sidebar_visible ());
        set_metadata_sidebar_visible (is_metadata_sidebar_visible ());
    }

    public static LibraryWindow get_app () {
        assert (instance is LibraryWindow);

        return (LibraryWindow) instance;
    }

    // This may be called before Debug.init (), so no error logging may be made
    public static bool is_mount_uri_supported (string uri) {
        foreach (string scheme in SUPPORTED_MOUNT_SCHEMES) {
            if (uri.has_prefix (scheme))
                return true;
        }

        return false;
    }

    public override string get_app_role () {
        return Resources.APP_LIBRARY_ROLE;
    }

    public void rename_tag_in_sidebar (Tag tag) {
        Tags.SidebarEntry? entry = tags_branch.get_entry_for_tag (tag);
        if (entry != null)
            sidebar_tree.rename_entry_in_place (entry);
        else
            debug ("No tag entry found for rename");
    }

    public void rename_event_in_sidebar (Event event) {
        Events.EventEntry? entry = events_branch.get_entry_for_event (event);
        if (entry != null)
            sidebar_tree.rename_entry_in_place (entry);
        else
            debug ("No event entry found for rename");
    }

    public void rename_search_in_sidebar (SavedSearch search) {
        Searches.SidebarEntry? entry = saved_search_branch.get_entry_for_saved_search (search);
        if (entry != null)
            sidebar_tree.rename_entry_in_place (entry);
        else
            debug ("No search entry found for rename");
    }

    protected override void on_quit () {
        window_settings.set_boolean ("library-maximize", is_maximized);
        window_settings.set_int ("library-width", dimensions.width);
        window_settings.set_int ("library-height", dimensions.height);
        ui_settings.set_int ("sidebar-position", client_paned.position);
        ui_settings.set_int ("metadata-sidebar-position", right_client_paned.position);

        base.on_quit ();
    }

    private Photo? get_start_fullscreen_photo (CollectionPage page) {
        ViewCollection view = page.get_view ();

        // if a selection is present, use the first selected LibraryPhoto, otherwise do
        // nothing; if no selection present, use the first LibraryPhoto
        Gee.List<DataSource>? sources = (view.get_selected_count () > 0)
                                        ? view.get_selected_sources_of_type (typeof (LibraryPhoto))
                                        : view.get_sources_of_type (typeof (LibraryPhoto));

        return (sources != null && sources.size != 0)
               ? (Photo) sources[0] : null;
    }

    private bool get_fullscreen_photo (Page page, out CollectionPage collection, out Photo start,
                                       out ViewCollection? view_collection = null) {
        collection = null;
        start = null;
        view_collection = null;

        // fullscreen behavior depends on the type of page being looked at
        if (page is CollectionPage) {
            collection = (CollectionPage) page;
            Photo? photo = get_start_fullscreen_photo (collection);
            if (photo == null)
                return false;

            start = photo;
            view_collection = null;

            return true;
        }

        if (page is EventsDirectoryPage) {
            ViewCollection view = page.get_view ();
            if (view.get_count () == 0)
                return false;

            Event? event = (Event? ) ((DataView) view.get_at (0)).source;
            if (event == null)
                return false;

            Events.EventEntry? entry = events_branch.get_entry_for_event (event);
            if (entry == null)
                return false;

            collection = (EventPage) entry.get_page ();
            Photo? photo = get_start_fullscreen_photo (collection);
            if (photo == null)
                return false;

            start = photo;
            view_collection = null;

            return true;
        }

        if (page is LibraryPhotoPage) {
            LibraryPhotoPage photo_page = (LibraryPhotoPage) page;

            CollectionPage? controller = photo_page.get_controller_page ();
            if (controller == null)
                return false;

            if (!photo_page.has_photo ())
                return false;

            collection = controller;
            start = photo_page.get_photo ();
            view_collection = photo_page.get_view ();

            return true;
        }

        return false;
    }

    protected override void on_fullscreen () {
        Page? current_page = get_current_page ();
        if (current_page == null)
            return;

        CollectionPage collection;
        Photo start;
        ViewCollection? view = null;
        if (!get_fullscreen_photo (current_page, out collection, out start, out view))
            return;

        FullscreenPhotoPage fs_photo = new FullscreenPhotoPage (collection, start, view);

        go_fullscreen (fs_photo);
    }

    private void on_file_import () {
        Gtk.FileChooserDialog import_dialog = new Gtk.FileChooserDialog (_ ("Import From Folder"), null,
                Gtk.FileChooserAction.SELECT_FOLDER, _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Import"), Gtk.ResponseType.OK);
        import_dialog.set_local_only (false);
        import_dialog.set_select_multiple (true);
        import_dialog.set_current_folder (import_dir);

        int response = import_dialog.run ();

        if (response == Gtk.ResponseType.OK) {
            /* Set invisible the dialog because some wm keep it in front
             * giving the sensation of a froozen program.*/
            import_dialog.set_visible (false);

            // force file linking if directory is inside current library directory
            Gtk.ResponseType copy_files_response =
                AppDirs.is_in_import_dir (File.new_for_uri (import_dialog.get_uri ()))
                ? Gtk.ResponseType.REJECT : copy_files_dialog ();

            if (copy_files_response != Gtk.ResponseType.CANCEL) {
                dispatch_import_jobs (import_dialog.get_uris (), "folders",
                                      copy_files_response == Gtk.ResponseType.ACCEPT);
            }
        }

        import_dir = import_dialog.get_current_folder ();
        import_dialog.destroy ();
    }

    protected override void update_common_action_availability (Page? old_page, Page? new_page) {
        base.update_common_action_availability (old_page, new_page);

        bool is_checkerboard = new_page is CheckerboardPage;

        set_common_action_sensitive ("CommonDisplaySearchbar", is_checkerboard);
        set_common_action_sensitive ("CommonFind", is_checkerboard);
    }

    protected override void update_common_actions (Page page, int selected_count, int count) {
        // see on_fullscreen for the logic here ... both CollectionPage and EventsDirectoryPage
        // are CheckerboardPages (but in on_fullscreen have to be handled differently to locate
        // the view controller)
        CollectionPage collection;
        Photo start;
        bool can_fullscreen = get_fullscreen_photo (page, out collection, out start);
        set_common_action_visible ("CommonJumpToEvent", true);
        set_common_action_sensitive ("CommonJumpToEvent", can_jump_to_event ());

        ((SimpleAction) AppWindow.get_instance ().lookup_action (AppWindow.ACTION_FULLSCREEN)).set_enabled (can_fullscreen);

        base.update_common_actions (page, selected_count, count);
    }

    public void update_common_toggle_actions () {
        Gtk.ToggleAction? sidebar_action = get_common_action ("CommonDisplayMetadataSidebar") as Gtk.ToggleAction;
        if (sidebar_action != null) {
            sidebar_action.toggled.disconnect (on_display_metadata_sidebar);
            sidebar_action.active = is_metadata_sidebar_visible ();
            sidebar_action.toggled.connect (on_display_metadata_sidebar);
        }
    }

    private void on_new_search () {
        (new SavedSearchDialog ()).show ();
    }

    private bool can_jump_to_event () {
        ViewCollection view = get_current_page ().get_view ();
        if (view.get_selected_count () == 1) {
            DataSource selected_source = view.get_selected_source_at (0);
            if (selected_source is Event)
                return true;
            else if (selected_source is MediaSource)
                return ((MediaSource) view.get_selected_source_at (0)).get_event () != null;
            else
                return false;
        } else {
            return false;
        }
    }

    private void on_jump_to_event () {
        ViewCollection view = get_current_page ().get_view ();

        if (view.get_selected_count () != 1)
            return;

        MediaSource? media = view.get_selected_source_at (0) as MediaSource;
        if (media == null)
            return;

        if (media.get_event () != null)
            switch_to_event (media.get_event ());
    }

    private void on_find () {
        Gtk.ToggleAction action = (Gtk.ToggleAction) get_current_page ().get_common_action (
                                      "CommonDisplaySearchbar");
        // Toggle state so repeated ctrl+F hides and unhides the search bar
        action.active = !action.active;
    }

    private void on_media_altered () {
        set_common_action_sensitive ("CommonJumpToEvent", can_jump_to_event ());
    }

    public int get_events_sort () {
        Gtk.RadioAction? action = get_common_action ("CommonSortEventsAscending") as Gtk.RadioAction;

        return (action != null) ? action.current_value : SORT_EVENTS_ORDER_DESCENDING;
    }

    private void on_events_sort_changed (Gtk.Action action, Gtk.Action c) {
        Gtk.RadioAction current = (Gtk.RadioAction) c;

        ui_settings.set_boolean ("events-sort-ascending", current.current_value == SORT_EVENTS_ORDER_ASCENDING);
    }

    private void on_preferences () {
        PreferencesDialog.show ();
    }

    private void on_display_sidebar (Gtk.Action action) {
        set_sidebar_visible (((Gtk.ToggleAction) action).get_active ());

    }

    private void on_focus_search_entry (Gtk.Action action) {
        search_entry.grab_focus ();
    }

    private void on_display_metadata_sidebar (Gtk.Action action) {
        set_metadata_sidebar_visible (((Gtk.ToggleAction) action).get_active ());
        get_current_page ().update_sidebar_action (!is_metadata_sidebar_visible ());
    }

    private void set_sidebar_visible (bool visible) {
        sidebar_paned.set_visible (visible);
        ui_settings.set_boolean ("display-sidebar", visible);
    }

    private bool is_sidebar_visible () {
        return ui_settings.get_boolean ("display-sidebar");
    }

    public void set_metadata_sidebar_visible (bool visible) {
        metadata_sidebar.set_visible (visible);
        ui_settings.set_boolean ("display-metadata-sidebar", visible);
    }

    public bool is_metadata_sidebar_visible () {
        return ui_settings.get_boolean ("display-metadata-sidebar");
    }

    public void enqueue_batch_import (BatchImport batch_import, bool allow_user_cancel) {
        library_branch.import_queue_entry.enqueue_and_schedule (batch_import, allow_user_cancel);
    }

    private void import_reporter (ImportManifest manifest) {
        ImportUI.report_manifest (manifest, true);
    }

    private void dispatch_import_jobs (GLib.SList<string> uris, string job_name, bool copy_to_library) {
        if (AppDirs.get_import_dir ().get_path () == Environment.get_home_dir () && notify_library_is_home_dir) {
            var response = AppWindow.cancel_affirm_question (
                _("Photos is configured to import photos to your home directory.\n" +
                    "We recommend changing this in <span weight=\"bold\">Edit %s Preferences</span>.\n" +
                    "Do you want to continue importing photos?"
                ).printf ("▸"),
                _("_Import"),
                _("Library Location")
            );

            if (response == Gtk.ResponseType.CANCEL)
                return;

            notify_library_is_home_dir = false;
        }

        Gee.ArrayList<FileImportJob> jobs = new Gee.ArrayList<FileImportJob> ();
        foreach (string uri in uris) {
            File file_or_dir = File.new_for_uri (uri);
            if (file_or_dir.get_path () == null) {
                // TODO: Specify which directory/file.
                AppWindow.error_message (_ ("Photos cannot be imported from this directory."));

                continue;
            }

            jobs.add (new FileImportJob (file_or_dir, copy_to_library));
        }

        if (jobs.size > 0) {
            BatchImport batch_import = new BatchImport (jobs, job_name, import_reporter);
            enqueue_batch_import (batch_import, true);
            switch_to_import_queue_page ();
        }
    }

    private Gdk.DragAction get_drag_action () {
        Gdk.ModifierType mask;

        var seat = Gdk.Display.get_default ().get_default_seat ();
        get_window ().get_device_position (seat.get_pointer (), null, null, out mask);

        bool ctrl = (mask & Gdk.ModifierType.CONTROL_MASK) != 0;
        bool alt = (mask & Gdk.ModifierType.MOD1_MASK) != 0;
        bool shift = (mask & Gdk.ModifierType.SHIFT_MASK) != 0;

        if (ctrl && !alt && !shift)
            return Gdk.DragAction.COPY;
        else if (!ctrl && alt && !shift)
            return Gdk.DragAction.ASK;
        else if (ctrl && !alt && shift)
            return Gdk.DragAction.LINK;
        else
            return Gdk.DragAction.DEFAULT;
    }

    public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time) {
        Gdk.Atom target = Gtk.drag_dest_find_target (this, context, Gtk.drag_dest_get_target_list (this));
        // Want to use GDK_NONE (or, properly bound, Gdk.Atom.NONE) but GTK3 doesn't have it bound
        // See: https://bugzilla.gnome.org/show_bug.cgi?id=655094
        if (((int) target) == 0) {
            debug ("drag target is GDK_NONE");
            Gdk.drag_status (context, 0, time);

            return true;
        }

        // internal drag
        if (Gtk.drag_get_source_widget (context) != null) {
            Gdk.drag_status (context, Gdk.DragAction.PRIVATE, time);

            return true;
        }

        // since we cannot set a default action, we must set it when we spy a drag motion
        Gdk.DragAction drag_action = get_drag_action ();

        if (drag_action == Gdk.DragAction.DEFAULT)
            drag_action = Gdk.DragAction.ASK;

        Gdk.drag_status (context, drag_action, time);

        return true;
    }

    public override void drag_data_received (Gdk.DragContext context, int x, int y,
            Gtk.SelectionData selection_data, uint info, uint time) {
        if (selection_data.get_data ().length < 0)
            debug ("failed to retrieve SelectionData");

        // If an external drop, piggyback on the sidebar ExternalDropHandler, otherwise it's an
        // internal drop, which isn't handled by the main window
        if (Gtk.drag_get_source_widget (context) == null)
            external_drop_handler (context, null, selection_data, info, time);
        else
            Gtk.drag_finish (context, false, false, time);
    }

    private void external_drop_handler (Gdk.DragContext context, Sidebar.Entry? entry,
                                        Gtk.SelectionData data, uint info, uint time) {
        string[] uris_array = data.get_uris ();

        GLib.SList<string> uris = new GLib.SList<string> ();
        foreach (string uri in uris_array)
            uris.append (uri);

        Gdk.DragAction selected_action = context.get_selected_action ();
        if (selected_action == Gdk.DragAction.ASK) {
            // Default action is to link, unless one or more URIs are external to the library
            Gtk.ResponseType result = Gtk.ResponseType.REJECT;
            foreach (string uri in uris) {
                if (!AppDirs.is_in_import_dir (File.new_for_uri (uri))) {
                    result = copy_files_dialog ();

                    break;
                }
            }

            switch (result) {
            case Gtk.ResponseType.ACCEPT:
                selected_action = Gdk.DragAction.COPY;
                break;

            case Gtk.ResponseType.REJECT:
                selected_action = Gdk.DragAction.LINK;
                break;

            default:
                // cancelled
                Gtk.drag_finish (context, false, false, time);

                return;
            }
        }

        dispatch_import_jobs (uris, "drag-and-drop", selected_action == Gdk.DragAction.COPY);

        Gtk.drag_finish (context, true, false, time);
    }

    public void switch_to_library_page () {
        switch_to_page (library_branch.photos_entry.get_page ());
    }

    public void switch_to_event_directory () {
        switch_to_page (events_branch.get_master_entry ().get_page ());
    }

    public void switch_to_event (Event event) {
        Events.EventEntry? entry = events_branch.get_entry_for_event (event);
        if (entry != null)
            switch_to_page (entry.get_page ());
    }

    public void switch_to_tag (Tag tag) {
        Tags.SidebarEntry? entry = tags_branch.get_entry_for_tag (tag);
        if (entry != null)
            switch_to_page (entry.get_page ());
    }

    public void switch_to_saved_search (SavedSearch search) {
        Searches.SidebarEntry? entry = saved_search_branch.get_entry_for_saved_search (search);
        if (entry != null)
            switch_to_page (entry.get_page ());
    }

    public void switch_to_photo_page (CollectionPage controller, Photo current) {
        assert (controller.get_view ().get_view_for_source (current) != null);
        if (photo_page == null) {
            photo_page = new LibraryPhotoPage ();
            add_to_notebook (photo_page);

            // need to do this to allow the event loop a chance to map and realize the page
            // before switching to it
            spin_event_loop ();
        }

        photo_page.get_toolbar ();
        photo_page.display_for_collection (controller, current);
        switch_to_page (photo_page);
    }

    public void switch_to_import_queue_page () {
        switch_to_page (library_branch.import_queue_entry.get_page ());
    }

    private void on_camera_added (DiscoveredCamera camera) {
        Camera.SidebarEntry? entry = camera_branch.get_entry_for_camera (camera);
        if (entry == null)
            return;

        ImportPage page = (ImportPage) entry.get_page ();
        File uri_file = File.new_for_uri (camera.uri);

        // find the VFS mount point
        Mount mount = null;
        try {
            mount = uri_file.find_enclosing_mount (null);
        } catch (Error err) {
            // error means not mounted
        }

        // don't unmount mass storage cameras, as they are then unavailable to gPhoto
        if (mount != null && !camera.uri.has_prefix ("file://")) {
            if (page.unmount_camera (mount))
                switch_to_page (page);
            else
                error_message ("Unable to unmount the camera at this time.");
        } else {
            switch_to_page (page);
        }
    }

    // This should only be called by LibraryWindow and PageStub.
    public void add_to_notebook (Page page) {
        // need to show all before handing over to notebook
        page.show_all ();

        int pos = notebook.append_page (page, null);
        assert (pos >= 0);

        // need to show_all () after pages are added and removed
        notebook.show_all ();
    }

    private void remove_from_notebook (Page page) {
        notebook.remove (page);

        // need to show_all () after pages are added and removed
        notebook.show_all ();
    }

    // check for settings that should persist between instances
    private void load_configuration () {
        Gtk.RadioAction? sort_events_action = get_common_action ("CommonSortEventsAscending")
                                              as Gtk.RadioAction;
        assert (sort_events_action != null);

        // Ticket #3321 - Event sorting order wasn't saving on exit.
        // Instead of calling set_active against one of the toggles, call
        // set_current_value against the entire radio group...
        int event_sort_val = ui_settings.get_boolean ("events-sort-ascending") ? SORT_EVENTS_ORDER_ASCENDING :
                             SORT_EVENTS_ORDER_DESCENDING;

        sort_events_action.set_current_value (event_sort_val);
    }

    private void on_library_monitor_discovery_started () {
        top_display.start_pulse_background_progress_bar (_ ("Updating library…"), STARTUP_SCAN_PROGRESS_PRIORITY);
    }

    private void on_library_monitor_discovery_completed () {
        top_display.stop_pulse_background_progress_bar (STARTUP_SCAN_PROGRESS_PRIORITY, true);
    }

    private void on_library_monitor_auto_update_progress (int completed_files, int total_files) {
        if (total_files < MIN_PROGRESS_BAR_FILES)
            top_display.clear_background_progress_bar (REALTIME_UPDATE_PROGRESS_PRIORITY);
        else {
            top_display.update_background_progress_bar (_ ("Updating library…"), REALTIME_UPDATE_PROGRESS_PRIORITY,
                                            completed_files, total_files);
        }
    }

    private void on_library_monitor_auto_import_preparing () {
        top_display.start_pulse_background_progress_bar (_ ("Preparing to auto-import photos…"),
                                             REALTIME_IMPORT_PROGRESS_PRIORITY);
    }

    private void on_library_monitor_auto_import_progress (uint64 completed_bytes, uint64 total_bytes) {
        top_display.update_background_progress_bar (_ ("Auto-importing photos…"),
                                        REALTIME_IMPORT_PROGRESS_PRIORITY, completed_bytes, total_bytes);
    }

    private void on_metadata_writer_progress (uint completed, uint total) {
        if (total < MIN_PROGRESS_BAR_FILES)
            top_display.clear_background_progress_bar (METADATA_WRITER_PROGRESS_PRIORITY);
        else {
            top_display.update_background_progress_bar (_ ("Writing metadata to files…"),
                                            METADATA_WRITER_PROGRESS_PRIORITY, completed, total);
        }
    }

    private void create_layout (Page start_page) {
        // put the sidebar in a scrolling window
        var scrolled_sidebar = new Gtk.ScrolledWindow (null, null);
        scrolled_sidebar.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_sidebar.get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        scrolled_sidebar.add (sidebar_tree);

        sidebar_paned = new Gtk.Paned (Gtk.Orientation.VERTICAL);
        sidebar_paned.pack1 (scrolled_sidebar, true, false);

        // use a Notebook to hold all the pages, which are switched when a sidebar child is selected
        notebook.set_show_tabs (false);
        notebook.set_show_border (false);
        // TODO: Calc according to layout's size, to give sidebar a maximum width
        notebook.width_request = PAGE_MIN_WIDTH;

        metadata_sidebar.width_request = METADATA_SIDEBAR_MIN_WIDTH;

        right_client_paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        right_client_paned.width_request = METADATA_SIDEBAR_MIN_WIDTH;
        right_client_paned.pack1 (notebook, true, false);
        right_client_paned.pack2 (metadata_sidebar, false, false);

        right_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        right_vbox.pack_start (right_client_paned, true, true, 0);

        // layout the selection tree to the left of the collection/toolbar box with an adjustable
        // gutter between them, framed for presentation
        right_frame = new Gtk.Frame (null);
        right_frame.set_shadow_type (Gtk.ShadowType.NONE);
        right_frame.add (right_vbox);

        sidebar_tree.set_size_request (SIDEBAR_MIN_WIDTH, -1);

        client_paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        client_paned.pack1 (sidebar_paned, false, false);
        client_paned.pack2 (right_frame, true, false);
        client_paned.set_position (ui_settings.get_int ("sidebar-position"));

        int metadata_sidebar_pos = ui_settings.get_int ("metadata-sidebar-position");
        if (metadata_sidebar_pos > 0)
            right_client_paned.set_position (metadata_sidebar_pos);

        add (client_paned);

        switch_to_page (start_page);
        start_page.grab_focus ();
    }

    public override void set_current_page (Page page) {
        // switch_to_page () will call base.set_current_page (), maintain the semantics of this call
        switch_to_page (page);
    }

    public void set_page_switching_enabled (bool should_enable) {
        page_switching_enabled = should_enable;
    }

    public void switch_to_page (Page page) {
        if (!page_switching_enabled)
            return;

        if (page == get_current_page ())
            return;

        metadata_sidebar.save_changes ();
        Page current_page = get_current_page ();
        if (current_page != null) {
            Gtk.Toolbar toolbar = current_page.get_toolbar ();
            if (toolbar != null) {
                toolbar.destroy ();
            }
            if (page_header_box != null)
                header.remove (page_header_box);

            current_page.switching_from ();

            // see note below about why the sidebar is uneditable while the LibraryPhotoPage is
            // visible
            if (current_page is LibraryPhotoPage)
                sidebar_tree.enable_editing ();

            // old page unsubscribes to these signals (new page subscribes below)
            unsubscribe_from_basic_information (current_page);
        }

        notebook.set_current_page (notebook.page_num (page));

        // do this prior to changing selection, as the change will fire a cursor-changed event,
        // which will then call this function again
        base.set_current_page (page);
        page_header_box = page.get_header_buttons ();
        header.pack_start (page_header_box);
        header.show_all ();
        // if the visible page is the LibraryPhotoPage, we need to prevent single-click inline
        // renaming in the sidebar because a single click while in the LibraryPhotoPage indicates
        // the user wants to return to the controlling page ... that is, in this special case, the
        // sidebar cursor is set not to the 'current' page, but the page the user came from
        if (page is LibraryPhotoPage)
            sidebar_tree.disable_editing ();

        // Update search filter to new page.
        search_entry.sensitive = is_search_sensitive ();

        // Not all pages have sidebar entries
        Sidebar.Entry? entry = page_map.get (page);
        if (entry != null) {
            // if the corresponding sidebar entry is an expandable entry and wants to be
            // expanded when it's selected, then expand it
            Sidebar.ExpandableEntry expandable_entry = entry as Sidebar.ExpandableEntry;
            if (expandable_entry != null && expandable_entry.expand_on_select ())
                sidebar_tree.expand_to_entry (entry);

            sidebar_tree.place_cursor (entry, true);
        }

        on_update_properties ();

        if (page is CheckerboardPage)
            init_view_filter ((CheckerboardPage)page);

        page.show_all ();

        // subscribe to these signals for each event page so basic properties display will update
        subscribe_for_basic_information (get_current_page ());

        page.switched_to ();

        var toolbar = page.get_toolbar ();
        if (toolbar != null) {
            right_vbox.add (toolbar);
            toolbar.show_all ();
        }

        page.ready ();
    }

    private void init_view_filter (CheckerboardPage page) {
        search_entry.set_view_filter (page.get_search_view_filter ());
        page.get_view ().install_view_filter (page.get_search_view_filter ());
    }

    private bool is_search_sensitive () {
        return get_current_page () is CheckerboardPage;
    }

    public void toggle_welcome_page (bool show, string title = "", string subtitle = "", bool show_import = false) {
        if (show == true) {
            welcome_page = null;
            welcome_page = new Granite.Widgets.Welcome (title, subtitle);
            if (show_import) {
                welcome_page.append ("document-import", _ ("Import Photos"), _ ("Copy photos from a folder or external device."));
                welcome_page.append ("folder-pictures", _ ("Change Library Folder"), _ ("Choose where to keep your photos."));
                welcome_page.activated.connect ((index) => {
                    switch (index) {
                    case 0:
                        on_file_import ();
                        break;
                    case 1:
                        on_preferences ();
                        break;
                    }
                });
            }
        }

        if (right_frame != null) {
            if (right_frame.get_child () != null)
                right_frame.remove (right_frame.get_child ());

            if (show) {
                right_frame.add (welcome_page);
            } else {
                right_frame.add (right_vbox);
            }

            right_frame.show_all ();
        }

        set_metadata_sidebar_visible (is_metadata_sidebar_visible ());

        if (get_current_page () != null && !search_entry.has_focus) {
            get_current_page ().grab_focus ();
        }
    }

    private void on_page_created (Sidebar.PageRepresentative entry, Page page) {
        assert (!page_map.has_key (page));
        page_map.set (page, entry);

        add_to_notebook (page);
    }

    private void on_destroying_page (Sidebar.PageRepresentative entry, Page page) {
        // if page is the current page, switch to fallback before destroying
        if (page == get_current_page ())
            switch_to_page (library_branch.photos_entry.get_page ());

        remove_from_notebook (page);

        bool removed = page_map.unset (page);
        assert (removed);
    }

    private void on_sidebar_entry_selected (Sidebar.SelectableEntry selectable) {
        Sidebar.PageRepresentative? page_rep = selectable as Sidebar.PageRepresentative;
        if (page_rep != null)
            switch_to_page (page_rep.get_page ());
    }

    private void on_sidebar_selected_entry_removed (Sidebar.SelectableEntry selectable) {
        // if the currently selected item is removed, want to jump to fallback page (which
        // depends on the item that was selected)

        Library.LastImportSidebarEntry last_import_entry = library_branch.last_imported_entry;

        // Importing... -> Last Import (if available)
        if (selectable is Library.ImportQueueSidebarEntry && last_import_entry.visible) {
            switch_to_page (last_import_entry.get_page ());

            return;
        }

        // Event page -> Events (master event directory)
        if (selectable is Events.EventEntry && events_branch.get_show_branch ()) {
            switch_to_page (events_branch.get_master_entry ().get_page ());

            return;
        }

        // Any event directory -> Events (master event directory)
        if (selectable is Events.DirectoryEntry && events_branch.get_show_branch ()) {
            switch_to_page (events_branch.get_master_entry ().get_page ());

            return;
        }

        // basic all-around default: jump to the Library page
        switch_to_page (library_branch.photos_entry.get_page ());
    }

    private void subscribe_for_basic_information (Page page) {
        ViewCollection view = page.get_view ();

        view.items_state_changed.connect (on_update_properties);
        view.items_altered.connect (on_update_properties);
        view.contents_altered.connect (on_update_properties);
        view.items_visibility_changed.connect (on_update_properties);
    }

    private void unsubscribe_from_basic_information (Page page) {
        ViewCollection view = page.get_view ();

        view.items_state_changed.disconnect (on_update_properties);
        view.items_altered.disconnect (on_update_properties);
        view.contents_altered.disconnect (on_update_properties);
        view.items_visibility_changed.disconnect (on_update_properties);
    }

    private void on_update_properties () {
        properties_scheduler.at_idle ();
    }

    private void on_update_properties_now () {
        metadata_sidebar.update_properties (get_current_page ());
        update_window_title ();
    }

    public void mounted_camera_shell_notification (string uri, bool at_startup) {
        debug ("mount point reported: %s", uri);

        // ignore unsupport mount URIs
        if (!is_mount_uri_supported (uri)) {
            debug ("Unsupported mount scheme: %s", uri);

            return;
        }

        File uri_file = File.new_for_uri (uri);

        // find the VFS mount point
        Mount mount = null;
        try {
            mount = uri_file.find_enclosing_mount (null);
        } catch (Error err) {
            debug ("%s", err.message);

            return;
        }

        // convert file: URIs into gphoto disk: URIs
        string alt_uri = null;
        if (uri.has_prefix ("file://"))
            alt_uri = CameraTable.get_port_uri (uri.replace ("file://", "disk:"));

        // we only add uris when the notification is called on startup
        if (at_startup) {
            if (!is_string_empty (uri))
                initial_camera_uris.add (uri);

            if (!is_string_empty (alt_uri))
                initial_camera_uris.add (alt_uri);
        }
    }

    public override bool key_press_event (Gdk.EventKey event) {
        if (sidebar_tree.has_focus && sidebar_tree.is_keypress_interpreted (event)
                && sidebar_tree.key_press_event (event)) {
            return true;
        }

        if (base.key_press_event (event))
            return true;

        return false;
    }

    protected void update_window_title () {
        // show the name of the current page, as each page instance is properly
        // named: it displays the name of their collection (library, event, or
        // tag) when the page holds a collection of items (CheckerboardPages and
        // CollectionPages), and the name of the current photo when the page
        // just holds a single photo (SinglePhotoPage)
        Page? current_page = get_current_page ();
        if (current_page != null) {
                title = current_page.page_name;
        } else {
            // having no page is unlikely, but set the good old default title
            // just in case
            title = _(Resources.APP_TITLE);
        }
    }
}
