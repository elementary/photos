/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io),
                2009-2013 Yorba Foundation
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

// PageWindow is a Gtk.Window with essential functions for hosting a Page.  There may be more than
// one PageWindow in the system, and closing one does not imply exiting the application.
//
// PageWindow offers support for hosting a single Page; multiple Pages must be handled by the
// subclass.  A subclass should set current_page to the user-visible Page for it to receive
// various notifications.  It is the responsibility of the subclass to notify Pages when they're
// switched to and from, and other aspects of the Page interface.
public abstract class PageWindow : Gtk.ApplicationWindow {
    protected Gtk.UIManager ui;

    private Page current_page = null;
    private int busy_counter = 0;

    protected virtual void switched_pages (Page? old_page, Page? new_page) {
    }

    construct {
        // the current page needs to know when modifier keys are pressed
        add_events (
            Gdk.EventMask.KEY_PRESS_MASK |
            Gdk.EventMask.KEY_RELEASE_MASK |
            Gdk.EventMask.STRUCTURE_MASK
        );

        ui = new Gtk.UIManager ();
    }

    public Page? get_current_page () {
        return current_page;
    }

    public virtual void set_current_page (Page page) {
        if (current_page != null)
            current_page.clear_container ();

        Page? old_page = current_page;
        current_page = page;
        current_page.set_container (this);

        switched_pages (old_page, page);
    }

    public virtual void clear_current_page () {
        if (current_page != null)
            current_page.clear_container ();

        Page? old_page = current_page;
        current_page = null;

        switched_pages (old_page, null);
    }

    public override bool key_press_event (Gdk.EventKey event) {
        if (get_focus () is Gtk.Entry && get_focus ().key_press_event (event)) {
            return true;
        }

        if (current_page != null && current_page.notify_app_key_pressed (event)) {
            return true;
        }

        return (base.key_press_event != null) ? base.key_press_event (event) : false;
    }

    public override bool key_release_event (Gdk.EventKey event) {
        if (get_focus () is Gtk.Entry && get_focus ().key_release_event (event))
            return true;

        if (current_page != null && current_page.notify_app_key_released (event))
            return true;

        return (base.key_release_event != null) ? base.key_release_event (event) : false;
    }

    public override bool focus_in_event (Gdk.EventFocus event) {
        if (current_page != null && current_page.notify_app_focus_in (event))
            return true;

        return (base.focus_in_event != null) ? base.focus_in_event (event) : false;
    }

    public override bool focus_out_event (Gdk.EventFocus event) {
        if (current_page != null && current_page.notify_app_focus_out (event))
            return true;

        return (base.focus_out_event != null) ? base.focus_out_event (event) : false;
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (current_page != null) {
            if (current_page.notify_configure_event (event))
                return true;
        }

        return (base.configure_event != null) ? base.configure_event (event) : false;
    }

    public void set_busy_cursor () {
        if (busy_counter++ > 0)
            return;

        get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
        spin_event_loop ();
    }

    public void set_normal_cursor () {
        if (busy_counter <= 0) {
            busy_counter = 0;
            return;
        } else if (--busy_counter > 0) {
            return;
        }

        get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.LEFT_PTR));
        spin_event_loop ();
    }
}
