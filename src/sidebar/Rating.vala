/***
    Copyright (C) 2012 Lucas Baudin <xapantu@gmail.com>
    Copyright (C) 2012-2014 Victor Martinez <victoreduardm@gmail.com>

    This program or library is free software; you can redistribute it
    and/or modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 3 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General
    Public License along with this library; if not, write to the
    Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301 USA.
***/

/**
 * A star rating widget.
 *
 *
 */
public class PhotoRatingWidget : Gtk.EventBox {
    /**
     * Emitted when a new rating is selected.
     *
     * @param new_rating The new rating.
     *
     */
    public signal void rating_changed (int new_rating);

    /**
     * Whether to use symbolic star icons.
     *
     *
     */
    public bool symbolic {
        get {
            return renderer.symbolic;
        } set {
            renderer.symbolic = value;
        }
    }

    /**
     * Pixel size of star icons.
     *
     *
     */
    public int icon_size {
        get {
            return renderer.icon_size;
        } set {
            renderer.icon_size = value;
        }
    }

    /**
     * Total number of stars. It also represents the maximum rating possible.
     * That is, possible ratings are between 0 and //n_stars//.
     *
     * Allowed values: >= 0. Default: 5.
     *
     */
    public int n_stars {
        get {
            return renderer.n_stars;
        } set {
            renderer.n_stars = value;
        }
    }

    /**
     * Spacing inserted between star icons.
     *
     *
     */
    public int star_spacing {
        get {
            return renderer.star_spacing;
        } set {
            renderer.star_spacing = value;
        }
    }


    private int _rating = 0;

    /**
     * Current selected rating.
     *
     *
     */
    public int rating {
        get {
            return _rating;
        } set {
            _rating = value.clamp (0, n_stars);
            update_rating (_rating);
        }
    }

    internal double rating_offset {
        get {
            return renderer.rating_offset;
        } set {
            renderer.rating_offset = value;
        }
    }

    internal int item_width {
        get {
            return renderer.item_width;
        }
    }

    /**
     * Whether the widget will be centered with respect to its allocation.
     *
     *
     */
    public bool centered {
        get;
        set;
        default = false;
    }

    private PhotoRatingRenderer renderer;
    private int hover_rating = 0;

    /**
     * Creates a new Rating widget.
     *
     * @param centered Whether the widget should be centered with respect to its allocation.
     * @param size Pixel size of star icons.
     * @param symbolic Whether to use symbolic icons.
     *
     */
    public PhotoRatingWidget (bool centered, int size, bool symbolic = false) {
        this.centered = centered;
        this.renderer = new PhotoRatingRenderer (size, symbolic, get_style_context ());
        visible_window = false;

        add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                    | Gdk.EventMask.BUTTON_RELEASE_MASK
                    | Gdk.EventMask.POINTER_MOTION_MASK
                    | Gdk.EventMask.LEAVE_NOTIFY_MASK);

        state_flags_changed.connect_after (() => {
            renderer.render ();
        });

        renderer.render.connect_after (() => {
            compute_size ();
            queue_draw ();
        });
    }

    private void compute_size () {
        this.set_size_request (renderer.width, renderer.height);
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        int x_offset = 0;

        if (centered) {
            Gtk.Allocation al;
            get_allocation (out al);
            x_offset = (al.width - width_request) / 2;
        }

        hover_rating = renderer.get_new_rating (event.x - x_offset);
        update_rating (hover_rating);
        return true;
    }

    public override bool button_press_event (Gdk.EventButton event) {
        rating = hover_rating;
        rating_changed (rating);
        return true;
    }

    public override bool leave_notify_event (Gdk.EventCrossing ev) {
        update_rating (rating);
        return true;
    }

    internal void update_rating (int fake_rating) {
        renderer.rating = fake_rating;
        queue_draw ();
    }

    public override bool draw (Cairo.Context context) {
        Gtk.Allocation al;
        get_allocation (out al);
       // try {
            Gdk.cairo_set_source_pixbuf (context,
                                         renderer.canvas,
                                         centered ? (al.width - width_request) / 2 : 0,
                                         centered ? (al.height - height_request) / 2 : 0);
      //  } catch {

       // }
        context.paint ();
        return false;
    }
}

