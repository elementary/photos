/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class MetadataView : Gtk.ScrolledWindow {
    private List<Properties> properties_collection = new List<Properties> ();

    private Gtk.Label no_items_label = new Gtk.Label (_("No items selected"));
    private Gtk.Notebook notebook;
    private Gtk.Grid grid;

    private int line_count = 0;

    private BasicProperties colletion_page_properties = new BasicProperties ();

    public MetadataView () {
        set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        grid = new Gtk.Grid ();
        grid.hexpand = true;
        grid.row_spacing = 12;
        grid.margin = 12;

        properties_collection.append (new LibraryProperties ());
        properties_collection.append (new BasicProperties ());
        properties_collection.append (new ExtendedProperties ());

        foreach (var properties in properties_collection) {
            add_expander (properties);
        }

        colletion_page_properties.margin = 12;

        notebook = new Gtk.Notebook ();
        notebook.append_page (grid);
        notebook.append_page (colletion_page_properties);
        notebook.append_page (no_items_label);
        notebook.set_show_tabs (false);

        add (notebook);
    }

    private void add_expander (Properties properties) {
        var expander = new Gtk.Expander ("<b>" + properties.get_header_title () + "</b>");
        expander.use_markup = true;
        expander.add (properties);
        expander.set_spacing (10);
        grid.attach (expander, 0, line_count, 1, 1);
        line_count++;
        expander.set_expanded (true);
    }

    public void update_properties (Page page) {
        /* figure out if we have a single image selected */
        ViewCollection view = page.get_view ();
        bool display_single = false;

        if (view == null) {
            notebook.set_current_page ( notebook.page_num (no_items_label));
            save_changes ();
            return;
        }

        int count = view.get_selected_count ();
        Gee.Iterable<DataView> iter = null;
        if (count != 0) {
            iter = view.get_selected ();
        } else {
            count = view.get_count ();
            iter = (Gee.Iterable<DataView>) view.get_all ();
        }

        if (iter == null || count == 0) {
            notebook.set_current_page (notebook.page_num (no_items_label));
            save_changes ();
            return;
        }

        if (count == 1) {
            foreach (DataView item in iter) {
                var source = item.get_source () as MediaSource;
                if (source == null)
                    display_single = true;
                break;
            }
        } else {
            display_single = true;
        }

        int page_num = 0;
        if (display_single) {
            save_changes ();
            colletion_page_properties.update_properties (page);
            page_num = notebook.page_num (colletion_page_properties);
        } else {
            foreach (var properties in properties_collection)
                properties.update_properties (page);
            page_num = notebook.page_num (grid);
        }
        notebook.set_current_page (page_num);
    }

    public void save_changes () {
        foreach (var properties in properties_collection)
            properties.save_changes_to_source ();
    }
}




