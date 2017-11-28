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

public class DirectWindow : AppWindow {
    private DirectPhotoPage direct_photo_page;

    public DirectWindow (File file) {
        direct_photo_page = new DirectPhotoPage (file);
        direct_photo_page.get_view ().items_altered.connect (on_photo_changed);
        direct_photo_page.get_view ().items_state_changed.connect (on_photo_changed);

        set_current_page (direct_photo_page);

        update_title (file, false);

        direct_photo_page.switched_to ();

        // simple layout: menu on top, photo in center, toolbar along bottom (mimicking the
        // PhotoPage in the library, but without the sidebar)
        Gtk.Box layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        layout.pack_start (direct_photo_page, true, true, 0);
        layout.pack_end (direct_photo_page.get_toolbar (), false, false, 0);

        add (layout);
        header.pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));

        var save_action = get_direct_page ().get_action ("Save");
        var save_btn = save_action.create_tool_item ();
        save_btn.sensitive = true;
        header.pack_start (save_btn);

        var save_as_action = get_direct_page ().get_action ("SaveAs");
        var save_as_btn = save_as_action.create_tool_item ();
        save_as_btn.sensitive = true;
        header.pack_start (save_as_btn);
    }

    public static DirectWindow get_app () {
        return (DirectWindow) instance;
    }

    public DirectPhotoPage get_direct_page () {
        return (DirectPhotoPage) get_current_page ();
    }

    public void update_title (File file, bool modified) {
        title = "%s%s (%s) - %s".printf ((modified) ? "*" : "", file.get_basename (),
                                         get_display_pathname (file.get_parent ()), _ (Resources.APP_TITLE));
    }

    protected override void on_fullscreen () {
        File file = get_direct_page ().get_current_file ();

        go_fullscreen (new DirectPhotoPage (file, true));
    }

    public override string get_app_role () {
        return Resources.APP_DIRECT_ROLE;
    }

    private void on_photo_changed () {
        Photo? photo = direct_photo_page.get_photo ();
        if (photo != null)
            update_title (photo.get_file (), photo.has_alterations ());
    }

    protected override void on_quit () {
        if (!get_direct_page ().check_quit ())
            return;

        window_settings.set_boolean ("direct-maximize", is_maximized);
        window_settings.set_int ("direct-width", dimensions.width);
        window_settings.set_int ("direct-height", dimensions.height);

        base.on_quit ();
    }

    public override bool delete_event (Gdk.EventAny event) {
        if (!get_direct_page ().check_quit ())
            return true;

        return (base.delete_event != null) ? base.delete_event (event) : false;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        // check for an escape
        if (Gdk.keyval_name (event.keyval) == "Escape") {
            on_quit ();

            return true;
        }

        // ...then let the base class take over
        return (base.key_press_event != null) ? base.key_press_event (event) : false;
    }
}
