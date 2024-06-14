/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Photos.MainWindow : Gtk.ApplicationWindow {
    private Gtk.Paned paned;
    private Gtk.Stack stack;


    construct {
        // Construct the left collections pane
        var start_window_controls = new Gtk.WindowControls (Gtk.PackType.START);
        
        var collections_header = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label ("")
        };
        collections_header.add_css_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);
        collections_header.pack_start (start_window_controls);
        
        var collection_listbox = new Gtk.ListBox () {
            hexpand = true,
            vexpand = true
        };
        
        var scrolled = new Gtk.ScrolledWindow () {
            child = collection_listbox
        };
        
        var collection = new Adw.ToolbarView () {
            content = scrolled
        };
        collection.add_css_class (Granite.STYLE_CLASS_SIDEBAR);
        collection.add_top_bar (collections_header);
        
        // Construct the right view stack pane
        var main_header = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label ("")
        };
    
        var placeholder = new Granite.Placeholder (_("No Photos in your collection")) {
            description = _("Add photos to your Pictures folder to view and organize them here"),
            icon = new ThemedIcon ("camera-photo")
        };
    
        stack = new Gtk.Stack () {
            vexpand = true
        };
        stack.add_titled (placeholder, "placeholder", "Photos");
        
        var end_header = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label ("")
        };
        end_header.add_css_class (Granite.STYLE_CLASS_FLAT);
        end_header.pack_end (new Gtk.WindowControls (Gtk.PackType.END));

        var end_box = new Gtk.Box (VERTICAL, 0);
        end_box.add_css_class (Granite.STYLE_CLASS_VIEW);
        end_box.append (end_header);
        end_box.append (stack);
        
        // Build the paned window
        paned = new Gtk.Paned (HORIZONTAL) {
            start_child = collection,
            end_child = end_box
        };
        
        child = paned;
        
        // We need to hide the title area for the split headerbar
        var null_title = new Gtk.Grid () {
            visible = false
        };
        set_titlebar (null_title);
        
        var settings = new Settings ("io.elementary.photos");
        settings.bind ("pane-position", paned, "position", SettingsBindFlags.DEFAULT);
    }
}
