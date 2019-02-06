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

public class SearchRowFlagged : SearchRow {
    private Gtk.ComboBoxText flagged_state;

    public SearchRowFlagged (SearchRowContainer parent) {
        Object (parent: parent);

        // Ordering must correspond with SearchConditionFlagged.State
        flagged_state = new Gtk.ComboBoxText ();
        flagged_state.append_text (_ ("flagged"));
        flagged_state.append_text (_ ("not flagged"));
        flagged_state.set_active (0);
        flagged_state.changed.connect (on_changed);

        add (new Gtk.Label (_("is")));
        add (flagged_state);
        show_all ();
    }

    ~SearchRowFlagged () {
        flagged_state.changed.disconnect (on_changed);
    }

    public override SearchCondition get_search_condition () {
        SearchCondition.SearchType search_type = parent.get_search_type ();
        SearchConditionFlagged.State state = (SearchConditionFlagged.State) flagged_state.get_active ();
        SearchConditionFlagged c = new SearchConditionFlagged (search_type, state);
        return c;
    }

    public override void populate (SearchCondition sc) {
        SearchConditionFlagged? f = sc as SearchConditionFlagged;
        assert (f != null);
        flagged_state.set_active (f.state);
    }

    public override bool is_complete () {
        return true;
    }

    private void on_changed () {
        parent.changed (parent);
    }
}
