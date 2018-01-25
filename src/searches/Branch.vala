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

public class Searches.Branch : Sidebar.Branch {
    private Gee.HashMap<SavedSearch, Searches.SidebarEntry> entry_map =
        new Gee.HashMap<SavedSearch, Searches.SidebarEntry> ();

    public Branch () {
        base (new Searches.Grouping (),
              Sidebar.Branch.Options.HIDE_IF_EMPTY
              | Sidebar.Branch.Options.AUTO_OPEN_ON_NEW_CHILD
              | Sidebar.Branch.Options.STARTUP_EXPAND_TO_FIRST_CHILD,
              comparator);

        // seed the branch with existing searches
        foreach (SavedSearch search in SavedSearchTable.get_instance ().get_all ())
            on_saved_search_added (search);

        // monitor collection for future events
        SavedSearchTable.get_instance ().search_added.connect (on_saved_search_added);
        SavedSearchTable.get_instance ().search_removed.connect (on_saved_search_removed);
    }

    ~Branch () {
        SavedSearchTable.get_instance ().search_added.disconnect (on_saved_search_added);
        SavedSearchTable.get_instance ().search_removed.disconnect (on_saved_search_removed);
    }

    public Searches.SidebarEntry? get_entry_for_saved_search (SavedSearch search) {
        return entry_map.get (search);
    }

    private static int comparator (Sidebar.Entry a, Sidebar.Entry b) {
        if (a == b)
            return 0;

        return SavedSearch.compare_names (((Searches.SidebarEntry) a).for_saved_search (),
                                          ((Searches.SidebarEntry) b).for_saved_search ());
    }

    private void on_saved_search_added (SavedSearch search) {
        debug ("smart album added");
        Searches.SidebarEntry entry = new Searches.SidebarEntry (search);
        entry_map.set (search, entry);
        graft (get_root (), entry);
    }

    private void on_saved_search_removed (SavedSearch search) {
        debug ("smart album removed");
        Searches.SidebarEntry? entry = entry_map.get (search);
        assert (entry != null);

        bool is_removed = entry_map.unset (search);
        assert (is_removed);

        prune (entry);
    }
}

public class Searches.Grouping : Sidebar.Grouping, Sidebar.Contextable {
    private Gtk.Menu? context_menu = null;

    public Grouping () {
        base (_ ("Smart Albums"), new ThemedIcon ("playlist-automatic"));
    }

    public Gtk.Menu? get_sidebar_context_menu (Gdk.EventButton? event) {
        if (context_menu == null) {
            context_menu = new Gtk.Menu ();

            var new_search_menu_item = new Gtk.MenuItem.with_mnemonic (_("New Smart Album…"));
            new_search_menu_item.activate.connect (() => on_new_search);
            context_menu.add (new_search_menu_item);
            context_menu.show_all ();
        }

        return context_menu;
    }

    private void on_new_search () {
        (new SavedSearchDialog ()).show ();
    }
}

public class Searches.SidebarEntry : Sidebar.SimplePageEntry, Sidebar.RenameableEntry,
    Sidebar.DestroyableEntry {
    private static Icon single_search_icon;

    private SavedSearch search;

    class construct {
        single_search_icon = new ThemedIcon ("playlist-automatic");
    }

    public SidebarEntry (SavedSearch search) {
        this.search = search;
    }

    public SavedSearch for_saved_search () {
        return search;
    }

    public override string get_sidebar_name () {
        return search.get_name ();
    }

    public override Icon? get_sidebar_icon () {
        return single_search_icon;
    }

    protected override Page create_page () {
        return new SavedSearchPage (search);
    }

    public void rename (string new_name) {
        if (!SavedSearchTable.get_instance ().exists (new_name))
            AppWindow.get_command_manager ().execute (new RenameSavedSearchCommand (search, new_name));
        else if (new_name != search.get_name ())
            AppWindow.error_message (Resources.rename_search_exists_message (new_name));
    }

    public void destroy_source () {
        if (Dialogs.confirm_delete_saved_search (search))
            AppWindow.get_command_manager ().execute (new DeleteSavedSearchCommand (search));
    }
}
