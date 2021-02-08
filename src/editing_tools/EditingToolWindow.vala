/*
* Copyright 2011-2013 Yorba Foundation
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

/* This file is the master unit file for the EditingTools unit.  It should be edited to include
 * whatever code is deemed necessary.
 *
 * The init () and terminate () methods are mandatory.
 *
 * If the unit needs to be configured prior to initialization, add the proper parameters to
 * the preconfigure () method, implement it, and ensure in init () that it's been called.
 */

public abstract class EditingTools.EditingToolWindow : Hdy.Window {
    private Gtk.Grid content_area;

    protected EditingToolWindow (Gtk.Window container) {
        Object (transient_for: container);
    }

    construct {
        content_area = new Gtk.Grid () {
            margin = 12
        };

        var window_handle = new Hdy.WindowHandle ();
        window_handle.add (content_area);

        add (window_handle);

        accept_focus = true;
        can_focus = true;
        deletable = false;
        focus_on_map = true;
        resizable = false;

        add_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.KEY_PRESS_MASK);

        // Needed to prevent the (spurious) 'This event was synthesised outside of GDK'
        // warnings after a keypress.
        Log.set_handler ("Gdk", LogLevelFlags.LEVEL_WARNING, suppress_warnings);
    }

    ~EditingToolWindow () {
        Log.set_handler ("Gdk", LogLevelFlags.LEVEL_WARNING, Log.default_handler);
    }

    protected Gtk.Grid get_content_area () {
        return content_area;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        if (base.key_press_event (event)) {
            return true;
        }
        return AppWindow.get_instance ().key_press_event (event);
    }
}
