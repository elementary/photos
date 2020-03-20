/*
* Copyright (c) 2011-2013 Yorba Foundation
*               2013 Jens Bav
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

using Spit;

private class CirclesEffectDescriptor : ShotwellTransitionDescriptor {
    public CirclesEffectDescriptor (GLib.File resource_directory) {
        base (resource_directory);
    }

    public override unowned string get_id () {
        return "io.elementary.photos.transitions.circles";
    }

    public override unowned string get_pluggable_name () {
        return _ ("Circles");
    }

    public override Transitions.Effect create (HostInterface host) {
        return new CirclesEffect ();
    }
}

private class CirclesEffect : Object, Transitions.Effect {
    private const int DESIRED_FPS = 25;
    private const int MIN_FPS = 15;
    private const double SPEED = 2.5;

    public CirclesEffect () {
    }

    public void get_fps (out int desired_fps, out int min_fps) {
        desired_fps = CirclesEffect.DESIRED_FPS;
        min_fps = CirclesEffect.MIN_FPS;
    }

    public void start (Transitions.Visuals visuals, Transitions.Motion motion) {
    }

    public bool needs_clear_background () {
        return true;
    }

    public void paint (Transitions.Visuals visuals, Transitions.Motion motion, Cairo.Context ctx,
                       int width, int height, int frame_number) {
        double alpha = motion.get_alpha (frame_number);
        int distance = 60, radius;
        int circle_count_x = width / (2 * distance);
        int circle_count_y = height / distance;
        double max_radius = SPEED * distance;

        if (visuals.from_pixbuf != null) {
            Gdk.cairo_set_source_pixbuf (ctx, visuals.from_pixbuf, visuals.from_pos.x,
                                         visuals.from_pos.y);
            ctx.paint_with_alpha (1 - alpha);
        }

        if (visuals.to_pixbuf != null) {
            Gdk.cairo_set_source_pixbuf (ctx, visuals.to_pixbuf, visuals.to_pos.x, visuals.to_pos.y);

            for (int y = 0; y <= circle_count_y; y++) {
                for (int x = 0; x <= circle_count_x; x++) {
                    radius = (int) (Math.fmax (0, Math.fmin (1, alpha - ((double) (x + y) / (double)
                                               ((circle_count_y + circle_count_x) * SPEED)))) * max_radius);
                    ctx.arc (2 * distance * x, 2 * distance * y, radius, 0, 2 * Math.PI);
                    ctx.fill ();
                }
            }

            ctx.clip ();
            ctx.paint_with_alpha (alpha);
        }
    }

    public void advance (Transitions.Visuals visuals, Transitions.Motion motion, int frame_number) {
    }

    public void cancel () {
    }
}