/**
 * A menu item that contains a rating widget.
 *
 *
 */
public class PhotoRatingMenuItem : Gtk.MenuItem {
    /**
     * Current displayed rating. Note that you should read this value
     * after the {@link Gtk.MenuItem.activate} signal is emitted.
     *
     *
     */
    public int rating_value {
        get {
            return rating.rating;
        } set {
            rating.rating = value;
        }
    }

    private PhotoRatingWidget rating;

    /**
     * Creates a new rating menu item.
     *
     *
     */
    public PhotoRatingMenuItem (int icon_size = 16) {
        rating = new PhotoRatingWidget (false, icon_size, false);
        add (rating);

        // Workaround. Move the offset one star to the left for menuitems.
        rating.rating_offset = - (double) rating.item_width - (double) rating.star_spacing;

        this.state_flags_changed.connect (() => {
            // Suppress SELECTED and PRELIGHT states, since these are usually obtrusive
            var selected_flags = Gtk.StateFlags.SELECTED | Gtk.StateFlags.PRELIGHT;
            if ((get_state_flags() & selected_flags) != 0)
                unset_state_flags (selected_flags);
        });
    }

    public override bool motion_notify_event (Gdk.EventMotion ev) {
        rating.motion_notify_event (ev);
        rating.queue_draw ();
        return true;
    }

    public override bool button_press_event (Gdk.EventButton ev) {
        rating.button_press_event (ev);
        activate ();
        return true;
    }

    public override bool leave_notify_event (Gdk.EventCrossing ev) {
        rating.update_rating (rating_value);
        return true;
    }
}

/**
 * This class makes setting the rating from a cell possible. Unlike the other widgets,
 * it only allows doing so by clicking over a star.
 *
 * When the rating changes by activating (i.e. clicking) the cell renderer, it doesn't re-draw itself
 * automatically and/or apply the new rating right away, since there could be client code wanting
 * to check the new value. Instead, it passes the responsability off to the rating_changed signal handler.
 * That signal handler ''must'' take care of setting the new rating on the proper cell, and only then
 * the new value will take effect.
 *
 *
 */
public class PhotoCellRendererRating : Gtk.CellRendererPixbuf {
    /**
     * New rating was set. It is only emmited when the rating changes by activating the renderer.
     *
     * @param new_rating new selected rating.
     * @param widget Widget that captured the event (e.g. a {@link Gtk.TreeView}).
     * @param path string representation of the tree path for the cell where the event occurred.
     *
     */
    public signal void rating_changed (int new_rating, Gtk.Widget widget, string path);

    private PhotoRatingRenderer renderer;

    /**
     * Creates a new rating cell renderer.
     *
     * @param icon_size Pixel size of the star icons
     *
     */
    public PhotoCellRendererRating (int icon_size = 16) {
        this.xalign = 0.0f;
        this.mode = Gtk.CellRendererMode.ACTIVATABLE;

        renderer = new PhotoRatingRenderer (icon_size, true, null);

        // We'll only redraw from render() for performance reasons
        renderer.delayed_render_mode = true;

        // Set rating to 1 star and render to init the 'width' property
        rating = 1;
        renderer.render ();
        update_pixbuf ();
    }

    /**
     * Spacing inserted between star icons.
     *
     *
     */
    public int star_spacing {
        get {
            return renderer.star_spacing;
        } set {
            renderer.star_spacing = value;
        }
    }

    private uint _rating = 0;


    /**
     * Current displayed rating.
     *
     *
     */
    public uint rating {
        get {
            return _rating;
        } set {
            _rating = value;
            renderer.rating = _rating;
        }
    }

    /**
     * Total number of stars. It also represents the maximum rating possible.
     * That is, possible ratings are between 0 and //n_stars//.
     *
     * Allowed values: >= 0. Default: 5.
     *
     */
    public int n_stars {
        get {
            return renderer.n_stars;
        } set {
            renderer.n_stars = value;
        }
    }

