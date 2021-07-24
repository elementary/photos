/*
* Copyright (c) 2009-2013 Yorba Foundation
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

public class DirectWindow : AppWindow {
    private DirectPhotoPage direct_photo_page;

    public DirectWindow (File file) {
        direct_photo_page = new DirectPhotoPage (file);
        direct_photo_page.expand = true;
        direct_photo_page.get_view ().items_altered.connect (on_photo_changed);
        direct_photo_page.get_view ().items_state_changed.connect (on_photo_changed);

        set_current_page (direct_photo_page);

        update_title (file, false);

        direct_photo_page.switched_to ();

        var layout = new Gtk.Grid ();
        layout.orientation = Gtk.Orientation.VERTICAL;
        layout.add (header);
        layout.add (direct_photo_page);
        layout.add (direct_photo_page.get_toolbar ());

        add (layout);

        var save_btn = new Gtk.Button ();
        save_btn.related_action = get_direct_page ().get_action ("Save");
        save_btn.image = new Gtk.Image.from_icon_name ("document-save", Gtk.IconSize.LARGE_TOOLBAR);
        save_btn.tooltip_text = _("Save photo");

        var save_as_btn = new Gtk.Button ();
        save_as_btn.related_action = get_direct_page ().get_action ("SaveAs");
        save_as_btn.image = new Gtk.Image.from_icon_name ("document-save-as", Gtk.IconSize.LARGE_TOOLBAR);
        save_as_btn.tooltip_text = _("Save photo with a different name");

        header.has_subtitle = false;
        header.pack_start (save_btn);
        header.pack_start (save_as_btn);
        header.pack_end (redo_btn);
        header.pack_end (undo_btn);
    }

    construct {
        set_default_size (
            window_settings.get_int ("direct-width"),
            window_settings.get_int ("direct-height")
        );

        if (window_settings.get_boolean ("direct-maximize")) {
            maximize ();
        }
    }

    public static DirectWindow get_app () {
        return (DirectWindow) instance;
    }

    public DirectPhotoPage get_direct_page () {
        return (DirectPhotoPage) get_current_page ();
    }

    public void update_title (File file, bool modified) {
        header.title = "%s%s (%s) - %s".printf ((modified) ? "*" : "", file.get_basename (),
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
