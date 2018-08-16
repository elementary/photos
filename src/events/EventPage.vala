/*
* Copyright (c) 2009-2013 Yorba Foundation
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

public class EventPage : CollectionPage {
    private Event page_event;
    private Gtk.Menu page_sidebar_menu;

    public EventPage (Event page_event) {
        base (page_event.get_name ());

        this.page_event = page_event;
        page_event.mirror_photos (view, create_thumbnail);

        Event.global.items_altered.connect (on_events_altered);
    }

    public Event get_event () {
        return page_event;
    }

    protected override bool on_app_key_pressed (Gdk.EventKey event) {
        // If and only if one image is selected, propagate F2 to the rest of
        // the window, otherwise, consume it here - if we don't do this, it'll
        // either let us re-title multiple images at the same time or
        // spuriously highlight the event name in the sidebar for editing...
        if (Gdk.keyval_name (event.keyval) == "F2") {
            if (view.get_selected_count () != 1) {
                return true;
            }
        }

        return base.on_app_key_pressed (event);
    }

    ~EventPage () {
        Event.global.items_altered.disconnect (on_events_altered);
        view.halt_mirroring ();
    }

    public override Gtk.Menu? get_page_sidebar_menu () {
        if (page_sidebar_menu == null) {
            page_sidebar_menu = new Gtk.Menu ();

            var rename_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.RENAME_EVENT_MENU);
            var rename_action = get_action ("Rename");
            rename_action.bind_property ("sensitive", rename_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            rename_menu_item.activate.connect (() => rename_action.activate ());

            page_sidebar_menu.add (rename_menu_item);
            page_sidebar_menu.show_all ();
        }

        return page_sidebar_menu;
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] new_actions = base.init_collect_action_entries ();

        Gtk.ActionEntry make_primary = { "MakePrimary", null,
                                         Resources.MAKE_KEY_PHOTO_MENU, null, Resources.MAKE_KEY_PHOTO_MENU, on_make_primary
                                       };
        new_actions += make_primary;

        Gtk.ActionEntry rename = { "Rename", null, Resources.RENAME_EVENT_MENU, null, Resources.RENAME_EVENT_MENU, on_rename };
        new_actions += rename;

        return new_actions;
    }

    protected override void init_actions (int selected_count, int count) {
        base.init_actions (selected_count, count);
    }

    protected override void update_actions (int selected_count, int count) {
        set_action_sensitive ("MakePrimary", selected_count == 1);

        // hide this command in CollectionPage, as it does not apply here
        set_action_visible ("CommonJumpToEvent", false);

        base.update_actions (selected_count, count);
    }

    protected override void get_config_photos_sort (out bool sort_order, out int sort_by) {
        sort_order = ui_settings.get_boolean ("event-photos-sort-ascending");
        sort_by = ui_settings.get_int ("event-photos-sort-by");
    }

    protected override void set_config_photos_sort (bool sort_order, int sort_by) {
        ui_settings.set_boolean ("event-photos-sort-ascending", sort_order);
        ui_settings.set_int ("event-photos-sort-by", sort_by);
    }

    private void on_events_altered (Gee.Map<DataObject, Alteration> map) {
        if (map.has_key (page_event)) {
            page_name = page_event.get_name ();
        }
    }

    private void on_make_primary () {
        if (view.get_selected_count () != 1)
            return;

        page_event.set_primary_source ((MediaSource) view.get_selected_at (0).get_source ());
    }

    private void on_rename () {
        LibraryWindow.get_app ().rename_event_in_sidebar (page_event);
    }

    public override Gtk.Box get_header_buttons () {
        header_box = base.get_header_buttons ();
        // Back Button
        var back_button = new Gtk.Button ();
        back_button.clicked.connect (back_to_master_clicked);
        back_button.get_style_context ().add_class ("back-button");
        back_button.can_focus = false;
        back_button.valign = Gtk.Align.CENTER;
        back_button.vexpand = false;
        back_button.visible = false;
        back_button.label = _("All Events");
        header_box.pack_start (back_button);

        return header_box;
    }

    public void back_to_master_clicked () {
        LibraryWindow app = AppWindow.get_instance () as LibraryWindow;
        app.switch_to_event_directory ();
    }

}

public class NoEventPage : CollectionPage {
    public const string NAME = _("No Event");

    // This seems very similar to EventSourceCollection -> ViewManager
    private class NoEventViewManager : CollectionViewManager {
        public NoEventViewManager (NoEventPage page) {
            base (page);
        }

        // this is not threadsafe
        public override bool include_in_view (DataSource source) {
            return (((MediaSource) source).get_event_id ().id != EventID.INVALID) ? false :
                   base.include_in_view (source);
        }
    }

    private static Alteration no_event_page_alteration = new Alteration ("metadata", "event");

    public NoEventPage () {
        base (NAME);

        ViewManager filter = new NoEventViewManager (this);
        view.monitor_source_collection (LibraryPhoto.global, filter, no_event_page_alteration);
        view.monitor_source_collection (Video.global, filter, no_event_page_alteration);
    }

    protected override void get_config_photos_sort (out bool sort_order, out int sort_by) {
        sort_order = ui_settings.get_boolean ("event-photos-sort-ascending");
        sort_by = ui_settings.get_int ("event-photos-sort-by");
    }

    protected override void set_config_photos_sort (bool sort_order, int sort_by) {
        ui_settings.set_boolean ("event-photos-sort-ascending", sort_order);
        ui_settings.set_int ("event-photos-sort-by", sort_by);
    }
}