    private void update_pixbuf () {
        this.pixbuf = renderer.canvas;
        this.set_fixed_size (this.pixbuf.width, this.pixbuf.height);
    }

    public override void render (Cairo.Context ctx, Gtk.Widget widget,
                                 Gdk.Rectangle background_area, Gdk.Rectangle cell_area,
                                 Gtk.CellRendererState flags) {
        var style_context = widget.get_style_context ();
        var state = style_context.get_state ();
        int old_n_stars = n_stars;

        // Only draw stars of 0-rating if the cursor is over the cell
        if (_rating == 0 && (state & (Gtk.StateFlags.SELECTED | Gtk.StateFlags.PRELIGHT)) == 0)
            return;

        // Only show the filled stars if the row is neither selected nor mouseovered
        if (0 < _rating && (state & (Gtk.StateFlags.SELECTED | Gtk.StateFlags.PRELIGHT)) == 0)
            n_stars = (int) rating;

        renderer.style_context = style_context;
        renderer.render ();
        update_pixbuf ();
        base.render (ctx, widget, background_area, cell_area, flags);
        n_stars = old_n_stars;
    }

    public override bool activate (Gdk.Event event, Gtk.Widget widget, string path,
                                   Gdk.Rectangle background_area, Gdk.Rectangle cell_area,
                                   Gtk.CellRendererState flags) {
        int old_rating = (int) rating;
        int new_rating = renderer.get_new_rating (event.button.x - cell_area.x);

        // If the user clicks again over the same star, decrease the rating (i.e. "unset" the star)
        if (new_rating == old_rating && new_rating > 0)
            new_rating--;

        // emit signal
        rating_changed (new_rating, widget, path);

        return true;
    }
}

public class PhotoRatingRenderer : Object {
    /**
     * Whether to delay the rendering of the rating until the next call
     * to render() after a property change. This is recommended in cases
     * where there's an extensive amount of drawing and the renderer's
     * properties are constantly changing; for example, when used by
     * a Gtk.CellRenderer in a Gtk.TreeView; in such case, it's desirable
     * to have the renderer re-draw its pixbuf only on the next call to
     * Gtk.CellRenderer.render.
     *
     * Default value: false.
     *
     */
    public bool delayed_render_mode {
        get;
        set;
        default = false;
    }

    /**
     * The pixbuf containing the stars. Should not be modified.
     *
     * To listen for changes on this property, connect to the render() signal.
     * If you need to modify this pixbuf, create a copy first.
     *
     *
     */
    public Gdk.Pixbuf canvas {
        get;
        private set;
    }

    /**
     * Rating value to render.
     *
     * Default value: 0.
     *
     */
    public uint rating {
        get;
        set;
        default = 0;
    }

    /**
     * Maximum possible rating. This represents the total number of stars
     * that will be rendered.
     *
     * Default value: 5.
     *
     */
    public int n_stars {
        get;
        set;
        default = 5;
    }

    /**
     * The number of pixels inserted between star icons.
     *
     * Default value: 3.
     *
     */
    public int star_spacing {
        get;
        set;
        default = 3;
    }

    /**
     * Total width of rating pixbuf (in pixels).
     *
     *
     */
    public int width {
        get;
        private set;
        default = 0;
    }

    /**
     * Total height of rating pixbuf (in pixels).
     *
     *
     */
    public int height {
        get;
        private set;
        default = 0;
    }

    /**
     * The width of each rating star (in pixels).
     *
     *
     */
    public int item_width {
        get;
        private set;
        default = 0;
    }

    /**
     * The height of each rating star (in pixels).
     *
     *
     */
    public int item_height {
        get;
        private set;
        default = 0;
    }

    /**
     * Pixel size of rating icons.
     *
     *
     */
    public int icon_size {
        get;
        set;
        default = 16;
    }

