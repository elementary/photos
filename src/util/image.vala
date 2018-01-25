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

Gdk.RGBA parse_color (string spec) {
    return fetch_color (spec);
}

Gdk.RGBA fetch_color (string spec) {
    Gdk.RGBA rgba = Gdk.RGBA ();
    if (!rgba.parse (spec))
        error ("Can't parse color %s", spec);

    return rgba;
}

void set_source_color_from_string (Cairo.Context ctx, string spec) {
    Gdk.RGBA rgba = fetch_color (spec);
    ctx.set_source_rgba (rgba.red, rgba.green, rgba.blue, rgba.alpha);
}

private const int MIN_SCALED_WIDTH = 10;
private const int MIN_SCALED_HEIGHT = 10;

Gdk.Pixbuf scale_pixbuf (Gdk.Pixbuf pixbuf, int scale, Gdk.InterpType interp, bool scale_up) {
    Dimensions original = Dimensions.for_pixbuf (pixbuf);
    Dimensions scaled = original.get_scaled (scale, scale_up);
    if ((original.width == scaled.width) && (original.height == scaled.height))
        return pixbuf;

    // use sane minimums ... scale_simple will hang if this is too low
    scaled = scaled.with_min (MIN_SCALED_WIDTH, MIN_SCALED_HEIGHT);

    return pixbuf.scale_simple (scaled.width, scaled.height, interp);
}

Gdk.Pixbuf resize_pixbuf (Gdk.Pixbuf pixbuf, Dimensions resized, Gdk.InterpType interp) {
    Dimensions original = Dimensions.for_pixbuf (pixbuf);
    if (original.width == resized.width && original.height == resized.height)
        return pixbuf;

    // use sane minimums ... scale_simple will hang if this is too low
    resized = resized.with_min (MIN_SCALED_WIDTH, MIN_SCALED_HEIGHT);

    return pixbuf.scale_simple (resized.width, resized.height, interp);
}

inline uchar shift_color_byte (int b, int shift) {
    return (uchar) (b + shift).clamp (0, 255);
}

public void shift_colors (Gdk.Pixbuf pixbuf, int red, int green, int blue, int alpha) {
    assert (red >= -255 && red <= 255);
    assert (green >= -255 && green <= 255);
    assert (blue >= -255 && blue <= 255);
    assert (alpha >= -255 && alpha <= 255);

    int width = pixbuf.get_width ();
    int height = pixbuf.get_height ();
    int rowstride = pixbuf.get_rowstride ();
    int channels = pixbuf.get_n_channels ();
    uchar *pixels = pixbuf.get_pixels ();

    assert (channels >= 3);
    assert (pixbuf.get_colorspace () == Gdk.Colorspace.RGB);
    assert (pixbuf.get_bits_per_sample () == 8);

    for (int y = 0; y < height; y++) {
        int y_offset = y * rowstride;

        for (int x = 0; x < width; x++) {
            int offset = y_offset + (x * channels);

            if (red != 0)
                pixels[offset] = shift_color_byte (pixels[offset], red);

            if (green != 0)
                pixels[offset + 1] = shift_color_byte (pixels[offset + 1], green);

            if (blue != 0)
                pixels[offset + 2] = shift_color_byte (pixels[offset + 2], blue);

            if (alpha != 0 && channels >= 4)
                pixels[offset + 3] = shift_color_byte (pixels[offset + 3], alpha);
        }
    }
}

public void dim_pixbuf (Gdk.Pixbuf pixbuf) {
    PixelTransformer transformer = new PixelTransformer ();
    SaturationTransformation sat = new SaturationTransformation (SaturationTransformation.MIN_PARAMETER);
    transformer.attach_transformation (sat);
    transformer.transform_pixbuf (pixbuf);
    shift_colors (pixbuf, 0, 0, 0, -100);
}

bool coord_in_rectangle (int x, int y, Gdk.Rectangle rect) {
    return (x >= rect.x && x < (rect.x + rect.width) && y >= rect.y && y <= (rect.y + rect.height));
}

public bool rectangles_equal (Gdk.Rectangle a, Gdk.Rectangle b) {
    return (a.x == b.x) && (a.y == b.y) && (a.width == b.width) && (a.height == b.height);
}

public string rectangle_to_string (Gdk.Rectangle rect) {
    return "%d,%d %dx%d".printf (rect.x, rect.y, rect.width, rect.height);
}

