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

private class BlindsEffectDescriptor : ShotwellTransitionDescriptor {
    public BlindsEffectDescriptor (GLib.File resource_directory) {
        base (resource_directory);
    }

    public override unowned string get_id () {
        return "io.elementary.photos.transitions.blinds";
    }

    public override unowned string get_pluggable_name () {
        return _ ("Blinds");
    }

    public override Transitions.Effect create (HostInterface host) {
        return new BlindsEffect ();
    }
}

private class BlindsEffect : Object, Transitions.Effect {
    private const int DESIRED_FPS = 30;
    private const int MIN_FPS = 15;

    private const int BLIND_WIDTH = 50;
    private int current_blind_width;

    private Cairo.ImageSurface[] to_blinds;
    private int blind_count;

    public BlindsEffect () {
    }

    public void get_fps (out int desired_fps, out int min_fps) {
        desired_fps = BlindsEffect.DESIRED_FPS;
        min_fps = BlindsEffect.MIN_FPS;
    }

    public bool needs_clear_background () {
        return true;
    }

    public void start (Transitions.Visuals visuals, Transitions.Motion motion) {
        if (visuals.from_pixbuf != null) {
            blind_count = visuals.to_pixbuf.width / BLIND_WIDTH;
            current_blind_width =
                (int) Math.ceil ((double) visuals.to_pixbuf.width / (double) blind_count);

            to_blinds = new Cairo.ImageSurface[blind_count];

            for (int i = 0; i < blind_count; ++i) {
                to_blinds[i] = new Cairo.ImageSurface (Cairo.Format.RGB24, current_blind_width,
                                                       visuals.to_pixbuf.height);
                Cairo.Context ctx = new Cairo.Context (to_blinds[i]);
                Gdk.cairo_set_source_pixbuf (ctx, visuals.to_pixbuf, -i * current_blind_width, 0);
                ctx.paint ();
            }
        }
    }

    public void paint (Transitions.Visuals visuals, Transitions.Motion motion, Cairo.Context ctx,
                       int width, int height, int frame_number) {
        double alpha = motion.get_alpha (frame_number);
        int y = visuals.to_pos.y;
        int x = visuals.to_pos.x;

        if (visuals.from_pixbuf != null) {
            Gdk.cairo_set_source_pixbuf (ctx, visuals.from_pixbuf, visuals.from_pos.x,
                                         visuals.from_pos.y);
            ctx.paint_with_alpha (1 - alpha * 2);
        }

        for (int i = 0; i < blind_count; ++i) {
            ctx.set_source_surface (to_blinds[i], x + i * current_blind_width, y);
            ctx.rectangle (x + i * current_blind_width, y, current_blind_width * (alpha + 0.5),
                           visuals.to_pixbuf.height);
            ctx.fill ();
        }

        ctx.clip ();
        ctx.paint ();
    }

    public void advance (Transitions.Visuals visuals, Transitions.Motion motion, int frame_number) {
    }

    public void cancel () {
    }
}
