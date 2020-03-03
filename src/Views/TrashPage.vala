/*
* Copyright (c) 2010-2013 Yorba Foundation
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

public class TrashPage : CheckerboardPage {
    public const string NAME = _ ("Trash");

    private class TrashView : Thumbnail {
        public TrashView (MediaSource source) {
            base (source);

            assert (source.is_trashed ());
        }
    }

    private class TrashSearchViewFilter : DefaultSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.FLAG |
                   SearchFilterCriteria.MEDIA;
        }
    }

    private TrashSearchViewFilter search_filter = new TrashSearchViewFilter ();
    private MediaViewTracker tracker;
    private Gtk.Menu page_sidebar_menu;
    private Gtk.Menu item_context_menu;
    private Gtk.Menu page_context_menu;

    public TrashPage () {
        base (NAME);

        tracker = new MediaViewTracker (get_view ());

        // monitor trashcans and initialize view with all items in them
        LibraryPhoto.global.trashcan_contents_altered.connect (on_trashcan_contents_altered);
        Video.global.trashcan_contents_altered.connect (on_trashcan_contents_altered);
        on_trashcan_contents_altered (LibraryPhoto.global.get_trashcan_contents (), null);
        on_trashcan_contents_altered (Video.global.get_trashcan_contents (), null);
    }

    public override Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            var app = AppWindow.get_instance () as LibraryWindow;

            var separator = new Gtk.SeparatorToolItem ();
            separator.set_expand (true);
            separator.set_draw (false);

            var restore_button = new Gtk.Button.with_mnemonic (Resources.RESTORE_PHOTOS_MENU);
            restore_button.margin_start = restore_button.margin_end = 3;
            restore_button.clicked.connect (on_restore);
            restore_button.tooltip_text = Resources.RESTORE_PHOTOS_TOOLTIP;

            var restore_tool = new Gtk.ToolItem ();
            restore_tool.add (restore_button);

            var restore_action = get_action ("Restore");
            restore_action.bind_property ("sensitive", restore_button, "sensitive", BindingFlags.SYNC_CREATE);

            var delete_button = new Gtk.Button.with_mnemonic (Resources.DELETE_PHOTOS_MENU);
            delete_button.margin_start = delete_button.margin_end = 3;
            delete_button.tooltip_text = Resources.DELETE_FROM_TRASH_TOOLTIP;
            delete_button.clicked.connect (on_delete);

            var delete_tool = new Gtk.ToolItem ();
            delete_tool.add (delete_button);

            var delete_action = get_action ("Delete");
            delete_action.bind_property ("sensitive", delete_button, "sensitive", BindingFlags.SYNC_CREATE);

            var empty_trash_button = new Gtk.Button.with_mnemonic (_("_Empty Trash"));
            empty_trash_button.margin_start = empty_trash_button.margin_end = 3;
            empty_trash_button.tooltip_text = _("Delete all photos in the trash");
            empty_trash_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            empty_trash_button.clicked.connect (on_empty_trash);

            var empty_trash_tool = new Gtk.ToolItem ();
            empty_trash_tool.add (empty_trash_button);

            var empty_trash_action = get_action ("EmptyTrash");
            empty_trash_action.bind_property ("sensitive", empty_trash_button, "sensitive", BindingFlags.SYNC_CREATE);

            show_sidebar_button = MediaPage.create_sidebar_button ();
            show_sidebar_button.clicked.connect (on_show_sidebar);

            base.get_toolbar ();
            toolbar.add (separator);
            toolbar.add (restore_tool);
            toolbar.add (delete_tool);
            toolbar.add (empty_trash_tool);
            toolbar.add (new Gtk.SeparatorToolItem ());
            toolbar.add (show_sidebar_button);

            update_sidebar_action (!app.is_metadata_sidebar_visible ());
        }
        return toolbar;
    }

    public override Gtk.Menu? get_item_context_menu () {
        if (item_context_menu == null) {
            item_context_menu = new Gtk.Menu ();

            var delete_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.DELETE_PHOTOS_MENU);
            var delete_action = get_action ("Delete");
            delete_action.bind_property ("sensitive", delete_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            delete_menu_item.activate.connect (() => delete_action.activate ());

            var restore_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.RESTORE_PHOTOS_MENU);
            var restore_action = get_action ("Restore");
            restore_action.bind_property ("sensitive", restore_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            restore_menu_item.activate.connect (() => restore_action.activate ());

            var jump_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.JUMP_TO_FILE_MENU);

            var jump_menu_action = AppWindow.get_instance ().lookup_action (AppWindow.ACTION_JUMP_TO_FILE);
            jump_menu_action.bind_property ("enabled", jump_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            jump_menu_item.activate.connect (() => jump_menu_action.activate (null));

            var empty_menu_item = new Gtk.MenuItem.with_mnemonic (_("_Empty Trash"));
            var empty_trash_action = get_action ("EmptyTrash");
            empty_trash_action.bind_property ("sensitive", empty_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            empty_menu_item.activate.connect (() => empty_trash_action.activate ());

            item_context_menu.add (delete_menu_item);
            item_context_menu.add (restore_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (jump_menu_item);
            item_context_menu.add (new Gtk.SeparatorMenuItem ());
            item_context_menu.add (empty_menu_item);
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
            var metadata_action = (Gtk.ToggleAction)get_common_action ("CommonDisplayMetadataSidebar");
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

    public override Gtk.Menu? get_page_sidebar_menu () {
        if (page_sidebar_menu == null) {
            page_sidebar_menu = new Gtk.Menu ();
            var empty_menu_item = new Gtk.MenuItem.with_mnemonic (_("_Empty Trash"));
            var empty_trash_action = get_action ("EmptyTrash");
            empty_trash_action.bind_property ("sensitive", empty_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            empty_menu_item.activate.connect (() => empty_trash_action.activate ());
            page_sidebar_menu.add (empty_menu_item);
            page_sidebar_menu.show_all ();
        }

        return page_sidebar_menu;
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry delete_action = { "Delete", null, Resources.DELETE_PHOTOS_MENU, "Delete",
                                          Resources.DELETE_FROM_TRASH_TOOLTIP, on_delete
                                        };
        actions += delete_action;

        Gtk.ActionEntry restore = { "Restore", null, Resources.RESTORE_PHOTOS_MENU, "Restore", Resources.RESTORE_PHOTOS_TOOLTIP,
                                    on_restore
                                  };
        actions += restore;

        Gtk.ActionEntry empty = { "EmptyTrash", null, _("_Empty Trash"), null, _("Delete all photos in the trash"),
                                  on_empty_trash
                                };
        actions += empty;

        return actions;
    }

    public override Core.ViewTracker? get_view_tracker () {
        return tracker;
    }

    protected override void update_actions (int selected_count, int count) {
        bool has_selected = selected_count > 0;

        set_action_sensitive ("Delete", has_selected);
        set_action_sensitive ("Restore", has_selected);

        base.update_actions (selected_count, count);
    }

    private bool can_empty_trash () {
        return (LibraryPhoto.global.get_trashcan_count () > 0) || (Video.global.get_trashcan_count () > 0);
    }

    private void on_trashcan_contents_altered (Gee.Collection<MediaSource>? added,
            Gee.Collection<MediaSource>? removed) {
        if (added != null) {
            foreach (MediaSource source in added)
                get_view ().add (new TrashView (source));
        }

        if (removed != null) {
            Marker marker = get_view ().start_marking ();
            foreach (MediaSource source in removed)
                marker.mark (get_view ().get_view_for_source (source));
            get_view ().remove_marked (marker);
        }

        set_action_sensitive ("EmptyTrash", can_empty_trash ());
    }

    private void on_restore () {
        if (get_view ().get_selected_count () == 0)
            return;

        get_command_manager ().execute (new TrashUntrashPhotosCommand (
                                            (Gee.Collection<LibraryPhoto>) get_view ().get_selected_sources (), false));
    }

    protected override string get_view_empty_message () {
        var window = AppWindow.get_instance () as LibraryWindow;
        warn_if_fail (window != null);
        if (window != null)
            window.toggle_welcome_page (true, "", _ ("Trash is empty"));
        return _ ("Trash is empty");
    }

    private void on_delete () {
        remove_from_app ((Gee.Collection<MediaSource>) get_view ().get_selected_sources (), _ ("Delete"),
                         ngettext ("Deleting a Photo", "Deleting Photos", get_view ().get_selected_count ()), true);
    }

    public void on_empty_trash () {
        Gee.ArrayList<MediaSource> to_remove = new Gee.ArrayList<MediaSource> ();
        to_remove.add_all (LibraryPhoto.global.get_trashcan_contents ());
        to_remove.add_all (Video.global.get_trashcan_contents ());

        remove_from_app (to_remove, _("Empty Trash"), _("Emptying Trash…"), true);

        AppWindow.get_command_manager ().reset ();
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }

    private void on_show_sidebar () {
        var app = AppWindow.get_instance () as LibraryWindow;
        app.set_metadata_sidebar_visible (!app.is_metadata_sidebar_visible ());
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
    }
}