public Gdk.Rectangle clamp_rectangle (Gdk.Rectangle original, Dimensions max) {
    Gdk.Rectangle rect = Gdk.Rectangle ();
    rect.x = original.x.clamp (0, max.width);
    rect.y = original.y.clamp (0, max.height);
    rect.width = original.width.clamp (0, max.width);
    rect.height = original.height.clamp (0, max.height);

    return rect;
}

public Gdk.Point scale_point (Gdk.Point p, double factor) {
    Gdk.Point result = {0};
    result.x = (int) (factor * p.x + 0.5);
    result.y = (int) (factor * p.y + 0.5);

    return result;
}

public Gdk.Point add_points (Gdk.Point p1, Gdk.Point p2) {
    Gdk.Point result = {0};
    result.x = p1.x + p2.x;
    result.y = p1.y + p2.y;

    return result;
}

public Gdk.Point subtract_points (Gdk.Point p1, Gdk.Point p2) {
    Gdk.Point result = {0};
    result.x = p1.x - p2.x;
    result.y = p1.y - p2.y;

    return result;
}

// Converts XRGB/ARGB (Cairo)-formatted pixels to RGBA (GDK).
void fix_cairo_pixbuf (Gdk.Pixbuf pixbuf) {
    uchar *gdk_pixels = pixbuf.pixels;
    for (int j = 0 ; j < pixbuf.height; ++j) {
        uchar *p = gdk_pixels;
        uchar *end = p + 4 * pixbuf.width;

        while (p < end) {
            uchar tmp = p[0];
#if G_BYTE_ORDER == G_LITTLE_ENDIAN
            p[0] = p[2];
            p[2] = tmp;
#else
            p[0] = p[1];
            p[1] = p[2];
            p[2] = p[3];
            p[3] = tmp;
#endif
            p += 4;
        }

        gdk_pixels += pixbuf.rowstride;
    }
}

/**
 * Finds the size of the smallest axially-aligned rectangle that could contain
 * a rectangle src_width by src_height, rotated by angle.
 *
 * @param src_width The width of the incoming rectangle.
 * @param src_height The height of the incoming rectangle.
 * @param angle The amount to rotate by, given in degrees.
 * @param dest_width The width of the computed rectangle.
 * @param dest_height The height of the computed rectangle.
 */
void compute_arb_rotated_size (double src_width, double src_height, double angle,
                               out double dest_width, out double dest_height) {

    angle = Math.fabs (degrees_to_radians (angle));
    assert (angle <= Math.PI_2);
    dest_width = src_width * Math.cos (angle) + src_height * Math.sin (angle);
    dest_height = src_height * Math.cos (angle) + src_width * Math.sin (angle);
}

/**
 * Rotates a pixbuf to an arbitrary angle, given in degrees, and returns the rotated pixbuf.
 *
 * @param source_pixbuf The source image that needs to be angled.
 * @param angle The angle the source image should be rotated by.
 */
Gdk.Pixbuf rotate_arb (Gdk.Pixbuf source_pixbuf, double angle) {
    // if the straightening angle has been reset
    // or was never set in the first place, nothing
    // needs to be done to the source image.
    if (angle == 0.0) {
        return source_pixbuf;
    }

    // Compute how much the corners of the source image will
    // move by to determine how big the dest pixbuf should be.

    double x_tmp, y_tmp;
    compute_arb_rotated_size (source_pixbuf.width, source_pixbuf.height, angle,
                              out x_tmp, out y_tmp);

    Gdk.Pixbuf dest_pixbuf = new Gdk.Pixbuf (
        Gdk.Colorspace.RGB, true, 8, (int) Math.round (x_tmp), (int) Math.round (y_tmp));

    Cairo.ImageSurface surface = new Cairo.ImageSurface.for_data (
        (uchar []) dest_pixbuf.pixels,
        source_pixbuf.has_alpha ? Cairo.Format.ARGB32 : Cairo.Format.RGB24,
        dest_pixbuf.width, dest_pixbuf.height, dest_pixbuf.rowstride);

    Cairo.Context context = new Cairo.Context (surface);

    context.set_source_rgb (0, 0, 0);
    context.rectangle (0, 0, dest_pixbuf.width, dest_pixbuf.height);
    context.fill ();

    context.translate (dest_pixbuf.width / 2, dest_pixbuf.height / 2);
    context.rotate (degrees_to_radians (angle));
    context.translate (- source_pixbuf.width / 2, - source_pixbuf.height / 2);

    Gdk.cairo_set_source_pixbuf (context, source_pixbuf, 0, 0);
    context.get_source ().set_filter (Cairo.Filter.BEST);
    context.paint ();

    // prepare the newly-drawn image for use by
    // the rest of the pipeline.
    fix_cairo_pixbuf (dest_pixbuf);

    return dest_pixbuf;
}

