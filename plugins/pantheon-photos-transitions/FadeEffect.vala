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

private class FadeEffectDescriptor : ShotwellTransitionDescriptor {
    public FadeEffectDescriptor (GLib.File resource_directory) {
        base (resource_directory);
    }

    public override unowned string get_id () {
        return "io.elementary.photos.transitions.fade";
    }

    public override unowned string get_pluggable_name () {
        return _ ("Fade");
    }

    public override Transitions.Effect create (Spit.HostInterface host) {
        return new FadeEffect ();
    }
}

private class FadeEffect : Object, Transitions.Effect {
    private const int DESIRED_FPS = 30;
    private const int MIN_FPS = 20;

    public FadeEffect () {
    }

    public void get_fps (out int desired_fps, out int min_fps) {
        desired_fps = FadeEffect.DESIRED_FPS;
        min_fps = FadeEffect.MIN_FPS;
    }

    public void start (Transitions.Visuals visuals, Transitions.Motion motion) {
    }

    public bool needs_clear_background () {
        return true;
    }

    public void paint (Transitions.Visuals visuals, Transitions.Motion motion, Cairo.Context ctx,
                       int width, int height, int frame_number) {
        double alpha = motion.get_alpha (frame_number);

        // blend the two pixbufs using an alpha of the appropriate level depending on how far
        // the cycle has progressed
        if (visuals.from_pixbuf != null) {
            Gdk.cairo_set_source_pixbuf (ctx, visuals.from_pixbuf, visuals.from_pos.x, visuals.from_pos.y);
            ctx.paint_with_alpha (1.0 - alpha);
        }

        if (visuals.to_pixbuf != null) {
            Gdk.cairo_set_source_pixbuf (ctx, visuals.to_pixbuf, visuals.to_pos.x, visuals.to_pos.y);
            ctx.paint_with_alpha (alpha);
        }
    }

    public void advance (Transitions.Visuals visuals, Transitions.Motion motion, int frame_number) {
    }

    public void cancel () {
    }
}