    /**
     * Whether to use symbolic star icons.
     *
     *
     */
    public bool symbolic {
        get;
        set;
        default = false;
    }

    /**
     * Whether to append a //plus// icon at the end of the star rating.
     *
     * Default value: false.
     *
     */
    public bool add_plus_sign {
        get;
        set;
        default = false;
    }

    /**
     * Background color.
     *
     * Default value: transparent.
     *
     */
    public Gdk.RGBA background_color {
        get {
            return bg_color;
        } set {
            bg_color = value;

            // Convert RGBA from 0-1.0 value range to 0-255 (8-bit representation) by
            // simply multiplying values. Then we move the bits to their correct positions,
            // since we'll use a 32 bit integer to represent four 8-bit portions.
            // Please note the loss of precision.
            uint r = ((uint) (value.red * 255)) << 24;
            uint g = ((uint) (value.green * 255)) << 16;
            uint b = ((uint) (value.blue * 255)) << 8;
            uint a = ((uint) (value.alpha * 255));

            // bit positions do not overlap, so this is safe.
            pixel_color_rgba = r | g | b | a;
        }
    }

    /**
     * Style context to use as reference for drawing.
     *
     *
     */
    public Gtk.StyleContext? style_context {
        get {
            return current_context;
        } set {
            if (value != current_context) {
                if (current_context != null)
                    current_context.changed.disconnect (on_style_changed);

                current_context = value;

                if (current_context != null)
                    current_context.changed.connect (on_style_changed);

                on_style_changed ();
            }
        }
    }

    internal double rating_offset {
        get;
        set;
        default = 0;
    }

    // Icon cache. It stores the pixbufs rendered for every state until the
    // style information changes.
    private Gee.HashMap<int, Gdk.Pixbuf> starred_pixbufs;
    private Gee.HashMap<int, Gdk.Pixbuf> not_starred_pixbufs;
    private Gee.HashMap<int, Gdk.Pixbuf> plus_sign_pixbufs;
    private Gdk.RGBA bg_color;
    private uint pixel_color_rgba;
    private Gtk.StyleContext? current_context;
    // Whether a property has changed or not. Used to avoid unnecessary work in render()
    private bool property_changed = true;

    /**
     * Creates a rating renderer.
     *
     * @param icon_size pixel size of star icons
     * @param symbolic Whether to use symbolic icons
     * @param context style context to use as reference for rendering, or //null//.
     *
     */
    public PhotoRatingRenderer (int icon_size, bool symbolic, Gtk.StyleContext? context) {
        starred_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf> ();
        not_starred_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf> ();
        plus_sign_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf> ();

        this.symbolic = symbolic;
        this.icon_size = icon_size;
        this.style_context = context;
        this.background_color = { 0, 0, 0, 0 };

        // Initial rendering. This is important; it will connect a handler
        // to the notify() signal, and will also init some properties, such
        // as item_width, item_height, width, height, etc.
        assert (property_changed);
        render ();
        assert (!property_changed);
    }

