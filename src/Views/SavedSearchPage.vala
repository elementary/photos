/*
* Copyright (c) 2011-2013 Yorba Foundation
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

// Source monitoring for saved searches.
private class SavedSearchManager : CollectionViewManager {
    SavedSearch search;
    public SavedSearchManager (SavedSearchPage owner, SavedSearch search) {
        base (owner);
        this.search = search;
    }

    public override bool include_in_view (DataSource source) {
        return search.predicate ((MediaSource) source);
    }
}

// Page for displaying saved searches.
public class SavedSearchPage : CollectionPage {

    // The search logic and parameters are contained in the SavedSearch.
    private SavedSearch search;
    private Gtk.Menu page_sidebar_menu;

    public SavedSearchPage (SavedSearch search) {
        base (search.get_name ());
        this.search = search;


        foreach (MediaSourceCollection sources in MediaCollectionRegistry.get_instance ().get_all ())
            get_view ().monitor_source_collection (sources, new SavedSearchManager (this, search), null);
    }

    public override Gtk.Menu? get_page_sidebar_menu () {
        if (page_sidebar_menu == null) {
            page_sidebar_menu = new Gtk.Menu ();

            var rename_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.RENAME_SEARCH_MENU);
            var rename_action = get_action ("RenameSearch");
            rename_menu_item.activate.connect (() => rename_action.activate ());

            var edit_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.EDIT_SEARCH_MENU);
            var edit_action = get_action ("EditSearch");
            edit_menu_item.activate.connect (() => edit_action.activate ());

            var delete_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.DELETE_SEARCH_MENU);
            var delete_action = get_action ("DeleteSearch");
            delete_menu_item.activate.connect (() => delete_action.activate ());

            page_sidebar_menu.add (rename_menu_item);
            page_sidebar_menu.add (edit_menu_item);
            page_sidebar_menu.add (delete_menu_item);
            page_sidebar_menu.show_all ();
        }

        return page_sidebar_menu;
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry rename_search = { "RenameSearch", null, TRANSLATABLE, null, null, on_rename_search };
        actions += rename_search;

        Gtk.ActionEntry edit_search = { "EditSearch", null, TRANSLATABLE, null, null, on_edit_search };
        actions += edit_search;

        Gtk.ActionEntry delete_search = { "DeleteSearch", null, TRANSLATABLE, null, null, on_delete_search };
        actions += delete_search;

        return actions;
    }

    private void on_delete_search () {
        if (Dialogs.confirm_delete_saved_search (search))
            AppWindow.get_command_manager ().execute (new DeleteSavedSearchCommand (search));
    }

    private void on_rename_search () {
        LibraryWindow.get_app ().rename_search_in_sidebar (search);
    }

    private void on_edit_search () {
        SavedSearchDialog ssd = new SavedSearchDialog.edit_existing (search);
        ssd.show ();
    }

    protected override void update_actions (int selected_count, int count) {
        set_action_details ("RenameSearch",
                            Resources.RENAME_SEARCH_MENU,
                            null, true);
        set_action_details ("EditSearch",
                            Resources.EDIT_SEARCH_MENU,
                            null, true);
        set_action_details ("DeleteSearch",
                            Resources.DELETE_SEARCH_MENU,
                            null, true);
        base.update_actions (selected_count, count);
    }
}

