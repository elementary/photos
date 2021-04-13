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

public class OfflinePage : CheckerboardPage {
    public const string NAME = _ ("Missing Files");

    private class OfflineView : Thumbnail {
        public OfflineView (MediaSource source) {
            base (source);

            assert (source.is_offline ());
        }
    }

    private class OfflineSearchViewFilter : DefaultSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.FLAG |
                   SearchFilterCriteria.MEDIA;
        }
    }

    private OfflineSearchViewFilter search_filter = new OfflineSearchViewFilter ();
    private MediaViewTracker tracker;
    private Gtk.Menu page_context_menu;
    private Gtk.Menu page_sidebar_menu;

    public OfflinePage () {
        base (NAME);

        tracker = new MediaViewTracker (get_view ());

        // monitor offline and initialize view with all items in it
        LibraryPhoto.global.offline_contents_altered.connect (on_offline_contents_altered);
        Video.global.offline_contents_altered.connect (on_offline_contents_altered);

        on_offline_contents_altered (LibraryPhoto.global.get_offline_bin_contents (), null);
        on_offline_contents_altered (Video.global.get_offline_bin_contents (), null);
    }

    ~OfflinePage () {
        LibraryPhoto.global.offline_contents_altered.disconnect (on_offline_contents_altered);
        Video.global.offline_contents_altered.disconnect (on_offline_contents_altered);
    }

    public override Gtk.ActionBar get_toolbar () {
        if (toolbar == null) {
            toolbar = new Gtk.ActionBar ();
            toolbar.get_style_context ().add_class ("bottom-toolbar"); // for elementary theme

            var remove_button = new Gtk.Button.with_mnemonic (Resources.REMOVE_FROM_LIBRARY_MENU);
            remove_button.margin_start = remove_button.margin_end = 3;
            remove_button.tooltip_text = Resources.DELETE_FROM_LIBRARY_TOOLTIP;
            var remove_tool = new Gtk.ToolItem ();
            remove_tool.add (remove_button);
            toolbar.pack_start (remove_tool);
            var remove_action = get_action ("RemoveFromLibrary");
            remove_action.bind_property ("sensitive", remove_button, "sensitive", BindingFlags.SYNC_CREATE);
            remove_button.clicked.connect (() => remove_action.activate ());
        }

        return toolbar;
    }

    public override Gtk.Menu? get_page_sidebar_menu () {
        if (page_sidebar_menu == null) {
            page_sidebar_menu = new Gtk.Menu ();

            var remove_menu_item = new Gtk.CheckMenuItem.with_mnemonic (Resources.REMOVE_FROM_LIBRARY_MENU);
            var remove_action = get_action ("RemoveFromLibrary");
            remove_action.bind_property ("sensitive", remove_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            remove_menu_item.activate.connect (() => remove_action.activate ());

            page_sidebar_menu.add (remove_menu_item);
            page_sidebar_menu.show_all ();
        }

        return page_sidebar_menu;
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

            var select_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.SELECT_ALL_MENU);

            var select_action = AppWindow.get_instance ().lookup_action (AppWindow.ACTION_SELECT_ALL);
            select_action.bind_property ("enabled", select_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            select_menu_item.activate.connect (() => select_action.activate (null));

            page_context_menu.add (sidebar_menu_item);
            page_context_menu.add (metadata_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (sort_menu_item);
            page_context_menu.add (new Gtk.SeparatorMenuItem ());
            page_context_menu.add (select_menu_item);
            page_context_menu.show_all ();
        }

        return page_context_menu;
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry remove = { "RemoveFromLibrary", null, Resources.REMOVE_FROM_LIBRARY_MENU, "Delete",
                                       Resources.DELETE_FROM_LIBRARY_TOOLTIP, on_remove_from_library
                                     };
        actions += remove;

        return actions;
    }

    public override Core.ViewTracker? get_view_tracker () {
        return tracker;
    }

    protected override void update_actions (int selected_count, int count) {
        set_action_sensitive ("RemoveFromLibrary", selected_count > 0);

        base.update_actions (selected_count, count);
    }

    private void on_offline_contents_altered (Gee.Collection<MediaSource>? added,
            Gee.Collection<MediaSource>? removed) {
        if (added != null) {
            foreach (MediaSource source in added)
                get_view ().add (new OfflineView (source));
        }

        if (removed != null) {
            Marker marker = get_view ().start_marking ();
            foreach (MediaSource source in removed)
                marker.mark (get_view ().get_view_for_source (source));
            get_view ().remove_marked (marker);
        }
    }

    private void on_remove_from_library () {
        Gee.Collection<MediaSource> sources =
            (Gee.Collection<MediaSource>) get_view ().get_selected_sources ();
        if (sources.size == 0)
            return;

        if (!remove_offline_dialog (AppWindow.get_instance (), sources.size))
            return;

        AppWindow.get_instance ().set_busy_cursor ();

        ProgressDialog progress = null;
        if (sources.size >= 20)
            progress = new ProgressDialog (AppWindow.get_instance (), _ ("Deleting…"));

        Gee.ArrayList<LibraryPhoto> photos = new Gee.ArrayList<LibraryPhoto> ();
        Gee.ArrayList<Video> videos = new Gee.ArrayList<Video> ();
        MediaSourceCollection.filter_media (sources, photos, videos);

        if (progress != null) {
            LibraryPhoto.global.remove_from_app (photos, false, progress.monitor);
            Video.global.remove_from_app (videos, false, progress.monitor);
        } else {
            LibraryPhoto.global.remove_from_app (photos, false);
            Video.global.remove_from_app (videos, false);
        }

        if (progress != null)
            progress.close ();

        AppWindow.get_instance ().set_normal_cursor ();
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}
