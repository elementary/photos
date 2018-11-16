/*
* Copyright (c) 2011-2013 Yorba Foundation
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

public class SearchRowContainer : Object {
    public signal void remove (SearchRowContainer this_row);
    public signal void changed (SearchRowContainer this_row);

    private Gtk.ComboBoxText type_combo;
    private Gtk.Grid grid;
    private Gtk.Grid align;
    private Gtk.Button remove_button;
    private SearchCondition.SearchType[] search_types;
    private Gee.HashMap<SearchCondition.SearchType, int> search_types_index;

    private SearchRow? my_row = null;

    public SearchRowContainer () {
        setup_gui ();
        set_type (SearchCondition.SearchType.ANY_TEXT);
    }

    public SearchRowContainer.edit_existing (SearchCondition sc) {
        setup_gui ();
        set_type (sc.search_type);
        set_type_combo_box (sc.search_type);
        my_row.populate (sc);
    }

    private void setup_gui () {
        search_types = SearchCondition.SearchType.as_array ();
        search_types_index = new Gee.HashMap<SearchCondition.SearchType, int> ();
        SearchCondition.SearchType.sort_array (ref search_types);

        type_combo = new Gtk.ComboBoxText ();
        for (int i = 0; i < search_types.length; i++) {
            SearchCondition.SearchType st = search_types[i];
            search_types_index.set (st, i);
            type_combo.append_text (st.display_text ());
        }
        set_type_combo_box (SearchCondition.SearchType.ANY_TEXT); // Sets default.
        type_combo.changed.connect (on_type_changed);

        remove_button = new Gtk.Button.from_icon_name ("list-remove-symbolic", Gtk.IconSize.BUTTON);
        remove_button.halign = Gtk.Align.END;
        remove_button.hexpand = true;
        remove_button.tooltip_text = _("Remove rule");
        remove_button.button_press_event.connect (on_removed);

        align = new Gtk.Grid ();

        grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.add (type_combo);
        grid.add (align);
        grid.add (remove_button);
        grid.show_all ();
    }

    private void on_type_changed () {
        set_type (get_search_type ());
        changed (this);
    }

    private void set_type_combo_box (SearchCondition.SearchType st) {
        type_combo.set_active (search_types_index.get (st));
    }

    private void set_type (SearchCondition.SearchType type) {
        if (my_row != null)
            align.remove (my_row);

        switch (type) {
        case SearchCondition.SearchType.ANY_TEXT:
        case SearchCondition.SearchType.EVENT_NAME:
        case SearchCondition.SearchType.FILE_NAME:
        case SearchCondition.SearchType.TAG:
        case SearchCondition.SearchType.COMMENT:
        case SearchCondition.SearchType.TITLE:
            my_row = new SearchRowText (this);
            break;

        case SearchCondition.SearchType.MEDIA_TYPE:
            my_row = new SearchRowMediaType (this);
            break;

        case SearchCondition.SearchType.FLAG_STATE:
            my_row = new SearchRowFlagged (this);
            break;

        case SearchCondition.SearchType.MODIFIED_STATE:
            my_row = new SearchRowModified (this);
            break;

        case SearchCondition.SearchType.DATE:
            my_row = new SearchRowDate (this);
            break;

        default:
            assert (false);
            break;
        }

        align.add (my_row);
    }

    public SearchCondition.SearchType get_search_type () {
        return search_types[type_combo.get_active ()];
    }

    private bool on_removed (Gdk.EventButton event) {
        remove (this);
        return false;
    }

    public void allow_removal (bool allow) {
        remove_button.sensitive = allow;
    }

    public Gtk.Widget get_widget () {
        return grid;
    }

    public SearchCondition get_search_condition () {
        return my_row.get_search_condition ();
    }

    public bool is_complete () {
        return my_row.is_complete ();
    }
}
