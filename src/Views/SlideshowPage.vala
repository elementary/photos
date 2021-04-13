/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary LLC. (https://elementary.io)
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

class SlideshowPage : SinglePhotoPage {
    private const int READAHEAD_COUNT = 5;
    private const int CHECK_ADVANCE_MSEC = 250;

    private Photo current;
    private Gtk.Button play_pause_button;
    private PixbufCache cache = null;
    private Timer timer = new Timer ();
    private bool playing = true;
    private bool exiting = false;
    private string[] transitions;
    private uint32 cookie = 0;
    private GLib.Settings slideshow_settings;

    public signal void hide_toolbar ();

    public SourceCollection sources { get; construct; }
    public ViewCollection controller { get; construct; }

    public SlideshowPage (SourceCollection sources, ViewCollection controller, Photo start) {
        Object (
            controller: controller,
            page_name: _("Slideshow"),
            scale_up_to_viewport: true,
            sources: sources
        );

        current = start;
    }

    construct {
        Gee.Collection<string> pluggables = TransitionEffectsManager.get_instance ().get_effect_ids ();
        Gee.ArrayList<string> a = new Gee.ArrayList<string> ();
        a.add_all (pluggables);
        a.remove (NullTransitionDescriptor.EFFECT_ID);
        a.remove (RandomEffectDescriptor.EFFECT_ID);
        transitions = a.to_array ();

        slideshow_settings = new GLib.Settings (GSettingsConfigurationEngine.SLIDESHOW_PREFS_SCHEMA_NAME);
        slideshow_settings.changed.connect (() => update_transition_effect ());

        update_transition_effect ();

        var previous_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR), _("Back"));
        previous_button.tooltip_text = _("Go to the previous photo");
        previous_button.clicked.connect (on_previous_photo);

        play_pause_button = new Gtk.Button.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        play_pause_button.tooltip_text = _("Pause the slideshow");
        play_pause_button.clicked.connect (on_play_pause);

        var next_button = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        next_button.tooltip_text = _("Go to the next photo");
        next_button.clicked.connect (on_next_photo);

        var effect_selector = new TransitionEffectSelector ();

        var titles_toggle = new Gtk.ToggleButton ();
        titles_toggle.image = new Gtk.Image.from_icon_name ("preferences-desktop-font-symbolic",
                                                            Gtk.IconSize.LARGE_TOOLBAR);
        titles_toggle.tooltip_text = _("Show Photo Titles");
        titles_toggle.margin_start = 6;
        titles_toggle.active = slideshow_settings.get_boolean ("show-title");
        titles_toggle.valign = Gtk.Align.CENTER;
        titles_toggle.toggled.connect (() => {
            slideshow_settings.set_boolean ("show-title", titles_toggle.active);
        });

        var dropdown_sizegroup = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);
        dropdown_sizegroup.add_widget (effect_selector);
        dropdown_sizegroup.add_widget (titles_toggle);

        var slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0.5, 15.0, 0.5);
        slider.draw_value = false;
        slider.inverted = true;
        slider.tooltip_text = _("Transition Speed");
        slider.width_request = 150;
        slider.add_mark (0.5, Gtk.PositionType.BOTTOM, _("Faster"));
        slider.add_mark (15.0, Gtk.PositionType.BOTTOM, _("Slower"));
        slider.set_value (slideshow_settings.get_double ("delay"));
        slider.value_changed.connect (() => {
            slideshow_settings.set_double ("delay", slider.get_value ());
        });

        var slider_wrapper = new Gtk.ToolItem ();
        slider_wrapper.margin_start = 6;
        slider_wrapper.add (slider);

        var toolbar = base.get_toolbar ();
        toolbar.pack_start (previous_button);
        toolbar.pack_start (play_pause_button);
        toolbar.pack_start (next_button);
        toolbar.add (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        toolbar.pack_start (effect_selector);
        toolbar.pack_start (titles_toggle);
        toolbar.pack_start (slider_wrapper);
        toolbar.add (new Gtk.Separator (Gtk.Orientation.VERTICAL));
    }

    public override void switched_to () {
        base.switched_to ();

        // create a cache for the size of this display
        cache = new PixbufCache (sources, PixbufCache.PhotoType.BASELINE, get_canvas_scaling (),
                                 READAHEAD_COUNT);

        Gdk.Pixbuf pixbuf;
        if (get_next_photo (current, Direction.FORWARD, out current, out pixbuf))
            set_pixbuf (pixbuf, current.get_dimensions (), Direction.FORWARD);

        // start the auto-advance timer
        Timeout.add (CHECK_ADVANCE_MSEC, auto_advance);
        timer.start ();

        inhibit_screensaver ();
    }

    public override void switching_from () {
        base.switching_from ();
        uninhibit_screensaver ();
        exiting = true;
    }

    private bool get_next_photo (Photo start, Direction direction, out Photo next,
                                 out Gdk.Pixbuf next_pixbuf) {
        next = start;

        for (;;) {
            try {
                // Fails if a photo source file is missing.
                next_pixbuf = cache.fetch (next);
            } catch (Error err) {
                warning ("Unable to fetch pixbuf for %s: %s", next.to_string (), err.message);

                // Look for the next good photo
                DataView view = controller.get_view_for_source (next);
                view = (direction == Direction.FORWARD)
                       ? controller.get_next (view)
                       : controller.get_previous (view);
                next = (Photo) view.source;

                // An entire slideshow set might be missing, so check for a loop.
                if ((next == start && next != current) || next == current) {
                    AppWindow.error_message (_("All photo source files are missing."), null, get_container ());
                    AppWindow.get_instance ().end_fullscreen ();

                    next = null;
                    next_pixbuf = null;

                    return false;
                }

                continue;
            }

            // prefetch this photo's extended neighbors: the next photo highest priority, the prior
            // one normal, and the extended neighbors lowest, to recognize immediate needs
            DataSource forward, back;
            controller.get_immediate_neighbors (next, out forward, out back, Photo.TYPENAME);
            cache.prefetch ((Photo) forward, BackgroundJob.JobPriority.HIGHEST);
            cache.prefetch ((Photo) back, BackgroundJob.JobPriority.NORMAL);

            Gee.Set<DataSource> neighbors = controller.get_extended_neighbors (next, Photo.TYPENAME);
            neighbors.remove (forward);
            neighbors.remove (back);

            cache.prefetch_many ((Gee.Collection<Photo>) neighbors, BackgroundJob.JobPriority.LOWEST);

            return true;
        }
    }

    private void on_play_pause () {
        if (playing) {
            play_pause_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic",
                                                                    Gtk.IconSize.LARGE_TOOLBAR);
            play_pause_button.tooltip_text = _("Continue the slideshow");
        } else {
            play_pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic",
                                                                    Gtk.IconSize.LARGE_TOOLBAR);
            play_pause_button.tooltip_text = _("Pause the slideshow");
        }

        playing = !playing;

        // reset the timer
        timer.start ();
    }

    protected override void on_previous_photo () {
        DataView view = controller.get_view_for_source (current);

        Photo? prev_photo = null;
        DataView? start_view = controller.get_previous (view);
        DataView? prev_view = start_view;

        while (prev_view != null) {
            if (prev_view.source is Photo) {
                prev_photo = (Photo) prev_view.source;
                break;
            }

            prev_view = controller.get_previous (prev_view);

            if (prev_view == start_view) {
                warning ("on_previous( ): can't advance to previous photo: collection has only videos");
                return;
            }
        }

        advance (prev_photo, Direction.BACKWARD);
    }

    protected override void on_next_photo () {
        DataView view = controller.get_view_for_source (current);

        Photo? next_photo = null;
        DataView? start_view = controller.get_next (view);
        DataView? next_view = start_view;

        while (next_view != null) {
            if (next_view.source is Photo) {
                next_photo = (Photo) next_view.source;
                break;
            }

            next_view = controller.get_next (next_view);

            if (next_view == start_view) {
                warning ("on_next( ): can't advance to next photo: collection has only videos");
                return;
            }
        }

        if (slideshow_settings.get_string ("transition-effect-id") == RandomEffectDescriptor.EFFECT_ID) {
            random_transition_effect ();
        }

        advance (next_photo, Direction.FORWARD);
    }

    private void advance (Photo photo, Direction direction) {
        current = photo;

        // set pixbuf
        Gdk.Pixbuf next_pixbuf;
        if (get_next_photo (current, direction, out current, out next_pixbuf))
            set_pixbuf (next_pixbuf, current.get_dimensions (), direction);

        // reset the advance timer
        timer.start ();
    }

    private bool auto_advance () {
        if (exiting)
            return false;

        if (!playing)
            return true;

        if (timer.elapsed () < slideshow_settings.get_double ("delay"))
            return true;

        on_next_photo ();

        return true;
    }

    public override bool button_press_event (Gdk.EventButton event) {
        if (event.type == Gdk.EventType.DOUBLE_BUTTON_PRESS && event.button == Gdk.BUTTON_PRIMARY) {
            hide_toolbar ();
            AppWindow.get_instance ().end_fullscreen ();
            switching_from ();
        }
        return false;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        bool handled = true;
        switch (Gdk.keyval_name (event.keyval)) {
        case "space":
            on_play_pause ();
            break;

        default:
            handled = false;
            break;
        }

        if (handled)
            return true;

        return (base.key_press_event != null) ? base.key_press_event (event) : true;
    }

    private void update_transition_effect () {
        string effect_id = slideshow_settings.get_string ("transition-effect-id");
        double effect_delay = calculate_effect_delay ();

        set_transition (effect_id, (int) (effect_delay * 1000.0));
    }

    private void random_transition_effect () {
        double effect_delay = calculate_effect_delay ();
        string effect_id = TransitionEffectsManager.NULL_EFFECT_ID;
        if (0 < transitions.length) {
            int random = Random.int_range (0, transitions.length);
            effect_id = transitions[random];
        }
        set_transition (effect_id, (int) (effect_delay * 1000.0));
    }

    private double calculate_effect_delay () {
        var photo_delay = slideshow_settings.get_double ("delay");
        var effect_delay = photo_delay / 7.0;

        if (effect_delay < 0.1) {
            effect_delay = 0.1;
        }

        if (effect_delay > 1.0) {
            effect_delay = 1.0;
        }

        return effect_delay;
    }

    // Paint the title of the photo
    private void paint_title (Cairo.Context ctx, Dimensions ctx_dim) {
        string? title = current.get_title ();

        // If the photo doesn't have a title, don't paint anything
        if (title == null || title == "")
            return;

        Pango.Layout layout = create_pango_layout (title);
        Pango.AttrList list = new Pango.AttrList ();
        Pango.Attribute size = Pango.attr_scale_new (3);
        list.insert (size.copy ());
        layout.set_attributes (list);
        layout.set_width ((int) ((ctx_dim.width * 0.9) * Pango.SCALE));

        // Find the right position
        int title_width, title_height;
        layout.get_pixel_size (out title_width, out title_height);
        double x = ctx_dim.width * 0.2;
        double y = ctx_dim.height * 0.90;

        // Move the title up if it is too high
        if (y + title_height >= ctx_dim.height * 0.95)
            y = ctx_dim.height * 0.95 - title_height;
        // Move to the left if the title is too long
        if (x + title_width >= ctx_dim.width * 0.95)
            x = ctx_dim.width / 2 - title_width / 2;

        set_source_color_from_string (ctx, "#fff");
        ctx.move_to (x, y);
        Pango.cairo_show_layout (ctx, layout);
        Pango.cairo_layout_path (ctx, layout);
        ctx.set_line_width (1.5);
        set_source_color_from_string (ctx, "#000");
        ctx.stroke ();
    }

    public override void paint (Cairo.Context ctx, Dimensions ctx_dim) {
        base.paint (ctx, ctx_dim);

        if (slideshow_settings.get_boolean ("show-title") && !is_transition_in_progress ())
            paint_title (ctx, ctx_dim);
    }

    private void inhibit_screensaver () {
        if (cookie != 0) {
            return;
        }

        cookie = ((Photos.Application) GLib.Application.get_default ()).app_inhibit (
            Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND,
            _("Slideshow")
        );
    }

    private void uninhibit_screensaver () {
        if (cookie == 0) {
            return;
        }

        ((Photos.Application) GLib.Application.get_default ()).uninhibit (cookie);
        cookie = 0;
    }
}
