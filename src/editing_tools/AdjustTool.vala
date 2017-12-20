/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2016 elementary LLC.
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
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
*/

public class EditingTools.AdjustTool : EditingTool {
    private const uint SLIDER_DELAY_MSEC = 100;

    private class AdjustToolWindow : EditingToolWindow {
        public Gtk.Scale exposure_slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                ExposureTransformation.MIN_PARAMETER, ExposureTransformation.MAX_PARAMETER,
                1.0);
        public Gtk.Scale saturation_slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                SaturationTransformation.MIN_PARAMETER, SaturationTransformation.MAX_PARAMETER,
                1.0);
        public Gtk.Scale tint_slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                TintTransformation.MIN_PARAMETER, TintTransformation.MAX_PARAMETER, 1.0);
        public Gtk.Scale temperature_slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                TemperatureTransformation.MIN_PARAMETER, TemperatureTransformation.MAX_PARAMETER,
                1.0);

        public Gtk.Scale shadows_slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                ShadowDetailTransformation.MIN_PARAMETER, ShadowDetailTransformation.MAX_PARAMETER,
                1.0);

        public Gtk.Scale highlights_slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                HighlightDetailTransformation.MIN_PARAMETER, HighlightDetailTransformation.MAX_PARAMETER,
                1.0);

        public Gtk.Button ok_button = new Gtk.Button.with_mnemonic (_ ("_Apply"));
        public Gtk.Button reset_button = new Gtk.Button.with_mnemonic (_ ("_Reset"));
        public Gtk.Button cancel_button = new Gtk.Button.with_mnemonic (_ ("_Cancel"));
        public RGBHistogramManipulator histogram_manipulator = new RGBHistogramManipulator ();

        public AdjustToolWindow (Gtk.Window container) {
            base (container);

            Gtk.Grid slider_organizer = new Gtk.Grid ();
            slider_organizer.set_column_homogeneous (false);
            slider_organizer.set_row_spacing (12);
            slider_organizer.set_column_spacing (12);
            slider_organizer.set_margin_bottom (12);

            Gtk.Label exposure_label = new Gtk.Label.with_mnemonic (_ ("Exposure:"));
            exposure_label.set_halign (Gtk.Align.END);
            slider_organizer.attach (exposure_label, 0, 0, 1, 1);
            slider_organizer.attach (exposure_slider, 1, 0, 1, 1);
            exposure_slider.set_draw_value (false);
            exposure_slider.set_hexpand (true);

            Gtk.Label saturation_label = new Gtk.Label.with_mnemonic (_ ("Saturation:"));
            saturation_label.set_halign (Gtk.Align.END);
            slider_organizer.attach (saturation_label, 0, 1, 1, 1);
            slider_organizer.attach (saturation_slider, 1, 1, 1, 1);
            saturation_slider.set_draw_value (false);

            Gtk.Label tint_label = new Gtk.Label.with_mnemonic (_ ("Tint:"));
            tint_label.set_halign (Gtk.Align.END);
            slider_organizer.attach (tint_label, 0, 2, 1, 1);
            slider_organizer.attach (tint_slider, 1, 2, 1, 1);
            tint_slider.set_draw_value (false);

            Gtk.Label temperature_label = new Gtk.Label.with_mnemonic (_ ("Temperature:"));
            temperature_label.set_halign (Gtk.Align.END);
            slider_organizer.attach (temperature_label, 0, 3, 1, 1);
            slider_organizer.attach (temperature_slider, 1, 3, 1, 1);
            temperature_slider.set_draw_value (false);

            Gtk.Label shadows_label = new Gtk.Label.with_mnemonic (_ ("Shadows:"));
            shadows_label.set_halign (Gtk.Align.END);
            slider_organizer.attach (shadows_label, 0, 4, 1, 1);
            slider_organizer.attach (shadows_slider, 1, 4, 1, 1);
            shadows_slider.set_draw_value (false);

            Gtk.Label highlights_label = new Gtk.Label.with_mnemonic (_ ("Highlights:"));
            highlights_label.set_halign (Gtk.Align.END);
            slider_organizer.attach (highlights_label, 0, 5, 1, 1);
            slider_organizer.attach (highlights_slider, 1, 5, 1, 1);
            highlights_slider.set_draw_value (false);

            Gtk.Box button_layouter = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            button_layouter.set_homogeneous (true);
            button_layouter.pack_start (cancel_button, true, true, 1);
            button_layouter.pack_start (reset_button, true, true, 1);
            button_layouter.pack_start (ok_button, true, true, 1);

            Gtk.Box pane_layouter = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            pane_layouter.margin = 12;
            pane_layouter.add (histogram_manipulator);
            pane_layouter.add (slider_organizer);
            pane_layouter.add (button_layouter);
            pane_layouter.set_child_packing (histogram_manipulator, true, true, 0, Gtk.PackType.START);

            add (pane_layouter);
        }
    }

    private abstract class AdjustToolCommand : Command {
        protected weak AdjustTool owner;

        public AdjustToolCommand (AdjustTool owner, string name, string explanation) {
            base (name, explanation);

            this.owner = owner;
            owner.deactivated.connect (on_owner_deactivated);
        }

        ~AdjustToolCommand () {
            if (owner != null)
                owner.deactivated.disconnect (on_owner_deactivated);
        }

        private void on_owner_deactivated () {
            // This reset call is by design. See notes on ticket #1946 if this is undesirable or if
            // you are planning to change it.
            AppWindow.get_command_manager ().reset ();
        }
    }

    private class AdjustResetCommand : AdjustToolCommand {
        private PixelTransformationBundle original;
        private PixelTransformationBundle reset;

        public AdjustResetCommand (AdjustTool owner, PixelTransformationBundle current) {
            base (owner, _ ("Reset Colors"), _ ("Reset all color adjustments to original"));

            original = current.copy ();
            reset = new PixelTransformationBundle ();
            reset.set_to_identity ();
        }

        public override void execute () {
            owner.set_adjustments (reset);
        }

        public override void undo () {
            owner.set_adjustments (original);
        }

        public override bool compress (Command command) {
            AdjustResetCommand reset_command = command as AdjustResetCommand;
            if (reset_command == null)
                return false;

            if (reset_command.owner != owner)
                return false;

            // multiple successive resets on the same photo as good as a single
            return true;
        }
    }

    private class SliderAdjustmentCommand : AdjustToolCommand {
        private PixelTransformationType transformation_type;
        private PixelTransformation new_transformation;
        private PixelTransformation old_transformation;

        public SliderAdjustmentCommand (AdjustTool owner, PixelTransformation old_transformation,
                                        PixelTransformation new_transformation, string name) {
            base (owner, name, name);

            this.old_transformation = old_transformation;
            this.new_transformation = new_transformation;
            transformation_type = old_transformation.get_transformation_type ();
            assert (new_transformation.get_transformation_type () == transformation_type);
        }

        public override void execute () {
            // don't update slider; it's been moved by the user
            owner.update_transformation (new_transformation);
            owner.canvas.repaint ();
        }

        public override void undo () {
            owner.update_transformation (old_transformation);

            owner.unbind_window_handlers ();
            owner.update_slider (old_transformation);
            owner.bind_window_handlers ();

            owner.canvas.repaint ();
        }

        public override void redo () {
            owner.update_transformation (new_transformation);

            owner.unbind_window_handlers ();
            owner.update_slider (new_transformation);
            owner.bind_window_handlers ();

            owner.canvas.repaint ();
        }

        public override bool compress (Command command) {
            SliderAdjustmentCommand slider_adjustment = command as SliderAdjustmentCommand;
            if (slider_adjustment == null)
                return false;

            // same photo
            if (slider_adjustment.owner != owner)
                return false;

            // same adjustment
            if (slider_adjustment.transformation_type != transformation_type)
                return false;

            // execute the command
            slider_adjustment.execute ();

            // save it's transformation as ours
            new_transformation = slider_adjustment.new_transformation;

            return true;
        }
    }

    private class AdjustEnhanceCommand : AdjustToolCommand {
        private Photo photo;
        private PixelTransformationBundle original;
        private PixelTransformationBundle enhanced = null;

        public AdjustEnhanceCommand (AdjustTool owner, Photo photo) {
            base (owner, Resources.ENHANCE_LABEL, Resources.ENHANCE_TOOLTIP);

            this.photo = photo;
            original = photo.get_color_adjustments ();
        }

        public override void execute () {
            if (enhanced == null)
                enhanced = photo.get_enhance_transformations ();

            owner.set_adjustments (enhanced);
        }

        public override void undo () {
            owner.set_adjustments (original);
        }

        public override bool compress (Command command) {
            // can compress both normal enhance and one with the adjust tool running
            EnhanceSingleCommand enhance_single = command as EnhanceSingleCommand;
            if (enhance_single != null) {
                Photo photo = (Photo) enhance_single.get_source ();

                // multiple successive enhances are as good as a single, as long as it's on the
                // same photo
                return photo.equals (owner.canvas.get_photo ());
            }

            AdjustEnhanceCommand enhance_command = command as AdjustEnhanceCommand;
            if (enhance_command == null)
                return false;

            if (enhance_command.owner != owner)
                return false;

            // multiple successive as good as a single
            return true;
        }
    }

    private AdjustToolWindow adjust_tool_window = null;
    private bool suppress_effect_redraw = false;
    private Gdk.Pixbuf draw_to_pixbuf = null;
    private Gdk.Pixbuf histogram_pixbuf = null;
    private Gdk.Pixbuf virgin_histogram_pixbuf = null;
    private PixelTransformer transformer = null;
    private PixelTransformer histogram_transformer = null;
    private PixelTransformationBundle transformations = null;
    private float[] fp_pixel_cache = null;
    private bool disable_histogram_refresh = false;
    private OneShotScheduler? temperature_scheduler = null;
    private OneShotScheduler? tint_scheduler = null;
    private OneShotScheduler? saturation_scheduler = null;
    private OneShotScheduler? exposure_scheduler = null;
    private OneShotScheduler? shadows_scheduler = null;
    private OneShotScheduler? highlights_scheduler = null;

    private AdjustTool () {
        base ("AdjustTool");
    }

    public static AdjustTool factory () {
        return new AdjustTool ();
    }

    public static bool is_available (Photo photo, Scaling scaling) {
        return true;
    }

    public override void activate (PhotoCanvas canvas) {
        adjust_tool_window = new AdjustToolWindow (canvas.container);

        Photo photo = canvas.get_photo ();
        transformations = photo.get_color_adjustments ();
        transformer = transformations.generate_transformer ();

        // the histogram transformer uses all transformations but contrast expansion
        histogram_transformer = new PixelTransformer ();

        /* set up expansion */
        ExpansionTransformation expansion_trans = (ExpansionTransformation)
                transformations.get_transformation (PixelTransformationType.TONE_EXPANSION);
        adjust_tool_window.histogram_manipulator.set_left_nub_position (
            expansion_trans.get_black_point ());
        adjust_tool_window.histogram_manipulator.set_right_nub_position (
            expansion_trans.get_white_point ());

        /* set up shadows */
        ShadowDetailTransformation shadows_trans = (ShadowDetailTransformation)
                transformations.get_transformation (PixelTransformationType.SHADOWS);
        histogram_transformer.attach_transformation (shadows_trans);
        adjust_tool_window.shadows_slider.set_value (shadows_trans.get_parameter ());

        /* set up highlights */
        HighlightDetailTransformation highlights_trans = (HighlightDetailTransformation)
                transformations.get_transformation (PixelTransformationType.HIGHLIGHTS);
        histogram_transformer.attach_transformation (highlights_trans);
        adjust_tool_window.highlights_slider.set_value (highlights_trans.get_parameter ());

        /* set up temperature & tint */
        TemperatureTransformation temp_trans = (TemperatureTransformation)
                                               transformations.get_transformation (PixelTransformationType.TEMPERATURE);
        histogram_transformer.attach_transformation (temp_trans);
        adjust_tool_window.temperature_slider.set_value (temp_trans.get_parameter ());

        TintTransformation tint_trans = (TintTransformation)
                                        transformations.get_transformation (PixelTransformationType.TINT);
        histogram_transformer.attach_transformation (tint_trans);
        adjust_tool_window.tint_slider.set_value (tint_trans.get_parameter ());

        /* set up saturation */
        SaturationTransformation sat_trans = (SaturationTransformation)
                                             transformations.get_transformation (PixelTransformationType.SATURATION);
        histogram_transformer.attach_transformation (sat_trans);
        adjust_tool_window.saturation_slider.set_value (sat_trans.get_parameter ());

        /* set up exposure */
        ExposureTransformation exposure_trans = (ExposureTransformation)
                                                transformations.get_transformation (PixelTransformationType.EXPOSURE);
        histogram_transformer.attach_transformation (exposure_trans);
        adjust_tool_window.exposure_slider.set_value (exposure_trans.get_parameter ());

        bind_canvas_handlers (canvas);
        bind_window_handlers ();

        draw_to_pixbuf = canvas.get_scaled_pixbuf ().copy ();
        init_fp_pixel_cache (canvas.get_scaled_pixbuf ());

        /* if we have an 1x1 pixel image, then there's no need to deal with recomputing the
           histogram, because a histogram for a 1x1 image is meaningless. The histogram shows the
           distribution of color over all the many pixels in an image, but if an image only has
           one pixel, the notion of a "distribution over pixels" makes no sense. */
        if (draw_to_pixbuf.width == 1 && draw_to_pixbuf.height == 1)
            disable_histogram_refresh = true;

        /* don't sample the original image to create the histogram if the original image is
           sufficiently large -- if it's over 8k pixels, then we'll get pretty much the same
           histogram if we sample from a half-size image */
        if (((draw_to_pixbuf.width * draw_to_pixbuf.height) > 8192) && (draw_to_pixbuf.width > 1) &&
                (draw_to_pixbuf.height > 1)) {
            histogram_pixbuf = draw_to_pixbuf.scale_simple (draw_to_pixbuf.width / 2,
                               draw_to_pixbuf.height / 2, Gdk.InterpType.HYPER);
        } else {
            histogram_pixbuf = draw_to_pixbuf.copy ();
        }
        virgin_histogram_pixbuf = histogram_pixbuf.copy ();

        DataCollection? owner = canvas.get_photo ().get_membership ();
        if (owner != null)
            owner.items_altered.connect (on_photos_altered);

        base.activate (canvas);
    }

    public override EditingToolWindow? get_tool_window () {
        return adjust_tool_window;
    }

    public override void deactivate () {
        if (canvas != null) {
            DataCollection? owner = canvas.get_photo ().get_membership ();
            if (owner != null)
                owner.items_altered.disconnect (on_photos_altered);

            unbind_canvas_handlers (canvas);
        }

        if (adjust_tool_window != null) {
            unbind_window_handlers ();
            adjust_tool_window.hide ();
            adjust_tool_window.destroy ();
            adjust_tool_window = null;
        }

        draw_to_pixbuf = null;
        fp_pixel_cache = null;

        base.deactivate ();
    }

    public override void paint (Cairo.Context ctx) {
        if (!suppress_effect_redraw) {
            transformer.transform_from_fp (ref fp_pixel_cache, draw_to_pixbuf);
            histogram_transformer.transform_to_other_pixbuf (virgin_histogram_pixbuf,
                    histogram_pixbuf);
            if (!disable_histogram_refresh)
                adjust_tool_window.histogram_manipulator.update_histogram (histogram_pixbuf);
        }

        canvas.paint_pixbuf (draw_to_pixbuf);
    }

    public override Gdk.Pixbuf? get_display_pixbuf (Scaling scaling, Photo photo,
            out Dimensions max_dim) throws Error {
        if (!photo.has_color_adjustments ()) {
            max_dim = Dimensions ();

            return null;
        }

        max_dim = photo.get_dimensions ();

        return photo.get_pixbuf_with_options (scaling, Photo.Exception.ADJUST);
    }

    private void on_reset () {
        AdjustResetCommand command = new AdjustResetCommand (this, transformations);
        AppWindow.get_command_manager ().execute (command);
    }

    private void on_ok () {
        suppress_effect_redraw = true;

        get_tool_window ().hide ();

        applied (new AdjustColorsSingleCommand (canvas.get_photo (), transformations,
                                                Resources.ADJUST_LABEL, Resources.ADJUST_TOOLTIP), draw_to_pixbuf,
                 canvas.get_photo ().get_dimensions (), false);
    }

    private void update_transformations (PixelTransformationBundle new_transformations) {
        foreach (PixelTransformation transformation in new_transformations.get_transformations ())
            update_transformation (transformation);
    }

    private void update_transformation (PixelTransformation new_transformation) {
        PixelTransformation old_transformation = transformations.get_transformation (
                    new_transformation.get_transformation_type ());

        transformer.replace_transformation (old_transformation, new_transformation);
        if (new_transformation.get_transformation_type () != PixelTransformationType.TONE_EXPANSION)
            histogram_transformer.replace_transformation (old_transformation, new_transformation);

        transformations.set (new_transformation);
    }

    private void slider_updated (PixelTransformation new_transformation, string name) {
        PixelTransformation old_transformation = transformations.get_transformation (
                    new_transformation.get_transformation_type ());
        SliderAdjustmentCommand command = new SliderAdjustmentCommand (this, old_transformation,
                new_transformation, name);
        AppWindow.get_command_manager ().execute (command);
    }

    private void on_temperature_adjustment () {
        if (temperature_scheduler == null)
            temperature_scheduler = new OneShotScheduler ("temperature", on_delayed_temperature_adjustment);

        temperature_scheduler.after_timeout (SLIDER_DELAY_MSEC, true);
    }

    private void on_delayed_temperature_adjustment () {
        TemperatureTransformation new_temp_trans = new TemperatureTransformation (
            (float) adjust_tool_window.temperature_slider.get_value ());
        slider_updated (new_temp_trans, _ ("Temperature"));
    }

    private void on_tint_adjustment () {
        if (tint_scheduler == null)
            tint_scheduler = new OneShotScheduler ("tint", on_delayed_tint_adjustment);

        tint_scheduler.after_timeout (SLIDER_DELAY_MSEC, true);
    }

    private void on_delayed_tint_adjustment () {
        TintTransformation new_tint_trans = new TintTransformation (
            (float) adjust_tool_window.tint_slider.get_value ());
        slider_updated (new_tint_trans, _ ("Tint"));
    }

    private void on_saturation_adjustment () {
        if (saturation_scheduler == null)
            saturation_scheduler = new OneShotScheduler ("saturation", on_delayed_saturation_adjustment);

        saturation_scheduler.after_timeout (SLIDER_DELAY_MSEC, true);
    }

    private void on_delayed_saturation_adjustment () {
        SaturationTransformation new_sat_trans = new SaturationTransformation (
            (float) adjust_tool_window.saturation_slider.get_value ());
        slider_updated (new_sat_trans, _ ("Saturation"));
    }

    private void on_exposure_adjustment () {
        if (exposure_scheduler == null)
            exposure_scheduler = new OneShotScheduler ("exposure", on_delayed_exposure_adjustment);

        exposure_scheduler.after_timeout (SLIDER_DELAY_MSEC, true);
    }

    private void on_delayed_exposure_adjustment () {
        ExposureTransformation new_exp_trans = new ExposureTransformation (
            (float) adjust_tool_window.exposure_slider.get_value ());
        slider_updated (new_exp_trans, _ ("Exposure"));
    }

    private void on_shadows_adjustment () {
        if (shadows_scheduler == null)
            shadows_scheduler = new OneShotScheduler ("shadows", on_delayed_shadows_adjustment);

        shadows_scheduler.after_timeout (SLIDER_DELAY_MSEC, true);
    }

    private void on_delayed_shadows_adjustment () {
        ShadowDetailTransformation new_shadows_trans = new ShadowDetailTransformation (
            (float) adjust_tool_window.shadows_slider.get_value ());
        slider_updated (new_shadows_trans, _ ("Shadows"));
    }

    private void on_highlights_adjustment () {
        if (highlights_scheduler == null)
            highlights_scheduler = new OneShotScheduler ("highlights", on_delayed_highlights_adjustment);

        highlights_scheduler.after_timeout (SLIDER_DELAY_MSEC, true);
    }

    private void on_delayed_highlights_adjustment () {
        HighlightDetailTransformation new_highlights_trans = new HighlightDetailTransformation (
            (float) adjust_tool_window.highlights_slider.get_value ());
        slider_updated (new_highlights_trans, _ ("Highlights"));
    }

    private void on_histogram_constraint () {
        int expansion_black_point =
            adjust_tool_window.histogram_manipulator.get_left_nub_position ();
        int expansion_white_point =
            adjust_tool_window.histogram_manipulator.get_right_nub_position ();
        ExpansionTransformation new_exp_trans =
            new ExpansionTransformation.from_extrema (expansion_black_point, expansion_white_point);
        slider_updated (new_exp_trans, _ ("Contrast Expansion"));
    }

    private void on_canvas_resize () {
        draw_to_pixbuf = canvas.get_scaled_pixbuf ().copy ();
        init_fp_pixel_cache (canvas.get_scaled_pixbuf ());
    }

    private bool on_hscale_reset (Gtk.Widget widget, Gdk.EventButton event) {
        Gtk.Scale source = (Gtk.Scale) widget;

        if (event.button == 1 && event.type == Gdk.EventType.BUTTON_PRESS
                && has_only_key_modifier (event.state, Gdk.ModifierType.CONTROL_MASK)) {
            // Left Mouse Button and CTRL pressed
            source.set_value (0);

            return true;
        }

        return false;
    }

    private void bind_canvas_handlers (PhotoCanvas canvas) {
        canvas.resized_scaled_pixbuf.connect (on_canvas_resize);
    }

    private void unbind_canvas_handlers (PhotoCanvas canvas) {
        canvas.resized_scaled_pixbuf.disconnect (on_canvas_resize);
    }

    private void bind_window_handlers () {
        adjust_tool_window.ok_button.clicked.connect (on_ok);
        adjust_tool_window.reset_button.clicked.connect (on_reset);
        adjust_tool_window.cancel_button.clicked.connect (notify_cancel);
        adjust_tool_window.exposure_slider.value_changed.connect (on_exposure_adjustment);
        adjust_tool_window.saturation_slider.value_changed.connect (on_saturation_adjustment);
        adjust_tool_window.tint_slider.value_changed.connect (on_tint_adjustment);
        adjust_tool_window.temperature_slider.value_changed.connect (on_temperature_adjustment);
        adjust_tool_window.shadows_slider.value_changed.connect (on_shadows_adjustment);
        adjust_tool_window.highlights_slider.value_changed.connect (on_highlights_adjustment);
        adjust_tool_window.histogram_manipulator.nub_position_changed.connect (on_histogram_constraint);

        adjust_tool_window.saturation_slider.button_press_event.connect (on_hscale_reset);
        adjust_tool_window.exposure_slider.button_press_event.connect (on_hscale_reset);
        adjust_tool_window.tint_slider.button_press_event.connect (on_hscale_reset);
        adjust_tool_window.temperature_slider.button_press_event.connect (on_hscale_reset);
        adjust_tool_window.shadows_slider.button_press_event.connect (on_hscale_reset);
        adjust_tool_window.highlights_slider.button_press_event.connect (on_hscale_reset);
    }

    private void unbind_window_handlers () {
        adjust_tool_window.ok_button.clicked.disconnect (on_ok);
        adjust_tool_window.reset_button.clicked.disconnect (on_reset);
        adjust_tool_window.cancel_button.clicked.disconnect (notify_cancel);
        adjust_tool_window.exposure_slider.value_changed.disconnect (on_exposure_adjustment);
        adjust_tool_window.saturation_slider.value_changed.disconnect (on_saturation_adjustment);
        adjust_tool_window.tint_slider.value_changed.disconnect (on_tint_adjustment);
        adjust_tool_window.temperature_slider.value_changed.disconnect (on_temperature_adjustment);
        adjust_tool_window.shadows_slider.value_changed.disconnect (on_shadows_adjustment);
        adjust_tool_window.highlights_slider.value_changed.disconnect (on_highlights_adjustment);
        adjust_tool_window.histogram_manipulator.nub_position_changed.disconnect (on_histogram_constraint);

        adjust_tool_window.saturation_slider.button_press_event.disconnect (on_hscale_reset);
        adjust_tool_window.exposure_slider.button_press_event.disconnect (on_hscale_reset);
        adjust_tool_window.tint_slider.button_press_event.disconnect (on_hscale_reset);
        adjust_tool_window.temperature_slider.button_press_event.disconnect (on_hscale_reset);
        adjust_tool_window.shadows_slider.button_press_event.disconnect (on_hscale_reset);
        adjust_tool_window.highlights_slider.button_press_event.disconnect (on_hscale_reset);
    }

    public bool enhance () {
        AdjustEnhanceCommand command = new AdjustEnhanceCommand (this, canvas.get_photo ());
        AppWindow.get_command_manager ().execute (command);

        return true;
    }

    private void on_photos_altered (Gee.Map<DataObject, Alteration> map) {
        if (!map.has_key (canvas.get_photo ()))
            return;

        PixelTransformationBundle adjustments = canvas.get_photo ().get_color_adjustments ();
        set_adjustments (adjustments);
    }

    private void set_adjustments (PixelTransformationBundle new_adjustments) {
        unbind_window_handlers ();

        update_transformations (new_adjustments);

        foreach (PixelTransformation adjustment in new_adjustments.get_transformations ())
            update_slider (adjustment);

        bind_window_handlers ();
        canvas.repaint ();
    }

    // Note that window handlers should be unbound (unbind_window_handlers) prior to calling this
    // if the caller doesn't want the widget's signals to fire with the change.
    private void update_slider (PixelTransformation transformation) {
        switch (transformation.get_transformation_type ()) {
        case PixelTransformationType.TONE_EXPANSION:
            ExpansionTransformation expansion = (ExpansionTransformation) transformation;

            if (!disable_histogram_refresh) {
                adjust_tool_window.histogram_manipulator.set_left_nub_position (
                    expansion.get_black_point ());
                adjust_tool_window.histogram_manipulator.set_right_nub_position (
                    expansion.get_white_point ());
            }
            break;

        case PixelTransformationType.SHADOWS:
            adjust_tool_window.shadows_slider.set_value (
                ((ShadowDetailTransformation) transformation).get_parameter ());
            break;

        case PixelTransformationType.HIGHLIGHTS:
            adjust_tool_window.highlights_slider.set_value (
                ((HighlightDetailTransformation) transformation).get_parameter ());
            break;

        case PixelTransformationType.EXPOSURE:
            adjust_tool_window.exposure_slider.set_value (
                ((ExposureTransformation) transformation).get_parameter ());
            break;

        case PixelTransformationType.SATURATION:
            adjust_tool_window.saturation_slider.set_value (
                ((SaturationTransformation) transformation).get_parameter ());
            break;

        case PixelTransformationType.TINT:
            adjust_tool_window.tint_slider.set_value (
                ((TintTransformation) transformation).get_parameter ());
            break;

        case PixelTransformationType.TEMPERATURE:
            adjust_tool_window.temperature_slider.set_value (
                ((TemperatureTransformation) transformation).get_parameter ());
            break;

        default:
            error ("Unknown adjustment: %d", (int) transformation.get_transformation_type ());
        }
    }

    private void init_fp_pixel_cache (Gdk.Pixbuf source) {
        int source_width = source.get_width ();
        int source_height = source.get_height ();
        int source_num_channels = source.get_n_channels ();
        int source_rowstride = source.get_rowstride ();
        unowned uchar[] source_pixels = source.get_pixels ();

        fp_pixel_cache = new float[3 * source_width * source_height];
        int cache_pixel_index = 0;
        float INV_255 = 1.0f / 255.0f;

        for (int j = 0; j < source_height; j++) {
            int row_start_index = j * source_rowstride;
            int row_end_index = row_start_index + (source_width * source_num_channels);
            for (int i = row_start_index; i < row_end_index; i += source_num_channels) {
                fp_pixel_cache[cache_pixel_index++] = ((float) source_pixels[i]) * INV_255;
                fp_pixel_cache[cache_pixel_index++] = ((float) source_pixels[i + 1]) * INV_255;
                fp_pixel_cache[cache_pixel_index++] = ((float) source_pixels[i + 2]) * INV_255;
            }
        }
    }

    public override bool on_keypress (Gdk.EventKey event) {
        if ((Gdk.keyval_name (event.keyval) == "KP_Enter") ||
                (Gdk.keyval_name (event.keyval) == "Enter") ||
                (Gdk.keyval_name (event.keyval) == "Return")) {
            on_ok ();
            return true;
        }

        return base.on_keypress (event);
    }
}
