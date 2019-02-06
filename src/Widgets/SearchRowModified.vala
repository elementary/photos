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

public class SearchRowModified : SearchRow {
    private Gtk.ComboBoxText modified_context;
    private Gtk.ComboBoxText modified_state;

    public SearchRowModified (SearchRowContainer parent) {
        Object (parent: parent);

        modified_context = new Gtk.ComboBoxText ();
        modified_context.append_text (_ ("has"));
        modified_context.append_text (_ ("has no"));
        modified_context.set_active (0);
        modified_context.changed.connect (on_changed);

        modified_state = new Gtk.ComboBoxText ();
        modified_state.append_text (_ ("modifications"));
        modified_state.append_text (_ ("internal modifications"));
        modified_state.append_text (_ ("external modifications"));
        modified_state.set_active (0);
        modified_state.changed.connect (on_changed);

        add (modified_context);
        add (modified_state);
        show_all ();
    }

    ~SearchRowModified () {
        modified_state.changed.disconnect (on_changed);
        modified_context.changed.disconnect (on_changed);
    }

    public override SearchCondition get_search_condition () {
        SearchCondition.SearchType search_type = parent.get_search_type ();
        SearchConditionModified.Context context = (SearchConditionModified.Context) modified_context.get_active ();
        SearchConditionModified.State state = (SearchConditionModified.State) modified_state.get_active ();
        SearchConditionModified c = new SearchConditionModified (search_type, context, state);
        return c;
    }

    public override void populate (SearchCondition sc) {
        SearchConditionModified? scm = sc as SearchConditionModified;
        assert (scm != null);
        modified_state.set_active (scm.state);
        modified_context.set_active (scm.context);
    }

    public override bool is_complete () {
        return true;
    }

    private void on_changed () {
        parent.changed (parent);
    }
}
