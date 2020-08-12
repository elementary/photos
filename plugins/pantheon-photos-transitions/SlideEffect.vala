/*
* Copyright (c) 2011-2013 Yorba Foundation
*               2010 Maxim Kartashev
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

private class SlideEffectDescriptor : ShotwellTransitionDescriptor {
    public SlideEffectDescriptor (GLib.File resource_directory) {
        base (resource_directory);
    }

    public override unowned string get_id () {
        return "io.elementary.photos.transitions.slide";
    }

    public override unowned string get_pluggable_name () {
        return _ ("Slide");
    }

    public override Transitions.Effect create (Spit.HostInterface host) {
        return new SlideEffect ();
    }
}

private class SlideEffect : Object, Transitions.Effect {
    private const int DESIRED_FPS = 25;
    private const int MIN_FPS = 15;

    public SlideEffect () {
    }

    public void get_fps (out int desired_fps, out int min_fps) {
        desired_fps = SlideEffect.DESIRED_FPS;
        min_fps = SlideEffect.MIN_FPS;
    }

    public void start (Transitions.Visuals visuals, Transitions.Motion motion) {
    }

    public bool needs_clear_background () {
        return true;
    }

    public void paint (Transitions.Visuals visuals, Transitions.Motion motion, Cairo.Context ctx,
                       int width, int height, int frame_number) {
        double alpha = motion.get_alpha (frame_number);

        if (visuals.from_pixbuf != null) {
            int from_target_x = (motion.direction == Transitions.Direction.FORWARD)
                                ? -visuals.from_pixbuf.width : width;
            int from_current_x = (int) (visuals.from_pos.x * (1 - alpha) + from_target_x * alpha);
            Gdk.cairo_set_source_pixbuf (ctx, visuals.from_pixbuf, from_current_x, visuals.from_pos.y);
            ctx.paint ();
        }

        if (visuals.to_pixbuf != null) {
            int to_target_x = (width - visuals.to_pixbuf.width) / 2;
            int from_x = (motion.direction == Transitions.Direction.FORWARD)
                         ? width : -visuals.to_pixbuf.width;
            int to_current_x = (int) (from_x * (1 - alpha) + to_target_x * alpha);
            Gdk.cairo_set_source_pixbuf (ctx, visuals.to_pixbuf, to_current_x, visuals.to_pos.y);
            ctx.paint ();
        }
    }

    public void advance (Transitions.Visuals visuals, Transitions.Motion motion, int frame_number) {
    }

    public void cancel () {
    }
}
