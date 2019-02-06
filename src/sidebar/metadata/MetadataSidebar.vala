/*
* Copyright (c) 2011-2014 Yorba Foundation
*               2016 elementary LLC (https://github.com/elementary/photos)
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

public class MetadataView : Gtk.ScrolledWindow {
    private List<Properties> properties_collection = new List<Properties> ();

    private Gtk.Grid grid;
    private Gtk.Label no_items_label;
    private Gtk.Stack stack;

    private int line_count = 0;

    private BasicProperties collection_page_properties;

    public MetadataView () {
        hscrollbar_policy = Gtk.PolicyType.NEVER;

        grid = new Gtk.Grid ();
        grid.hexpand = true;
        grid.row_spacing = 12;
        grid.margin = 12;

        properties_collection.append (new BasicProperties ());
        properties_collection.append (new LibraryProperties ());
        properties_collection.append (new ExtendedProperties ());

        foreach (var properties in properties_collection) {
            grid.attach (properties, 0, line_count, 1, 1);
            line_count++;
        }

        collection_page_properties = new BasicProperties ();
        collection_page_properties.margin = 12;

        no_items_label = new Gtk.Label (_("No items selected"));

        stack = new Gtk.Stack ();
        stack.add (grid);
        stack.add (collection_page_properties);
        stack.add (no_items_label);

        add (stack);
    }

    public void update_properties (Page page) {
        /* figure out if we have a single image selected */
        ViewCollection view = page.get_view ();
        bool display_single = false;

        if (view == null) {
            stack.visible_child = no_items_label;
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
            stack.visible_child = no_items_label;
            save_changes ();
            return;
        }

        if (count == 1) {
            foreach (DataView item in iter) {
                var source = item.source as MediaSource;
                if (source == null)
                    display_single = true;
                break;
            }
        } else {
            display_single = true;
        }

        if (display_single) {
            save_changes ();
            collection_page_properties.update_properties (page);
            stack.visible_child = collection_page_properties;
        } else {
            foreach (var properties in properties_collection) {
                properties.update_properties (page);
            }
            stack.visible_child = grid;
        }
    }

    public void save_changes () {
        foreach (var properties in properties_collection)
            properties.save_changes_to_source ();
    }
}
