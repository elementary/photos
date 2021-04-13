/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
*               2009-2013 Yorba Foundation
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

public class FullscreenWindow : PageWindow {
    public const int TOOLBAR_DISMISSAL_SEC = 2;
    public const int TOOLBAR_CHECK_DISMISSAL_MSEC = 500;

    private Gtk.Revealer revealer;
    private Gtk.ActionBar toolbar;
    private Gtk.ToggleButton pin_button;
    private int64 left_toolbar_time = 0;
    private bool switched_to = false;

    public bool auto_dismiss_toolbar { get; set; default = true; }

    public FullscreenWindow (Page page) {
        set_current_page (page);

        ui.ensure_update ();

        Gtk.AccelGroup accel_group = ui.get_accel_group ();
        if (accel_group != null)
            add_accel_group (accel_group);

        set_screen (AppWindow.get_instance ().get_screen ());

        // Needed so fullscreen will occur on correct monitor in multi-monitor setups
        Gdk.Rectangle monitor = get_monitor_geometry ();
        move (monitor.x, monitor.y);

        set_border_width (0);

        pin_button = new Gtk.ToggleButton ();
        pin_button.image = new Gtk.Image.from_icon_name ("view-pin-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        pin_button.tooltip_text = _("Pin the toolbar open");
        pin_button.bind_property ("active", this, "auto-dismiss-toolbar", GLib.BindingFlags.INVERT_BOOLEAN);

        var close_button = new Gtk.Button.from_icon_name ("window-restore-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        close_button.tooltip_text = _("Leave fullscreen");
        close_button.clicked.connect (on_close);

        toolbar = page.get_toolbar ();
        toolbar.halign = Gtk.Align.CENTER;
        toolbar.margin = 6;
        toolbar.get_style_context ().add_class ("overlay-toolbar");

        if (page is SlideshowPage) {
            // slideshow page doesn't own toolbar to hide it, subscribe to signal instead
            ((SlideshowPage) page).hide_toolbar.connect (hide_toolbar);
        } else {
            // only non-slideshow pages should have pin button
            toolbar.pack_end (pin_button);
        }

        page.set_cursor_hide_time (TOOLBAR_DISMISSAL_SEC * 1000);
        page.start_cursor_hiding ();

        toolbar.pack_end (close_button);

        revealer = new Gtk.Revealer ();
        revealer.halign = Gtk.Align.CENTER;
        revealer.valign = Gtk.Align.END;
        revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        revealer.add (toolbar);

        var overlay = new Gtk.Overlay ();
        overlay.add (page);
        overlay.add_overlay (revealer);

        add (overlay);

        // call to set_default_size () saves one repaint caused by changing
        // size from default to full screen. In slideshow mode, this change
        // also causes pixbuf cache updates, so it really saves some work.
        set_default_size (monitor.width, monitor.height);

        // need to create a Gdk.Window to set masks
        fullscreen ();
        show_all ();

        // capture motion events to show the toolbar
        add_events (Gdk.EventMask.POINTER_MOTION_MASK);

        // start off with toolbar invoked, as a clue for the user
        invoke_toolbar ();

        page.grab_focus ();
    }

    private Gdk.Rectangle get_monitor_geometry () {
        var monitor = get_display ().get_monitor_at_window (AppWindow.get_instance ().get_window ());
        return monitor.get_geometry ();
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        bool result = base.configure_event (event);

        if (!switched_to) {
            get_current_page ().switched_to ();
            switched_to = true;
        }

        return result;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        // check for an escape/abort
        switch (Gdk.keyval_name (event.keyval)) {
            case "F11":
            case "Escape":
                on_close ();
                return true;
        }

        return (base.key_press_event != null) ? base.key_press_event (event) : false;
    }

    private void on_close () {
        hide_toolbar ();

        AppWindow.get_instance ().end_fullscreen ();
    }

    public new void close () {
        on_close ();
    }

    public override void destroy () {
        Page? page = get_current_page ();
        clear_current_page ();

        if (page != null) {
            page.stop_cursor_hiding ();
            page.switching_from ();
        }

        base.destroy ();
    }

    public override bool delete_event (Gdk.EventAny event) {
        on_close ();
        AppWindow.get_instance ().destroy ();

        return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (!revealer.reveal_child) {
            invoke_toolbar ();
        }

        return (base.motion_notify_event != null) ? base.motion_notify_event (event) : false;
    }

    private bool is_pointer_in_toolbar () {
        var seat = get_display ().get_default_seat ();
        if (seat == null) {
            debug ("No seat for display");

            return false;
        }

        int py;
        seat.get_pointer ().get_position (null, null, out py);

        Gtk.Allocation toolbar_alloc;
        toolbar.get_allocation (out toolbar_alloc);

        var screen_rect = get_monitor_geometry ();

        int threshold = screen_rect.height;
        if (revealer.reveal_child) {
            threshold -= toolbar_alloc.height;
        }

        return py >= threshold;
    }

    private void invoke_toolbar () {
        revealer.reveal_child = true;

        Timeout.add (TOOLBAR_CHECK_DISMISSAL_MSEC, on_check_toolbar_dismissal);
    }

    private bool on_check_toolbar_dismissal () {
        if (!revealer.reveal_child)
            return false;

        // if dismissal is disabled, keep open but keep checking
        if (!auto_dismiss_toolbar) {
            return true;
        }

        // if the pointer is in toolbar range, keep it alive, but keep checking
        if (is_pointer_in_toolbar ()) {
            left_toolbar_time = 0;

            return true;
        }

        // if this is the first time noticed, start the timer and keep checking
        if (left_toolbar_time == 0) {
            left_toolbar_time = time_t ();

            return true;
        }

        // see if enough time has elapsed
        int64 now = time_t ();
        assert (now >= left_toolbar_time);

        if (now - left_toolbar_time < TOOLBAR_DISMISSAL_SEC)
            return true;

        hide_toolbar ();

        return false;
    }

    private void hide_toolbar () {
        revealer.reveal_child = false;
        left_toolbar_time = 0;
    }
}
