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

public class SearchRowText : SearchRow {
    private Gtk.ComboBoxText text_context;
    private Gtk.Entry entry;

    public SearchRowText (SearchRowContainer parent) {
        Object (parent: parent);

        // Ordering must correspond with SearchConditionText.Context
        text_context = new Gtk.ComboBoxText ();
        text_context.append_text (_("contains"));
        text_context.append_text (_("is exactly"));
        text_context.append_text (_("starts with"));
        text_context.append_text (_("ends with"));
        text_context.append_text (_("does not contain"));
        text_context.append_text (_("is not set"));
        text_context.set_active (0);
        text_context.changed.connect (on_changed);

        entry = new Gtk.Entry ();
        entry.set_width_chars (25);
        entry.set_activates_default (true);
        entry.changed.connect (on_changed);

        add (text_context);
        add (entry);
        show_all ();
    }

    ~SearchRowText () {
        text_context.changed.disconnect (on_changed);
        entry.changed.disconnect (on_changed);
    }

    public override SearchCondition get_search_condition () {
        SearchCondition.SearchType type = parent.get_search_type ();
        string text = entry.get_text ();
        SearchConditionText.Context context = get_text_context ();
        SearchConditionText c = new SearchConditionText (type, text, context);
        return c;
    }

    public override void populate (SearchCondition sc) {
        SearchConditionText? text = sc as SearchConditionText;
        assert (text != null);
        text_context.set_active (text.context);
        entry.set_text (text.text);
        on_changed ();
    }

    public override bool is_complete () {
        return entry.text.chomp () != "" || get_text_context () == SearchConditionText.Context.IS_NOT_SET;
    }

    private SearchConditionText.Context get_text_context () {
        return (SearchConditionText.Context) text_context.get_active ();
    }

    private void on_changed () {
        if (get_text_context () == SearchConditionText.Context.IS_NOT_SET) {
            entry.hide ();
        } else {
            entry.show ();
        }

        parent.changed (parent);
    }
}
