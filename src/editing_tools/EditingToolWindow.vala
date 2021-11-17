/*
* Copyright 2021 elementary, Inc. <https://elementary.io>
*           2011-2013 Yorba Foundation
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

public abstract class EditingTools.EditingToolWindow : Hdy.Window {
    public Gtk.Grid content_area { get; private set; }

    protected EditingToolWindow (Gtk.Window container) {
        Object ( transient_for: container );
    }

    construct {
        content_area = new Gtk.Grid () {
            margin = 12
        };

        add (content_area);

        accept_focus = true;
        can_focus = true;
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

    public override bool key_press_event (Gdk.EventKey event) {
        if (base.key_press_event (event)) {
            return true;
        }
        return AppWindow.get_instance ().key_press_event (event);
    }

    public override bool button_press_event (Gdk.EventButton event) {
        // LMB only
        if (event.button != 1) {
            return (base.button_press_event != null) ? base.button_press_event (event) : true;
        }

        begin_move_drag ((int) event.button, (int) event.x_root, (int) event.y_root, event.time);

        return true;
    }
}
