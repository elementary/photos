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

public class SearchRowDate : SearchRow {
    private const string DATE_FORMAT = "%x";
    private Gtk.Box box;
    private Gtk.ComboBoxText context;
    private Granite.Widgets.DatePicker datepicker_one;
    private Granite.Widgets.DatePicker datepicker_two;
    private Gtk.Label and;

    private SearchRowContainer parent;

    public SearchRowDate (SearchRowContainer parent) {
        this.parent = parent;

        // Ordering must correspond with Context
        context = new Gtk.ComboBoxText ();
        context.append_text (_("is exactly"));
        context.append_text (_("is after"));
        context.append_text (_("is before"));
        context.append_text (_("is between"));
        context.append_text (_("is not set"));
        context.set_active (0);
        context.changed.connect (on_changed);

        datepicker_one = new Granite.Widgets.DatePicker ();
        datepicker_two = new Granite.Widgets.DatePicker ();

        and = new Gtk.Label (_ ("and"));

        box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        box.pack_start (context, false, false, 0);
        box.pack_start (datepicker_one, false, false, 0);
        box.pack_start ( and , false, false, 0);
        box.pack_start (datepicker_two, false, false, 0);

        box.show_all ();
        update_datepickers ();
    }

    ~SearchRowDate () {
        context.changed.disconnect (on_changed);
    }

    private void update_datepickers () {
        SearchConditionDate.Context c = (SearchConditionDate.Context)context.get_active ();

        // Only show "and" and 2nd date label for between mode.
        if (c == SearchConditionDate.Context.BETWEEN) {
            datepicker_one.show ();
            and.show ();
            datepicker_two.show ();
        } else if (c == SearchConditionDate.Context.IS_NOT_SET) {
            datepicker_one.hide ();
            and.hide ();
            datepicker_two.hide ();
        } else {
            datepicker_one.show ();
            and.hide ();
            datepicker_two.hide ();
        }
    }

    public override Gtk.Widget get_widget () {
        return box;
    }

    public override SearchCondition get_search_condition () {
        SearchCondition.SearchType search_type = parent.get_search_type ();
        SearchConditionDate.Context search_context = (SearchConditionDate.Context) context.get_active ();
        SearchConditionDate c = new SearchConditionDate (search_type, search_context, datepicker_one.date,
                datepicker_two.date);
        return c;
    }

    public override void populate (SearchCondition sc) {
        SearchConditionDate? cond = sc as SearchConditionDate;
        assert (cond != null);
        context.set_active (cond.context);
        datepicker_one.date = cond.date_one;
        datepicker_two.date = cond.date_two;
        update_datepickers ();
    }

    public override bool is_complete () {
        return true;
    }

    private void on_changed () {
        parent.changed (parent);
        update_datepickers ();
    }
}
