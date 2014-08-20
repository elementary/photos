/* Copyright 2009-2013 Yorba Foundation
 *
 * This software is licensed under the GNU LGPL (version 2.1 or later).
 * See the COPYING file in this distribution.
 */

public abstract class Properties : Gtk.Grid {
    protected uint line_count = 0;

    public Properties () {
        row_spacing = 0;
        column_spacing = 6;
    }

    protected void add_line (string label_text, string info_text, bool multi_line = false) {
        Gtk.Label label = new Gtk.Label ("");
        Gtk.Widget info;

        label.set_justify (Gtk.Justification.RIGHT);

        label.set_markup (GLib.Markup.printf_escaped ("<span font_weight=\"bold\">%s</span>", label_text));

        if (multi_line) {
            Gtk.ScrolledWindow info_scroll = new Gtk.ScrolledWindow (null, null);
            info_scroll.shadow_type = Gtk.ShadowType.ETCHED_IN;
            Gtk.TextView view = new Gtk.TextView ();
            // by default TextView widgets have a white background, which
            // makes sense during editing. In this instance we only *show*
            // the content and thus want that the parent's background color
            // is inherited to the TextView
            Gtk.StyleContext context = info_scroll.get_style_context ();
            view.override_background_color (Gtk.StateFlags.NORMAL,
                                            context.get_background_color (Gtk.StateFlags.NORMAL));
            view.set_wrap_mode (Gtk.WrapMode.WORD);
            view.set_cursor_visible (false);
            view.set_editable (false);
            view.buffer.text = is_string_empty (info_text) ? "" : info_text;
            info_scroll.add (view);
            label.set_alignment (1, 0);
            info = (Gtk.Widget) info_scroll;
        } else {
            Gtk.Label info_label = new Gtk.Label ("");
            info_label.set_markup (is_string_empty (info_text) ? "" : info_text);
            info_label.set_alignment (0, (float) 5e-1);
            info_label.set_ellipsize (Pango.EllipsizeMode.END);
            info_label.set_selectable (true);
            label.set_alignment (1, (float) 5e-1);
            info = (Gtk.Widget) info_label;
        }

        attach (label, 0, (int) line_count, 1, 1);

        if (multi_line) {
            attach (info, 1, (int) line_count, 1, 2);
        } else {
            attach (info, 1, (int) line_count, 1, 1);
        }

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

    public abstract string get_header_title ();

}





