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

public abstract class EventsDirectoryPage : CheckerboardPage {
    public class EventDirectoryManager : ViewManager {
        public override DataView create_view (DataSource source) {
            return new EventDirectoryItem ((Event) source);
        }
    }

    private class EventsDirectorySearchViewFilter : SearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT;
        }

        public override bool predicate (DataView view) {
            assert (view.source is Event);
            if (is_string_empty (get_search_filter ()))
                return true;

            Event source = (Event) view.source;
            unowned string? event_keywords = source.get_indexable_keywords ();
            if (is_string_empty (event_keywords))
                return false;

            // Return false if the word isn't found, true otherwise.
            foreach (unowned string word in get_search_filter_words ()) {
                if (!event_keywords.contains (word))
                    return false;
            }

            return true;
        }
    }

    private const int MIN_PHOTOS_FOR_PROGRESS_WINDOW = 50;

    protected ViewManager view_manager;

    private EventsDirectorySearchViewFilter search_filter = new EventsDirectorySearchViewFilter ();
    private Gtk.Menu page_context_menu;
    private Gtk.Menu item_context_menu;
    private GLib.Settings ui_settings;

    construct {
        ui_settings = new GLib.Settings (GSettingsConfigurationEngine.UI_PREFS_SCHEMA_NAME);

        var merge_button = new Gtk.ToolButton (null, null);
        merge_button.icon_widget = new Gtk.Image.from_icon_name (Resources.MERGE, Gtk.IconSize.LARGE_TOOLBAR);
        merge_button.related_action = get_action ("Merge");
        merge_button.tooltip_text = _("Merge events");

        var separator = new Gtk.SeparatorToolItem ();
        separator.set_expand (true);

        show_sidebar_button = MediaPage.create_sidebar_button ();
        show_sidebar_button.clicked.connect (on_show_sidebar);

        var toolbar = get_toolbar ();
        toolbar.add (merge_button);
        toolbar.add (separator);
        toolbar.add (show_sidebar_button);
    }

    protected EventsDirectoryPage (string page_name, ViewManager view_manager,
                                   Gee.Collection<Event>? initial_events) {
        base (page_name);

        // set comparator before monitoring source collection, to prevent a re-sort
        get_view ().set_comparator (get_event_comparator (ui_settings.get_boolean ("events-sort-ascending")),
                                    event_comparator_predicate);
        get_view ().monitor_source_collection (Event.global, view_manager, null, initial_events);

        get_view ().set_property (Event.PROP_SHOW_COMMENTS,
                                  ui_settings.get_boolean ("display-event-comments"));

        this.view_manager = view_manager;

        var app = AppWindow.get_instance () as LibraryWindow;
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
    }

    ~EventsDirectoryPage () {
        Gtk.RadioAction? action = get_action ("CommonSortEventsAscending") as Gtk.RadioAction;
        assert (action != null);
        action.changed.disconnect (on_sort_changed);
    }

    public override Gtk.Menu? get_item_context_menu () {
        if (item_context_menu == null) {
            item_context_menu = new Gtk.Menu ();

            var merge_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.MERGE_MENU);
            var merge_action = get_action ("Merge");
            merge_action.bind_property ("sensitive", merge_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            merge_menu_item.activate.connect (() => merge_action.activate ());

            var rename_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.RENAME_EVENT_MENU);
            var rename_action = get_action ("Rename");
            rename_action.bind_property ("sensitive", rename_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            rename_menu_item.activate.connect (() => rename_action.activate ());

            item_context_menu.add (merge_menu_item);
            item_context_menu.add (rename_menu_item);
            item_context_menu.show_all ();
        }

        return item_context_menu;
    }

    public override Gtk.Menu? get_page_context_menu () {
        if (page_context_menu == null) {
            page_context_menu = new Gtk.Menu ();

            var sidebar_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("S_idebar"));
            var sidebar_action = get_common_action ("CommonDisplaySidebar");
            sidebar_action.bind_property ("active", sidebar_menu_item, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

            var metadata_menu_item = new Gtk.CheckMenuItem.with_mnemonic (_("Edit Photo In_fo"));
            var metadata_action = get_common_action ("CommonDisplayMetadataSidebar");
            metadata_action.bind_property ("active", metadata_menu_item, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

            var sort_menu_item = new Gtk.MenuItem.with_mnemonic (_("Sort _Events"));

            var ascending_menu_item = new Gtk.RadioMenuItem.with_mnemonic (null, _("_Ascending"));
            var ascending_action = get_common_action ("CommonSortEventsAscending");
            ascending_action.bind_property ("active", ascending_menu_item, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
            ascending_menu_item.activate.connect (() => {
                if (ascending_menu_item.active) {
                    ascending_action.activate ();
                }
            });

            var descending_menu_item = new Gtk.RadioMenuItem.with_mnemonic_from_widget (ascending_menu_item, _("D_escending"));
            var descending_action = get_common_action ("CommonSortEventsDescending");
            descending_action.bind_property ("active", descending_menu_item, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
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
            page_context_menu.add (sort_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (fullscreen_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (select_menu_item);
            page_context_menu.show_all ();
        }

        return page_context_menu;
    }

    protected static bool event_comparator_predicate (DataObject object, Alteration alteration) {
        return alteration.has_detail ("metadata", "time");
    }

    private static int64 event_ascending_comparator (void *a, void *b) {
        int64 start_a = ((EventDirectoryItem *) a)->event.get_start_time ();
        int64 start_b = ((EventDirectoryItem *) b)->event.get_start_time ();

        return start_a - start_b;
    }

    private static int64 event_descending_comparator (void *a, void *b) {
        return event_ascending_comparator (b, a);
    }

    private static Comparator get_event_comparator (bool ascending) {
        if (ascending)
            return event_ascending_comparator;
        else
            return event_descending_comparator;
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry rename = { "Rename", null, Resources.RENAME_EVENT_MENU, "F2", Resources.RENAME_EVENT_MENU, on_rename };
        actions += rename;

        Gtk.ActionEntry merge = { "Merge", Resources.MERGE, Resources.MERGE_MENU, null, Resources.MERGE_TOOLTIP,
                                  on_merge
                                };
        actions += merge;

        return actions;
    }

    protected override Gtk.ToggleActionEntry[] init_collect_toggle_action_entries () {
        Gtk.ToggleActionEntry[] toggle_actions = base.init_collect_toggle_action_entries ();

        Gtk.ToggleActionEntry comments = { "ViewComment", null, _("_Comments"), "<Ctrl><Shift>C",
                                           _("Display the comment of each event"), on_display_comments,
                                           ui_settings.get_boolean ("display-event-comments")
                                         };
        toggle_actions += comments;

        return toggle_actions;
    }

    protected override void init_actions (int selected_count, int count) {
        base.init_actions (selected_count, count);

        Gtk.RadioAction? action = get_action ("CommonSortEventsAscending") as Gtk.RadioAction;
        assert (action != null);
        action.changed.connect (on_sort_changed);
    }

    protected override void update_actions (int selected_count, int count) {
        set_action_sensitive ("Merge", selected_count > 1);
        set_action_sensitive ("Rename", selected_count == 1);

        base.update_actions (selected_count, count);
    }

    protected override string get_view_empty_message () {
        return _ ("No events");
    }

    protected override string get_filter_no_match_message () {
        return _ ("No events found");
    }

    public override void on_item_activated (CheckerboardItem item) {
        EventDirectoryItem event = (EventDirectoryItem) item;
        LibraryWindow.get_app ().switch_to_event (event.event);
    }

    private void on_sort_changed (Gtk.Action action, Gtk.Action c) {
        Gtk.RadioAction current = (Gtk.RadioAction) c;

        get_view ().set_comparator (
            get_event_comparator (current.current_value == LibraryWindow.SORT_EVENTS_ORDER_ASCENDING),
            event_comparator_predicate);
    }

    private void on_show_sidebar () {
        var app = AppWindow.get_instance () as LibraryWindow;
        app.set_metadata_sidebar_visible (!app.is_metadata_sidebar_visible ());
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
    }

    private void on_rename () {
        // only rename one at a time
        if (get_view ().get_selected_count () != 1)
            return;

        EventDirectoryItem item = (EventDirectoryItem) get_view ().get_selected_at (0);

        EventRenameDialog rename_dialog = new EventRenameDialog (item.event.get_raw_name ());
        string? new_name = rename_dialog.execute ();
        if (new_name == null)
            return;

        RenameEventCommand command = new RenameEventCommand (item.event, new_name);
        get_command_manager ().execute (command);
    }

    private void on_merge () {
        if (get_view ().get_selected_count () <= 1)
            return;

        MergeEventsCommand command = new MergeEventsCommand (get_view ().get_selected ());
        get_command_manager ().execute (command);
    }

    private void on_display_comments (Gtk.Action action) {
        bool display = ((Gtk.ToggleAction) action).get_active ();

        set_display_comments (display);

        ui_settings.set_boolean ("display-event-comments", display);
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}

public class MasterEventsDirectoryPage : EventsDirectoryPage {
    public const string NAME = _ ("Events");

    public MasterEventsDirectoryPage () {
        base (NAME, new EventDirectoryManager (), (Gee.Collection<Event>) Event.global.get_all ());
    }
}

public class SubEventsDirectoryPage : EventsDirectoryPage {
    public enum DirectoryType {
        YEAR,
        MONTH,
        UNDATED;
    }

    public const string UNDATED_PAGE_NAME = _ ("Undated");
    public const string YEAR_FORMAT = _ ("%Y");
    public const string MONTH_FORMAT = _ ("%OB");

    private class SubEventDirectoryManager : EventsDirectoryPage.EventDirectoryManager {
        private int month = 0;
        private int year = 0;
        DirectoryType type;

        public SubEventDirectoryManager (DirectoryType type, DateTime time) {
            base ();

            if (type == DirectoryType.MONTH)
                month = time.get_month ();
            this.type = type;
            year = time.get_year ();
        }

        public override bool include_in_view (DataSource source) {
            if (!base.include_in_view (source))
                return false;

            EventSource event = (EventSource) source;
            DateTime event_time = new DateTime.from_unix_local (event.get_start_time ());
            if (event_time.get_year () == year) {
                if (type == DirectoryType.MONTH) {
                    return (event_time.get_month () == month);
                }

                return true;
            }
            return false;
        }

        public int get_month () {
            return month;
        }

        public int get_year () {
            return year;
        }

        public DirectoryType get_event_directory_type () {
            return type;
        }
    }

    public SubEventsDirectoryPage (DirectoryType type, DateTime time) {
        string page_name;
        if (type == SubEventsDirectoryPage.DirectoryType.UNDATED) {
            page_name = UNDATED_PAGE_NAME;
        } else {
            page_name = time.format ((type == DirectoryType.YEAR) ? YEAR_FORMAT : MONTH_FORMAT);
        }

        base (page_name, new SubEventDirectoryManager (type, time), null);
    }

    public int get_month () {
        return ((SubEventDirectoryManager) view_manager).get_month ();
    }

    public int get_year () {
        return ((SubEventDirectoryManager) view_manager).get_year ();
    }

    public DirectoryType get_event_directory_type () {
        return ((SubEventDirectoryManager) view_manager).get_event_directory_type ();
    }
}
