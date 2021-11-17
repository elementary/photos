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

// The PhotoCanvas is an interface object between an EditingTool and its host.  It provides objects
// and primitives for an EditingTool to obtain information about the image, to draw on the host's
// canvas, and to be signalled when the canvas and its pixbuf changes (is resized).
public abstract class EditingTools.PhotoCanvas : Object {
    public signal void new_surface (Cairo.Context ctx, Dimensions dim);
    public signal void resized_scaled_pixbuf (Dimensions old_dim, Gdk.Pixbuf scaled, Gdk.Rectangle scaled_position);

    public Cairo.Context default_ctx { get; set construct; }
    public Dimensions surface_dim { get; set construct; }
    public Gdk.Pixbuf scaled_pixbuf { get; set construct; }
    public Gdk.Rectangle scaled_position { get; set construct; }
    public Gdk.Window drawing_window { get; set construct; }
    public Gtk.Window container { get; set construct; }
    public Photo photo { get; set construct; }

    private Cairo.Surface scaled { get; set; }

    protected PhotoCanvas (Gtk.Window container, Gdk.Window drawing_window, Photo photo,
                           Cairo.Context default_ctx, Dimensions surface_dim,
                           Gdk.Pixbuf scaled_pixbuf,
                           Gdk.Rectangle scaled_position) {
        Object (
            container: container,
            drawing_window: drawing_window,
            photo: photo,
            default_ctx: default_ctx,
            surface_dim: surface_dim,
            scaled_position: scaled_position,
            scaled_pixbuf: scaled_pixbuf
        );
    }

    construct {
        scaled = pixbuf_to_surface (default_ctx, scaled_pixbuf, scaled_position);
    }

    public Gdk.Rectangle unscaled_to_raw_rect (Gdk.Rectangle rectangle) {
        return photo.unscaled_to_raw_rect (rectangle);
    }

    private Gdk.Point active_to_unscaled_point (Gdk.Point active_point) {
        Dimensions unscaled_dims = photo.get_dimensions ();

        double scale_factor_x = ((double) unscaled_dims.width) /
                                ((double) scaled_position.width);
        double scale_factor_y = ((double) unscaled_dims.height) /
                                ((double) scaled_position.height);

        Gdk.Point result = {0};
        result.x = (int) (((double) active_point.x) * scale_factor_x + 0.5);
        result.y = (int) (((double) active_point.y) * scale_factor_y + 0.5);

        return result;
    }

    public Gdk.Rectangle active_to_unscaled_rect (Gdk.Rectangle active_rect) {
        Gdk.Point upper_left = {0};
        Gdk.Point lower_right = {0};
        upper_left.x = active_rect.x;
        upper_left.y = active_rect.y;
        lower_right.x = upper_left.x + active_rect.width;
        lower_right.y = upper_left.y + active_rect.height;

        upper_left = active_to_unscaled_point (upper_left);
        lower_right = active_to_unscaled_point (lower_right);

        Gdk.Rectangle unscaled_rect = Gdk.Rectangle ();
        unscaled_rect.x = upper_left.x;
        unscaled_rect.y = upper_left.y;
        unscaled_rect.width = lower_right.x - upper_left.x;
        unscaled_rect.height = lower_right.y - upper_left.y;

        return unscaled_rect;
    }

    public Gdk.Point user_to_active_point (Gdk.Point user_point) {
        Gdk.Point result = {0};
        result.x = user_point.x - scaled_position.x;
        result.y = user_point.y - scaled_position.y;

        return result;
    }

    public Gdk.Rectangle user_to_active_rect (Gdk.Rectangle user_rect) {
        Gdk.Point upper_left = {0};
        Gdk.Point lower_right = {0};
        upper_left.x = user_rect.x;
        upper_left.y = user_rect.y;
        lower_right.x = upper_left.x + user_rect.width;
        lower_right.y = upper_left.y + user_rect.height;

        upper_left = user_to_active_point (upper_left);
        lower_right = user_to_active_point (lower_right);

        Gdk.Rectangle active_rect = Gdk.Rectangle ();
        active_rect.x = upper_left.x;
        active_rect.y = upper_left.y;
        active_rect.width = lower_right.x - upper_left.x;
        active_rect.height = lower_right.y - upper_left.y;

        return active_rect;
    }

    public Scaling get_scaling () {
        return Scaling.for_viewport (surface_dim, false);
    }

    public void set_surface (Cairo.Context default_ctx, Dimensions surface_dim) {
        this.default_ctx = default_ctx;
        this.surface_dim = surface_dim;

        new_surface (default_ctx, surface_dim);
    }

    public void resized_pixbuf (Dimensions old_dim, Gdk.Pixbuf scaled, Gdk.Rectangle scaled_position) {
        this.scaled = pixbuf_to_surface (default_ctx, scaled, scaled_position);
        this.scaled_pixbuf = scaled;
        this.scaled_position = scaled_position;

        resized_scaled_pixbuf (old_dim, scaled, scaled_position);
    }

    public abstract void repaint ();

    // Because the editing tool should not have any need to draw on the gutters outside the photo,
    // and it's a pain to constantly calculate where it's laid out on the drawable, these convenience
    // methods automatically adjust for its position.
    //
    // If these methods are not used, all painting to the drawable should be offet by
    // scaled_position.x and scaled_position.y
    public void paint_pixbuf (Gdk.Pixbuf pixbuf) {
        default_ctx.save ();

        // paint background
        get_style_context ().render_background (default_ctx, 0, 0, surface_dim.width, surface_dim.height);

        // paint the actual image
        Gdk.cairo_set_source_pixbuf (default_ctx, pixbuf, scaled_position.x, scaled_position.y);
        default_ctx.rectangle (scaled_position.x, scaled_position.y,
                               pixbuf.get_width (), pixbuf.get_height ());
        default_ctx.fill ();
        default_ctx.restore ();
    }