/**
 * Rotates a point around the upper left corner of an image to an arbitrary angle,
 * given in degrees, and returns the rotated point, translated such that it, along with its attendant
 * image, are in positive x, positive y.
 *
 * Note: May be subject to slight inaccuracy as Gdk points' coordinates may only be in whole pixels,
 * so the fractional component is lost.
 *
 * @param source_point The point to be rotated and scaled.
 * @param img_w The width of the source image (unrotated).
 * @param img_h The height of the source image (unrotated).
 * @param angle The angle the source image is to be rotated by to straighten it.
 */
Gdk.Point rotate_point_arb (Gdk.Point source_point, int img_w, int img_h, double angle,
                            bool invert = false) {
    // angle of 0 degrees or angle was never set?
    if (angle == 0.0) {
        // nothing needs to be done.
        return source_point;
    }

    double dest_width;
    double dest_height;
    compute_arb_rotated_size (img_w, img_h, angle, out dest_width, out dest_height);

    Cairo.Matrix matrix = Cairo.Matrix.identity ();
    matrix.translate (dest_width / 2, dest_height / 2);
    matrix.rotate (degrees_to_radians (angle));
    matrix.translate (- img_w / 2, - img_h / 2);
    if (invert)
        assert (matrix.invert () == Cairo.Status.SUCCESS);

    double dest_x = source_point.x;
    double dest_y = source_point.y;
    matrix.transform_point (ref dest_x, ref dest_y);

    return { (int) dest_x, (int) dest_y };
}

/**
 * <u>De</u>rotates a point around the upper left corner of an image from an arbitrary angle,
 * given in degrees, and returns the de-rotated point, taking into account any translation necessary
 * to make sure all of the rotated image stays in positive x, positive y.
 *
 * Note: May be subject to slight inaccuracy as Gdk points' coordinates may only be in whole pixels,
 * so the fractional component is lost.
 *
 * @param source_point The point to be de-rotated.
 * @param img_w The width of the source image (unrotated).
 * @param img_h The height of the source image (unrotated).
 * @param angle The angle the source image is to be rotated by to straighten it.
 */
Gdk.Point derotate_point_arb (Gdk.Point source_point, int img_w, int img_h, double angle) {
    return rotate_point_arb (source_point, img_w, img_h, angle, true);
}


// Force an axially-aligned box to be inside a rotated rectangle.
Box clamp_inside_rotated_image (Box src, int img_w, int img_h, double angle_deg,
                                bool preserve_geom) {

    Gdk.Point top_left = derotate_point_arb ({src.left, src.top}, img_w, img_h, angle_deg);
    Gdk.Point top_right = derotate_point_arb ({src.right, src.top}, img_w, img_h, angle_deg);
    Gdk.Point bottom_left = derotate_point_arb ({src.left, src.bottom}, img_w, img_h, angle_deg);
    Gdk.Point bottom_right = derotate_point_arb ({src.right, src.bottom}, img_w, img_h, angle_deg);

    double angle = degrees_to_radians (angle_deg);
    int top_offset = 0, bottom_offset = 0, left_offset = 0, right_offset = 0;

    int top = int.min (top_left.y, top_right.y);
    if (top < 0)
        top_offset = (int) ((0 - top) * Math.cos (angle));

    int bottom = int.max (bottom_left.y, bottom_right.y);
    if (bottom > img_h)
        bottom_offset = (int) ((img_h - bottom) * Math.cos (angle));

    int left = int.min (top_left.x, bottom_left.x);
    if (left < 0)
        left_offset = (int) ((0 - left) * Math.cos (angle));

    int right = int.max (top_right.x, bottom_right.x);
    if (right > img_w)
        right_offset = (int) ((img_w - right) * Math.cos (angle));

    return preserve_geom ? src.get_offset (left_offset + right_offset, top_offset + bottom_offset)
           : Box (src.left + left_offset, src.top + top_offset,
                  src.right + right_offset, src.bottom + bottom_offset);
}

