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

public class FullscreenWindow : PageWindow {
    public const int TOOLBAR_INVOCATION_MSEC = 250;
    public const int TOOLBAR_DISMISSAL_SEC = 2;
    public const int TOOLBAR_CHECK_DISMISSAL_MSEC = 500;

    private Gtk.Window toolbar_window;
    private Gtk.ToggleToolButton pin_button;
    private bool is_toolbar_shown = false;
    private bool waiting_for_invoke = false;
    private time_t left_toolbar_time = 0;
    private bool switched_to = false;
    private bool is_toolbar_dismissal_enabled = true;

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

        pin_button = new Gtk.ToggleToolButton ();
        pin_button.icon_name = "pin-toolbar";
        pin_button.tooltip_text = _("Pin the toolbar open");
        pin_button.clicked.connect (update_toolbar_dismissal);

        var img = new Gtk.Image.from_icon_name ("window-restore-symbolic", Gtk.IconSize.LARGE_TOOLBAR);

        var close_button = new Gtk.ToolButton (img, null);
        close_button.tooltip_text = _("Leave fullscreen");
        close_button.clicked.connect (on_close);

        var toolbar = page.get_toolbar ();

        if (page is SlideshowPage) {
            // slideshow page doesn't own toolbar to hide it, subscribe to signal instead
            ((SlideshowPage) page).hide_toolbar.connect (hide_toolbar);
        } else {
            // only non-slideshow pages should have pin button
            toolbar.insert (pin_button, -1);
        }

        page.set_cursor_hide_time (TOOLBAR_DISMISSAL_SEC * 1000);
        page.start_cursor_hiding ();

        toolbar.insert (close_button, -1);

        // set up toolbar along bottom of screen
        toolbar_window = new Gtk.Window (Gtk.WindowType.POPUP);
        toolbar_window.set_screen (get_screen ());
        toolbar_window.set_border_width (0);
        toolbar_window.add (toolbar);

        toolbar_window.realize.connect (on_toolbar_realized);

        add (page);

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
    }

    public void disable_toolbar_dismissal () {
        is_toolbar_dismissal_enabled = false;
    }

    public void update_toolbar_dismissal () {
        is_toolbar_dismissal_enabled = !pin_button.get_active ();
    }

    private Gdk.Rectangle get_monitor_geometry () {
        Gdk.Rectangle monitor;

        get_screen ().get_monitor_geometry (
            get_screen ().get_monitor_at_window (AppWindow.get_instance ().get_window ()), out monitor);

        return monitor;
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

        // Make sure this event gets propagated to the underlying window...
        AppWindow.get_instance ().key_press_event (event);

        // ...then let the base class take over
        return (base.key_press_event != null) ? base.key_press_event (event) : false;
    }

    private void on_close () {
        hide_toolbar ();
        toolbar_window = null;

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
        if (!is_toolbar_shown) {
            // if pointer is in toolbar height range without the mouse down (i.e. in the middle of
            // an edit operation) and it stays there the necessary amount of time, invoke the
            // toolbar
            if (!waiting_for_invoke && is_pointer_in_toolbar ()) {
                Timeout.add (TOOLBAR_INVOCATION_MSEC, on_check_toolbar_invocation);
                waiting_for_invoke = true;
            }
        }

        return (base.motion_notify_event != null) ? base.motion_notify_event (event) : false;
    }

    private bool is_pointer_in_toolbar () {
        Gdk.DeviceManager? devmgr = get_display ().get_device_manager ();
        if (devmgr == null) {
            debug ("No device manager for display");

            return false;
        }

        int py;
        devmgr.get_client_pointer ().get_position (null, null, out py);

        int wy;
        toolbar_window.get_window ().get_geometry (null, out wy, null, null);

        return (py >= wy);
    }

    private bool on_check_toolbar_invocation () {
        waiting_for_invoke = false;

        if (is_toolbar_shown)
            return false;

        if (!is_pointer_in_toolbar ())
            return false;

        invoke_toolbar ();

        return false;
    }

    private void on_toolbar_realized () {
        Gtk.Requisition req;
        toolbar_window.get_preferred_size (null, out req);

        // place the toolbar in the center of the monitor along the bottom edge
        Gdk.Rectangle monitor = get_monitor_geometry ();
        int tx = monitor.x + (monitor.width - req.width) / 2;
        if (tx < 0)
            tx = 0;

        int ty = monitor.y + monitor.height - req.height;
        if (ty < 0)
            ty = 0;

        toolbar_window.move (tx, ty);
        toolbar_window.set_opacity (Resources.TRANSIENT_WINDOW_OPACITY);
    }

    private void invoke_toolbar () {
        toolbar_window.show_all ();

        is_toolbar_shown = true;

        Timeout.add (TOOLBAR_CHECK_DISMISSAL_MSEC, on_check_toolbar_dismissal);
    }

    private bool on_check_toolbar_dismissal () {
        if (!is_toolbar_shown)
            return false;

        if (toolbar_window == null)
            return false;

        // if dismissal is disabled, keep open but keep checking
        if ((!is_toolbar_dismissal_enabled))
            return true;

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
        time_t now = time_t ();
        assert (now >= left_toolbar_time);

        if (now - left_toolbar_time < TOOLBAR_DISMISSAL_SEC)
            return true;

        hide_toolbar ();

        return false;
    }

    private void hide_toolbar () {
        toolbar_window.hide ();
        is_toolbar_shown = false;
    }
}
