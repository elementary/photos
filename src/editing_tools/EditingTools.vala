/*
* Copyright (c) 2011-2013 Yorba Foundation
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

public abstract class EditingTools.EditingTool : Object {
    public PhotoCanvas canvas = null;

    private EditingToolWindow tool_window = null;
    protected Cairo.Surface surface;
    public string name { get; construct; }

    [CCode (has_target = false)]
    public delegate EditingTool Factory ();

    public signal void activated ();

    public signal void deactivated ();

    public signal void applied (Command? command, Gdk.Pixbuf? new_pixbuf, Dimensions new_max_dim,
                                bool needs_improvement);

    public signal void cancelled ();

    public signal void aborted ();

    protected EditingTool (string name) {
        Object (
            name: name
        );
    }

    // base.activate () should always be called by an overriding member to ensure the base class
    // gets to set up and store the PhotoCanvas in the canvas member field.  More importantly,
    // the activated signal is called here, and should only be called once the tool is completely
    // initialized.
    public virtual void activate (PhotoCanvas canvas) {
        // multiple activates are not tolerated
        assert (this.canvas == null);
        assert (tool_window == null);

        this.canvas = canvas;

        tool_window = get_tool_window ();
        if (tool_window != null) {
            tool_window.key_press_event.connect (on_keypress);
        }

        activated ();
    }

    // Like activate (), this should always be called from an overriding subclass.
    public virtual void deactivate () {
        // multiple deactivates are tolerated
        if (canvas == null && tool_window == null) {
            return;
        }

        canvas = null;

        if (tool_window != null) {
            tool_window.key_press_event.disconnect (on_keypress);
            tool_window = null;
        }

        deactivated ();
    }

    public bool is_activated () {
        return canvas != null;
    }

    public virtual EditingToolWindow? get_tool_window () {
        return null;
    }

    // This allows the EditingTool to specify which pixbuf to display during the tool's
    // operation.  Returning null means the host should use the pixbuf associated with the current
    // Photo.  Note: This will be called before activate (), primarily to display the pixbuf before
    // the tool is on the screen, and before paint_full () is hooked in.  It also means the PhotoCanvas
    // will have this pixbuf rather than one from the Photo class.
    //
    // If returns non-null, should also fill max_dim with the maximum dimensions of the original
    // image, as the editing host may not always scale images up to fit the viewport.
    //
    // Note this this method doesn't need to be returning the "proper" pixbuf on-the-fly (i.e.
    // a pixbuf with unsaved tool edits in it).  That can be handled in the paint () virtual method.
    public virtual Gdk.Pixbuf? get_display_pixbuf (Scaling scaling, Photo photo,
            out Dimensions max_dim) throws Error {
        max_dim = Dimensions ();

        return null;
    }

    public virtual void on_left_click (int x, int y) {
    }

    public virtual void on_left_released (int x, int y) {
    }

    public virtual void on_motion (int x, int y, Gdk.ModifierType mask) {
    }

    public virtual bool on_leave_notify_event () {
        return false;
    }

    public virtual bool on_keypress (Gdk.EventKey event) {
        // check for an escape/abort first
        if (Gdk.keyval_name (event.keyval) == "Escape") {
            notify_cancel ();

            return true;
        }

        return false;
    }

    public virtual void paint (Cairo.Context ctx) {
    }

    // Helper function that fires the cancelled signal.  (Can be connected to other signals.)
    protected void notify_cancel () {
        cancelled ();
    }
}