    // Paint a surface on top of the photo
    public void paint_surface (Cairo.Surface surface, bool over) {
        default_ctx.save ();
        if (over == false) {
            default_ctx.set_operator (Cairo.Operator.SOURCE);
        } else {
            default_ctx.set_operator (Cairo.Operator.OVER);
        }

        default_ctx.set_source_surface (scaled, scaled_position.x, scaled_position.y);
        default_ctx.paint ();
        default_ctx.set_source_surface (surface, scaled_position.x, scaled_position.y);
        default_ctx.paint ();
        default_ctx.restore ();
    }

    public void paint_surface_area (Cairo.Surface surface, Box source_area, bool over) {
        default_ctx.save ();
        if (over == false) {
            default_ctx.set_operator (Cairo.Operator.SOURCE);
        } else {
            default_ctx.set_operator (Cairo.Operator.OVER);
        }

        default_ctx.set_source_surface (scaled, scaled_position.x, scaled_position.y);
        default_ctx.rectangle (scaled_position.x + source_area.left,
                               scaled_position.y + source_area.top,
                               source_area.get_width (), source_area.get_height ());
        default_ctx.fill ();

        default_ctx.set_source_surface (surface, scaled_position.x, scaled_position.y);
        default_ctx.rectangle (scaled_position.x + source_area.left,
                               scaled_position.y + source_area.top,
                               source_area.get_width (), source_area.get_height ());
        default_ctx.fill ();
        default_ctx.restore ();
    }

    public void draw_box (Cairo.Context ctx, Box box) {
        Gdk.Rectangle rect = box.get_rectangle ();
        rect.x += scaled_position.x;
        rect.y += scaled_position.y;

        ctx.rectangle (rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1);
        ctx.stroke ();
    }

    public void draw_text (Cairo.Context ctx, string text, int x, int y, bool use_scaled_pos = true) {
        if (use_scaled_pos) {
            x += scaled_position.x;
            y += scaled_position.y;
        }
        Cairo.TextExtents extents;
        ctx.text_extents (text, out extents);
        x -= (int) extents.width / 2;

        set_source_color_from_string (ctx, Resources.ONIMAGE_FONT_BACKGROUND);

        int pane_border = 5; // border around edge of pane in pixels
        ctx.rectangle (x - pane_border, y - pane_border - extents.height,
                       extents.width + 2 * pane_border,
                       extents.height + 2 * pane_border);
        ctx.fill ();

        ctx.move_to (x, y);
        set_source_color_from_string (ctx, Resources.ONIMAGE_FONT_COLOR);
        ctx.show_text (text);
    }

    /**
     * Draw a horizontal line into the specified Cairo context at the specified position, taking
     * into account the scaled position of the image unless directed otherwise.
     *
     * @param ctx The drawing context of the surface we're drawing to.
     * @param x The horizontal position to place the line at.
     * @param y The vertical position to place the line at.
     * @param width The length of the line.
     * @param use_scaled_pos Whether to use absolute window positioning or take into account the
     *      position of the scaled image.
     */
    public void draw_horizontal_line (Cairo.Context ctx, int x, int y, int width, bool use_scaled_pos = true) {
        if (use_scaled_pos) {
            x += scaled_position.x;
            y += scaled_position.y;
        }

        ctx.move_to (x + 0.5, y + 0.5);
        ctx.line_to (x + width - 1, y + 0.5);
        ctx.stroke ();
    }

    /**
     * Draw a vertical line into the specified Cairo context at the specified position, taking
     * into account the scaled position of the image unless directed otherwise.
     *
     * @param ctx The drawing context of the surface we're drawing to.
     * @param x The horizontal position to place the line at.
     * @param y The vertical position to place the line at.
     * @param width The length of the line.
     * @param use_scaled_pos Whether to use absolute window positioning or take into account the
     *      position of the scaled image.
     */
    public void draw_vertical_line (Cairo.Context ctx, int x, int y, int height, bool use_scaled_pos = true) {
        if (use_scaled_pos) {
            x += scaled_position.x;
            y += scaled_position.y;
        }

        ctx.move_to (x + 0.5, y + 0.5);
        ctx.line_to (x + 0.5, y + height - 1);
        ctx.stroke ();
    }

    public void draw_circle (Cairo.Context ctx, int active_center_x, int active_center_y,
                             int radius) {
        int center_x = active_center_x + scaled_position.x;
        int center_y = active_center_y + scaled_position.y;

        int scale_factor = container.scale_factor;
        ctx.arc (center_x * scale_factor, center_y * scale_factor, radius * scale_factor, 0, 2 * GLib.Math.PI);
        ctx.stroke ();
    }

    public void invalidate_area (Box area) {
        Gdk.Rectangle rect = area.get_rectangle ();
        rect.x += scaled_position.x;
        rect.y += scaled_position.y;

        drawing_window.invalidate_rect (rect, false);
    }

    private Cairo.Surface pixbuf_to_surface (Cairo.Context default_ctx, Gdk.Pixbuf pixbuf,
            Gdk.Rectangle pos) {
        Cairo.Surface surface = new Cairo.Surface.similar (default_ctx.get_target (),
                Cairo.Content.COLOR_ALPHA, pos.width, pos.height);
        Cairo.Context ctx = new Cairo.Context (surface);
        Gdk.cairo_set_source_pixbuf (ctx, pixbuf, 0, 0);
        ctx.paint ();
        return surface;
    }

    /**
     * Returns the style context associated to this.
     *
     * @return a StyleContext. This memory is owned by this and must not be freed.
     */
    public abstract unowned Gtk.StyleContext get_style_context ();
}
