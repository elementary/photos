/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2016 elementary LLC. (https://github.com/elementary/photos)
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

public abstract class Properties : Gtk.Grid {
    protected uint line_count = 0;

    protected Properties () {
        row_spacing = 0;
        column_spacing = 6;
    }

    protected void add_line (string label_text, string info_text) {
        if (info_text == null || info_text == "") {
            return;
        }

        var label = new Properties.Header (GLib.Markup.printf_escaped ("%s", label_text));
        var info_label = new Properties.Label (is_string_empty (info_text) ? "" : info_text);

        attach (label, 0, (int) line_count, 1, 1);
        attach (info_label, 1, (int) line_count, 1, 1);

        line_count++;
    }

    protected string get_prettyprint_time (Time time) {
        string timestring = time.format (Resources.get_hh_mm_format_string ());

        if (timestring[0] == '0')
            timestring = timestring.substring (1, -1);

        return timestring;
    }

    protected string get_prettyprint_time_with_seconds (Time time) {
        string timestring = time.format (Resources.get_hh_mm_ss_format_string ());

        if (timestring[0] == '0')
            timestring = timestring.substring (1, -1);

        return timestring;
    }

    protected string get_prettyprint_date (Time date) {
        string date_string = null;
        Time today = Time.local (time_t ());
        if (date.day_of_year == today.day_of_year && date.year == today.year) {
            date_string = _ ("Today");
        } else if (date.day_of_year == (today.day_of_year - 1) && date.year == today.year) {
            date_string = _ ("Yesterday");
        } else {
            date_string = format_local_date (date);
        }

        return date_string;
    }

    protected virtual void get_single_properties (DataView view) {
    }

    protected virtual void get_multiple_properties (Gee.Iterable<DataView>? iter) {
    }

    protected virtual void get_properties (Page current_page) {
        ViewCollection view = current_page.get_view ();
        if (view == null)
            return;

        // summarize selected items, if none selected, summarize all
        int count = view.get_selected_count ();
        Gee.Iterable<DataView> iter = null;
        if (count != 0) {
            iter = view.get_selected ();
        } else {
            count = view.get_count ();
            iter = (Gee.Iterable<DataView>) view.get_all ();
        }

        if (iter == null || count == 0)
            return;

        if (count == 1) {
            foreach (DataView item in iter) {
                get_single_properties (item);
                break;
            }
        } else {
            get_multiple_properties (iter);
        }
    }

    protected virtual void clear_properties () {
        foreach (Gtk.Widget child in get_children ())
            remove (child);

        line_count = 0;
    }

    public virtual void update_properties (Page page) {
        clear_properties ();
        internal_update_properties (page);
        show_all ();
    }

    public virtual void internal_update_properties (Page page) {
        get_properties (page);
    }

    public void unselect_text () {
        foreach (Gtk.Widget child in get_children ()) {
            if (child is Gtk.Label)
                ((Gtk.Label) child).select_region (0, 0);
        }
    }

    public virtual void save_changes_to_source () {
    }

    public class Header : Gtk.Label {
        public Header (string text) {
            label = text;
            lines = 8;
            valign = Gtk.Align.START;
            wrap = true;
            wrap_mode = Pango.WrapMode.WORD_CHAR;
            xalign = 1;
        }
    }

    public class Label : Gtk.Label {
        public Label (string text) {
            ellipsize = Pango.EllipsizeMode.END;
            label = text;
            lines = 8;
            selectable = true;
            use_markup = true;
            wrap = true;
            wrap_mode = Pango.WrapMode.WORD_CHAR;
            xalign = 0;
        }
    }
}
