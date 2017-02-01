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

    public TrashPage () {
        base (NAME);

        init_item_context_menu ("/TrashContextMenu");
        init_page_sidebar_menu ("/TrashPageMenu");
        init_page_context_menu ("/TrashViewMenu");

        tracker = new MediaViewTracker (get_view ());

        // monitor trashcans and initialize view with all items in them
        LibraryPhoto.global.trashcan_contents_altered.connect (on_trashcan_contents_altered);
        Video.global.trashcan_contents_altered.connect (on_trashcan_contents_altered);
        on_trashcan_contents_altered (LibraryPhoto.global.get_trashcan_contents (), null);
        on_trashcan_contents_altered (Video.global.get_trashcan_contents (), null);
    }

    public override Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            toolbar = new Gtk.Toolbar ();
            toolbar.get_style_context ().add_class ("bottom-toolbar"); // for elementary theme
            toolbar.set_style (Gtk.ToolbarStyle.ICONS);
            var app = AppWindow.get_instance () as LibraryWindow;

            // separator to force slider to right side of toolbar
            Gtk.SeparatorToolItem separator = new Gtk.SeparatorToolItem ();
            separator.set_expand (true);
            separator.set_draw (false);
            toolbar.insert (separator, -1);

            Gtk.SeparatorToolItem drawn_separator = new Gtk.SeparatorToolItem ();
            drawn_separator.set_expand (false);
            drawn_separator.set_draw (true);

            toolbar.insert (drawn_separator, -1);

            var restore_button = new Gtk.Button.with_mnemonic (Resources.RESTORE_PHOTOS_MENU);
            restore_button.margin_start = restore_button.margin_end = 3;
            restore_button.clicked.connect (on_restore);
            restore_button.tooltip_text = Resources.RESTORE_PHOTOS_TOOLTIP;
            var restore_tool = new Gtk.ToolItem ();
            restore_tool.add (restore_button);
            toolbar.insert (restore_tool, -1);
            var restore_action = get_action ("Restore");
            restore_action.bind_property ("sensitive", restore_button, "sensitive", BindingFlags.SYNC_CREATE);

            var delete_button = new Gtk.Button.with_mnemonic (Resources.DELETE_PHOTOS_MENU);
            delete_button.margin_start = delete_button.margin_end = 3;
            delete_button.clicked.connect (on_delete);
            delete_button.tooltip_text = Resources.DELETE_FROM_TRASH_TOOLTIP;
            var delete_tool = new Gtk.ToolItem ();
            delete_tool.add (delete_button);
            toolbar.insert (delete_tool, -1);
            var delete_action = get_action ("Delete");
            delete_action.bind_property ("sensitive", delete_button, "sensitive", BindingFlags.SYNC_CREATE);

            var empty_trash_button = new Gtk.Button.with_mnemonic (_("_Empty Trash"));
            empty_trash_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            empty_trash_button.margin_start = empty_trash_button.margin_end = 3;
            empty_trash_button.clicked.connect (on_empty_trash);
            empty_trash_button.tooltip_text = _("Delete all photos in the trash");
            var empty_trash_tool = new Gtk.ToolItem ();
            empty_trash_tool.add (empty_trash_button);
            toolbar.insert (empty_trash_tool, -1);
            var empty_trash_action = get_action ("EmptyTrash");
            empty_trash_action.bind_property ("sensitive", empty_trash_button, "sensitive", BindingFlags.SYNC_CREATE);

            //  show metadata sidebar button
            show_sidebar_button = MediaPage.create_sidebar_button ();
            show_sidebar_button.clicked.connect (on_show_sidebar);
            toolbar.insert (show_sidebar_button, -1);
            update_sidebar_action (!app.is_metadata_sidebar_visible ());
        }
        return toolbar;
    }

    protected override void init_collect_ui_filenames (Gee.List<string> ui_filenames) {
        base.init_collect_ui_filenames (ui_filenames);

        ui_filenames.add ("trash.ui");
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
        set_action_important ("Delete", true);
        set_action_sensitive ("Restore", has_selected);
        set_action_important ("Restore", true);
        set_action_important ("EmptyTrash", true);

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
                         ngettext ("Deleting a Photo", "Deleting Photos", get_view().get_selected_count ()), true);
    }

    public void on_empty_trash () {
        Gee.ArrayList<MediaSource> to_remove = new Gee.ArrayList<MediaSource> ();
        to_remove.add_all (LibraryPhoto.global.get_trashcan_contents ());
        to_remove.add_all (Video.global.get_trashcan_contents ());

        remove_from_app (to_remove, _ ("Empty Trash"),  _ ("Emptying Trash…"), true);

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