    public virtual signal void render () {
        if (!property_changed)
            return;

        disable_property_notify ();

        Gtk.StateFlags state = Gtk.StateFlags.NORMAL;

        // Only consider actual state if the stars should be symbolic.
        // Otherwise we consider the single state (NORMAL) set above.
        if (symbolic && style_context != null)
            state = style_context.get_state ();

        var starred_pix = starred_pixbufs.get (state);
        var not_starred_pix = not_starred_pixbufs.get (state);
        var plus_sign_pix = plus_sign_pixbufs.get (state);

        // if no cached star pixbufs were found, render them.
        var factory = Granite.Services.IconFactory.get_default ();

        if (starred_pix == null) {
            string starred = symbolic ? "starred-symbolic" : "starred";
            starred_pix = factory.load_symbolic_icon (style_context, starred, icon_size);
            starred_pixbufs.set (state, starred_pix);
        }

        if (not_starred_pix == null) {
            string not_starred = symbolic ? "non-starred-symbolic" : "non-starred";
            not_starred_pix = factory.load_symbolic_icon (style_context, not_starred, icon_size);
            not_starred_pixbufs.set (state, not_starred_pix);
        }

        if (add_plus_sign && plus_sign_pix == null)
            plus_sign_pix = factory.load_symbolic_icon (style_context, "list-add-symbolic", icon_size);

        if (starred_pix != null && not_starred_pix != null) {
            // Compute size
            item_width  = int.max (starred_pix.width, not_starred_pix.width);
            item_height = int.max (starred_pix.height, not_starred_pix.height);

            int new_width = (item_width + star_spacing) * n_stars - star_spacing;
            int new_height = item_height;

            if (add_plus_sign) {
                new_width += star_spacing + plus_sign_pix.width;
                new_height = int.max (new_height, plus_sign_pix.height);
            }

            // Generate canvas pixbuf
            if (canvas == null || new_width != width || new_height != height) {
                width = new_width;
                height = new_height;
                canvas = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, width, height);
            }

            if (canvas != null) {
                var star_canvas = canvas.copy ();
                star_canvas.fill ((uint) 0xffffff00);

                // Render
                for (int i = 0; i <= n_stars; i++) {
                    Gdk.Pixbuf to_copy = null;

                    if (i == n_stars) {
                        if (!add_plus_sign)
                            break;
                        to_copy = plus_sign_pix;
                    } else if (i < rating) {
                        to_copy = starred_pix;
                    } else {
                        to_copy = not_starred_pix;
                    }

                    assert (to_copy != null);

                    int dest_x = i * (item_width + (i > 0 ? star_spacing : 0)), dest_y = 0;
                    to_copy.copy_area (0, 0, item_width, item_height, star_canvas, dest_x, dest_y);
                }

                canvas.fill (pixel_color_rgba);
                star_canvas.composite (canvas, 0, 0, canvas.width, canvas.height,
                                       0, 0, 1, 1, Gdk.InterpType.BILINEAR, 255);
            } else {
                warning ("NULL rating canvas");
            }
        }

        // No more work to do until the next property change
        property_changed = false;

        enable_property_notify ();
    }

    private inline void disable_property_notify () {
        notify.disconnect (on_property_changed);
    }

    private inline void enable_property_notify () {
        notify.connect (on_property_changed);
    }

    /*
     * Returns a new rating value between 0 and n_stars, based on the cursor position
     * relative to the left side of the widget (x = 0).
     *
     * LEGEND:
     * X : A STAR
     * - : SPACE
     *
     * |   x_offset   | | spacing | | spacing | | spacing | | spacing  ...  | remaining space...
     * <-------------> X --------- X --------- X --------- X --------- ... X ------------->
     * ... 0 stars    |   1 star  |  2 stars  |  3 stars  |   4 stars  ...| n_stars stars...
     *
     * The first row in the graphic above represents the values involved:
     * - x_offset : the value added in front of the first star.
     * - spacing  : space inserted between stars (star_spacing).
     * - n_stars  : total number of stars. It also represents the maximum rating.
     *
     * As you can see, you can modify the placement of the invisible value separators ("|")
     * by changing the value of x_offset. For instance, if you wanted the next star to be activated
     * when the cursor is at least halfway towards it, just modify x_offset. It should be similar
     * for other cases as well. 'rating_offset' uses exactly that mechanism to apply its value.
     */
    internal int get_new_rating (double x) {
        int x_offset = 0;

        x_offset -= (int) rating_offset;

        int cursor_x_pos = (int) x;
        int new_rating = 0;

        for (int i = 0; i < n_stars; i++) {
            if (cursor_x_pos > x_offset + i * (item_width + star_spacing))
                new_rating ++;
        }

        return new_rating;
    }

    private void on_style_changed () {
        // Invalidate old cached pixbufs
        starred_pixbufs.clear ();
        not_starred_pixbufs.clear ();
        plus_sign_pixbufs.clear ();
    }

    private void on_property_changed () {
        property_changed = true;

        if (!delayed_render_mode)
            render ();
    }
}


