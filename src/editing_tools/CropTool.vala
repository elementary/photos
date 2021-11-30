/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2016-2018 elementary, Inc. (https://elementary.io)
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

public class EditingTools.CropTool : EditingTool {
    private const double CROP_INIT_X_PCT = 0.15;
    private const double CROP_INIT_Y_PCT = 0.15;

    private const int CROP_MIN_SIZE = 8;

    private const float CROP_EXTERIOR_SATURATION = 0.00f;
    private const int CROP_EXTERIOR_RED_SHIFT = -32;
    private const int CROP_EXTERIOR_GREEN_SHIFT = -32;
    private const int CROP_EXTERIOR_BLUE_SHIFT = -32;
    private const int CROP_EXTERIOR_ALPHA_SHIFT = 0;

    private const float ANY_ASPECT_RATIO = -1.0f;
    private const float SCREEN_ASPECT_RATIO = -2.0f;
    private const float ORIGINAL_ASPECT_RATIO = -3.0f;
    private const float CUSTOM_ASPECT_RATIO = -4.0f;
    private const float COMPUTE_FROM_BASIS = -5.0f;
    private const float SEPARATOR = -6.0f;
    private const float MIN_ASPECT_RATIO = 1.0f / 64.0f;
    private const float MAX_ASPECT_RATIO = 64.0f;

    private class ConstraintDescription : Object {
        public string name { get; construct; }
        public int basis_width { get; set construct; }
        public int basis_height { get; set construct; }
        public bool is_pivotable { get; construct; }
        public float aspect_ratio { get; set construct; }

        public ConstraintDescription (string new_name, int new_basis_width, int new_basis_height,
                                      bool new_pivotable, float new_aspect_ratio = COMPUTE_FROM_BASIS) {
            Object (
                name: new_name,
                basis_width: new_basis_width,
                basis_height: new_basis_height,
                is_pivotable: new_pivotable,
                aspect_ratio: new_aspect_ratio
            );
            if (aspect_ratio == COMPUTE_FROM_BASIS) {
                aspect_ratio = ((float) basis_width) / ((float) basis_height);
            } else {
                aspect_ratio = new_aspect_ratio;
            }
        }

        public bool is_separator () {
            return !is_pivotable && aspect_ratio == SEPARATOR;
        }
    }

    private enum ReticleOrientation {
        LANDSCAPE,
        PORTRAIT;

        public ReticleOrientation toggle () {
            return (this == ReticleOrientation.LANDSCAPE) ? ReticleOrientation.PORTRAIT :
            ReticleOrientation.LANDSCAPE;
        }
    }

    private enum ConstraintMode {
        NORMAL,
        CUSTOM
    }

    private class CropToolWindow : EditingToolWindow {
        public Gtk.Button crop_button { get; private set; }
        public Gtk.Button cancel_button { get; private set; }
        public Gtk.ComboBox constraint_combo { get; private set; }
        public Gtk.Button pivot_reticle_button { get; private set; }
        public Gtk.Entry custom_width_entry { get; private set; }
        public Gtk.Entry custom_height_entry { get; private set; }
        public Gtk.Revealer custom_aspect_revealer { get; private set; }
        public Gtk.Entry most_recently_edited { get; private set; default = null; }

        public CropToolWindow (Gtk.Window container) {
            Object (transient_for: container);
        }

        construct {
            cancel_button = new Gtk.Button.with_mnemonic (_("_Cancel"));

            crop_button = new Gtk.Button.with_label (Resources.CROP_LABEL) {
                can_default = true
            };

            var combo_text_renderer = new Gtk.CellRendererText ();

            constraint_combo = new Gtk.ComboBox ();
            constraint_combo.pack_start (combo_text_renderer, true);
            constraint_combo.add_attribute (combo_text_renderer, "text", 0);
            constraint_combo.set_row_separator_func (constraint_combo_separator_func);
            constraint_combo.set_active (0);

            pivot_reticle_button = new Gtk.Button.from_icon_name ("object-rotate-right-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
                tooltip_text = _("Pivot the crop rectangle between portrait and landscape orientations"),
                margin_end = 18
            };

            custom_width_entry = new Gtk.Entry () {
                activates_default = true,
                vexpand = true,
                width_chars = 4,
                xalign = 0.5f
            };

            custom_height_entry = new Gtk.Entry () {
                activates_default = true,
                width_chars = 4,
                xalign = 0.5f
            };

            var custom_aspect_grid = new Gtk.Grid () {
                column_spacing = 3
            };
            custom_aspect_grid.add (custom_width_entry);
            custom_aspect_grid.add (new Gtk.Label (":"));
            custom_aspect_grid.add (custom_height_entry);

            custom_aspect_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT
            };
            custom_aspect_revealer.add (custom_aspect_grid);

            var response_sizegroup = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            response_sizegroup.add_widget (cancel_button);
            response_sizegroup.add_widget (crop_button);

            var layout = new Gtk.Grid ();
            layout.column_spacing = 6;
            layout.add (constraint_combo);
            layout.add (custom_aspect_revealer);
            layout.add (pivot_reticle_button);
            layout.add (cancel_button);
            layout.add (crop_button);

            content_area.add (layout);

            // Has to be set after activates_default
            crop_button.has_default = true;

            custom_width_entry.focus_out_event.connect (() => {
                most_recently_edited = custom_width_entry;
            });

            custom_height_entry.focus_out_event.connect (() => {
                most_recently_edited = custom_height_entry;
            });
        }

        private static bool constraint_combo_separator_func (Gtk.TreeModel model, Gtk.TreeIter iter) {
            Value val;
            model.get_value (iter, 0, out val);

            return (val.dup_string () == "-");
        }
    }

    private CropToolWindow crop_tool_window = null;
    private Gdk.CursorType current_cursor_type = Gdk.CursorType.LEFT_PTR;
    private BoxLocation in_manipulation = BoxLocation.OUTSIDE;
    private Cairo.Context wide_black_ctx = null;
    private Cairo.Context wide_white_ctx = null;
    private Cairo.Context thin_white_ctx = null;
    private Cairo.Context text_ctx = null;

    // This is where we draw our crop tool
    private Cairo.Surface crop_surface = null;

    // these are kept in absolute coordinates, not relative to photo's position on canvas
    private Box scaled_crop;
    private int last_grab_x = -1;
    private int last_grab_y = -1;

    private ConstraintDescription[] constraints = create_constraints ();
    private Gtk.ListStore constraint_list = create_constraint_list (create_constraints ());
    private ReticleOrientation reticle_orientation = ReticleOrientation.LANDSCAPE;
    private ConstraintMode constraint_mode = ConstraintMode.NORMAL;
    private bool entry_insert_in_progress = false;
    private float custom_aspect_ratio = 1.0f;
    private int custom_width = -1;
    private int custom_height = -1;
    private int custom_init_width = -1;
    private int custom_init_height = -1;
    private int scale_factor = 1;
    private float pre_aspect_ratio = ANY_ASPECT_RATIO;
    private GLib.Settings crop_settings;

    private CropTool () {
        Object (
            name: "CropTool"
        );

    }

    construct {
        crop_settings = new GLib.Settings (GSettingsConfigurationEngine.CROP_SCHEMA_NAME);
    }

    public static CropTool factory () {
        return new CropTool ();
    }

    public static bool is_available (Photo photo, Scaling scaling) {
        Dimensions dim = scaling.get_scaled_dimensions (photo.get_original_dimensions ());

        return dim.width > CROP_MIN_SIZE && dim.height > CROP_MIN_SIZE;
    }

    private static ConstraintDescription[] create_constraints () {
        ConstraintDescription[] result = new ConstraintDescription[0];

        result += new ConstraintDescription (_("Unconstrained"), 0, 0, false, ANY_ASPECT_RATIO);
        result += new ConstraintDescription (_("Square"), 1, 1, false);
        result += new ConstraintDescription (_("Screen"), 0, 0, true, SCREEN_ASPECT_RATIO);
        result += new ConstraintDescription (_("Original Size"), 0, 0, true, ORIGINAL_ASPECT_RATIO);
        result += new ConstraintDescription (_("-"), 0, 0, false, SEPARATOR);
        result += new ConstraintDescription (_("SD Video (4 : 3)"), 4, 3, true);
        result += new ConstraintDescription (_("HD Video (16 : 9)"), 16, 9, true);
        result += new ConstraintDescription (_("-"), 0, 0, false, SEPARATOR);
        result += new ConstraintDescription (_("Wallet (2 x 3 in.)"), 3, 2, true);
        result += new ConstraintDescription (_("Notecard (3 x 5 in.)"), 5, 3, true);
        result += new ConstraintDescription (_("4 x 6 in."), 6, 4, true);
        result += new ConstraintDescription (_("5 x 7 in."), 7, 5, true);
        result += new ConstraintDescription (_("8 x 10 in."), 10, 8, true);
        result += new ConstraintDescription (_("Letter (8.5 x 11 in.)"), 85, 110, true);
        result += new ConstraintDescription (_("11 x 14 in."), 14, 11, true);
        result += new ConstraintDescription (_("Tabloid (11 x 17 in.)"), 17, 11, true);
        result += new ConstraintDescription (_("16 x 20 in."), 20, 16, true);
        result += new ConstraintDescription (_("-"), 0, 0, false, SEPARATOR);
        result += new ConstraintDescription (_("Metric Wallet (9 x 13 cm)"), 13, 9, true);
        result += new ConstraintDescription (_("Postcard (10 x 15 cm)"), 15, 10, true);
        result += new ConstraintDescription (_("13 x 18 cm"), 18, 13, true);
        result += new ConstraintDescription (_("18 x 24 cm"), 24, 18, true);
        result += new ConstraintDescription (_("A4 (210 x 297 mm)"), 210, 297, true);
        result += new ConstraintDescription (_("20 x 30 cm"), 30, 20, true);
        result += new ConstraintDescription (_("24 x 40 cm"), 40, 24, true);
        result += new ConstraintDescription (_("30 x 40 cm"), 40, 30, true);
        result += new ConstraintDescription (_("A3 (297 x 420 mm)"), 420, 297, true);
        result += new ConstraintDescription (_("-"), 0, 0, false, SEPARATOR);
        result += new ConstraintDescription (_("Custom"), 0, 0, true, CUSTOM_ASPECT_RATIO);

        return result;
    }

    private static Gtk.ListStore create_constraint_list (ConstraintDescription[] constraint_data) {
        Gtk.ListStore result = new Gtk.ListStore (1, typeof (string), typeof (string));

        Gtk.TreeIter iter;
        foreach (ConstraintDescription constraint in constraint_data) {
            result.append (out iter);
            result.set_value (iter, 0, constraint.name);
        }

        return result;
    }

    private void update_pivot_button_state () {
        crop_tool_window.pivot_reticle_button.sensitive = get_selected_constraint ().is_pivotable;
    }

    private ConstraintDescription get_selected_constraint () {
        ConstraintDescription result = constraints[crop_tool_window.constraint_combo.get_active ()];

        if (result.aspect_ratio == ORIGINAL_ASPECT_RATIO) {
            result.basis_width = canvas.scaled_position.width;
            result.basis_height = canvas.scaled_position.height;
        } else if (result.aspect_ratio == SCREEN_ASPECT_RATIO) {
            var dimensions = Scaling.get_screen_dimensions (AppWindow.get_instance ());
            result.basis_width = dimensions.width;
            result.basis_height = dimensions.height;
        }

        return result;
    }

    private bool on_custom_entry_focus_out (Gdk.EventFocus event) {
        int width = int.parse (crop_tool_window.custom_width_entry.text);
        int height = int.parse (crop_tool_window.custom_height_entry.text);

        if (width < 1) {
            width = 1;
            crop_tool_window.custom_width_entry.set_text ("%d".printf (width));
        }

        if (height < 1) {
            height = 1;
            crop_tool_window.custom_height_entry.set_text ("%d".printf (height));
        }

        if ((width == custom_width) && (height == custom_height)) {
            return false;
        }

        custom_aspect_ratio = ((float) width) / ((float) height);

        if (custom_aspect_ratio < MIN_ASPECT_RATIO) {
            if (crop_tool_window.most_recently_edited == crop_tool_window.custom_height_entry) {
                height = (int) (width / MIN_ASPECT_RATIO);
                crop_tool_window.custom_height_entry.set_text ("%d".printf (height));
            } else {
                width = (int) (height * MIN_ASPECT_RATIO);
                crop_tool_window.custom_width_entry.set_text ("%d".printf (width));
            }
        } else if (custom_aspect_ratio > MAX_ASPECT_RATIO) {
            if (crop_tool_window.most_recently_edited == crop_tool_window.custom_height_entry) {
                height = (int) (width / MAX_ASPECT_RATIO);
                crop_tool_window.custom_height_entry.set_text ("%d".printf (height));
            } else {
                width = (int) (height * MAX_ASPECT_RATIO);
                crop_tool_window.custom_width_entry.set_text ("%d".printf (width));
            }
        }

        custom_aspect_ratio = ((float) width) / ((float) height);

        Box new_crop = constrain_crop (scaled_crop);

        crop_resized (new_crop);
        scaled_crop = new_crop;
        canvas.invalidate_area (new_crop);
        canvas.repaint ();

        custom_width = width;
        custom_height = height;

        return false;
    }

    private void on_width_insert_text (string text, int length, ref int position) {
        on_entry_insert_text (crop_tool_window.custom_width_entry, text, length, ref position);
    }

    private void on_height_insert_text (string text, int length, ref int position) {
        on_entry_insert_text (crop_tool_window.custom_height_entry, text, length, ref position);
    }

    private void on_entry_insert_text (Gtk.Entry sender, string text, int length, ref int position) {
        if (entry_insert_in_progress) {
            return;
        }

        entry_insert_in_progress = true;

        if (length == -1) {
            length = (int) text.length;
        }

        // only permit numeric text
        string new_text = "";
        for (int ctr = 0; ctr < length; ctr++) {
            if (text[ctr].isdigit ()) {
                new_text += ((char) text[ctr]).to_string ();
            }
        }

        if (new_text.length > 0) {
            sender.insert_text (new_text, (int) new_text.length, ref position);
        }

        Signal.stop_emission_by_name (sender, "insert-text");

        entry_insert_in_progress = false;
    }

    private float get_constraint_aspect_ratio () {
        float result = get_selected_constraint ().aspect_ratio;

        if (result == ORIGINAL_ASPECT_RATIO) {
            result = ((float) canvas.scaled_position.width) /
                     ((float) canvas.scaled_position.height);
        } else if (result == SCREEN_ASPECT_RATIO) {
            var dimensions = Scaling.get_screen_dimensions (AppWindow.get_instance ());
            result = ((float) dimensions.width) / ((float) dimensions.height);
        } else if (result == CUSTOM_ASPECT_RATIO) {
            result = custom_aspect_ratio;
        }
        if (reticle_orientation == ReticleOrientation.PORTRAIT) {
            result = 1.0f / result;
        }

        return result;
    }

    private void constraint_changed () {
        ConstraintDescription selected_constraint = get_selected_constraint ();
        if (selected_constraint.aspect_ratio == CUSTOM_ASPECT_RATIO) {
            set_custom_constraint_mode ();
        } else {
            if (constraint_mode != ConstraintMode.NORMAL) {
                crop_tool_window.custom_aspect_revealer.reveal_child = false;
                constraint_mode = ConstraintMode.NORMAL;
            }

            if (selected_constraint.aspect_ratio != ANY_ASPECT_RATIO) {
                // user may have switched away from 'Custom' without
                // accepting, so set these to default back to saved
                // values.
                custom_init_width = crop_settings.get_int ("last-crop-width");
                custom_init_height = crop_settings.get_int ("last-crop-height");
                custom_aspect_ratio = ((float) custom_init_width) / ((float) custom_init_height);
            }
        }

        update_pivot_button_state ();

        if (!get_selected_constraint ().is_pivotable) {
            reticle_orientation = ReticleOrientation.LANDSCAPE;
        }

        if (get_constraint_aspect_ratio () != pre_aspect_ratio) {
            Box new_crop = constrain_crop (scaled_crop);

            crop_resized (new_crop);
            scaled_crop = new_crop;
            canvas.invalidate_area (new_crop);
            canvas.repaint ();

            pre_aspect_ratio = get_constraint_aspect_ratio ();
        }
    }

    private void set_custom_constraint_mode () {
        if (constraint_mode == ConstraintMode.CUSTOM) {
            return;
        }

        crop_tool_window.custom_aspect_revealer.reveal_child = true;

        if (reticle_orientation == ReticleOrientation.LANDSCAPE) {
            crop_tool_window.custom_width_entry.set_text ("%d".printf (custom_init_width));
            crop_tool_window.custom_height_entry.set_text ("%d".printf (custom_init_height));
        } else {
            crop_tool_window.custom_width_entry.set_text ("%d".printf (custom_init_height));
            crop_tool_window.custom_height_entry.set_text ("%d".printf (custom_init_width));
        }
        custom_aspect_ratio = ((float) custom_init_width) / ((float) custom_init_height);

        constraint_mode = ConstraintMode.CUSTOM;
    }

    private Box constrain_crop (Box crop) {
        float user_aspect_ratio = get_constraint_aspect_ratio ();
        if (user_aspect_ratio == ANY_ASPECT_RATIO) {
            return crop;
        }

        // PHASE 1: Scale to the desired aspect ratio, preserving area and center.
        float old_area = (float) (crop.get_width () * crop.get_height ());
        crop.adjust_height ((int) Math.sqrt (old_area / user_aspect_ratio));
        crop.adjust_width ((int) Math.sqrt (old_area * user_aspect_ratio));

        // PHASE 2: Crop to the image boundary.
        Dimensions image_size = get_photo_dimensions ();
        double angle;
        canvas.photo.get_straighten (out angle);
        crop = clamp_inside_rotated_image (crop, image_size.width, image_size.height, angle, false);

        // PHASE 3: Crop down to the aspect ratio if necessary.
        if (crop.get_width () >= crop.get_height () * user_aspect_ratio) {  // possibly too wide
            crop.adjust_width ((int) (crop.get_height () * user_aspect_ratio));
        } else {   // possibly too tall
            crop.adjust_height ((int) (crop.get_width () / user_aspect_ratio));
        }

        return crop;
    }

    private ConstraintDescription? get_last_constraint (out int index) {
        index = crop_settings.get_int ("last-crop-menu-choice");

        return (index < constraints.length) ? constraints[index] : null;
    }

    public override void activate (PhotoCanvas canvas) {
        scale_factor = canvas.container.scale_factor;
        bind_canvas_handlers (canvas);

        prepare_ctx (canvas.default_ctx, canvas.surface_dim);

        if (crop_surface != null) {
            crop_surface = null;
        }

        crop_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32,
                                               canvas.scaled_position.width,
                                               canvas.scaled_position.height);

        Cairo.Context ctx = new Cairo.Context (crop_surface);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 1.0);
        ctx.paint ();

        // create the crop tool window, where the user can apply or cancel the crop
        crop_tool_window = new CropToolWindow (canvas.container);

        // set up the constraint combo box
        crop_tool_window.constraint_combo.set_model (constraint_list);
        if (!canvas.photo.has_crop ()) {
            int index;
            ConstraintDescription? desc = get_last_constraint (out index);
            if (desc != null && !desc.is_separator ()) {
                crop_tool_window.constraint_combo.set_active (index);
            }
        }

        // set up the pivot reticle button
        update_pivot_button_state ();
        reticle_orientation = ReticleOrientation.LANDSCAPE;

        bind_window_handlers ();

        // obtain crop dimensions and paint against the uncropped photo
        Dimensions uncropped_dim = canvas.photo.get_dimensions (Photo.Exception.CROP);

        Box crop;
        if (!canvas.photo.get_crop (out crop)) {
            int xofs = (int) (uncropped_dim.width * CROP_INIT_X_PCT);
            int yofs = (int) (uncropped_dim.height * CROP_INIT_Y_PCT);

            // initialize the actual crop in absolute coordinates, not relative
            // to the photo's position on the canvas
            crop = Box (xofs, yofs, uncropped_dim.width - xofs, uncropped_dim.height - yofs);
        }

        // scale the crop to the scaled photo's size ... the scaled crop is maintained in
        // coordinates not relative to photo's position on canvas
        scaled_crop = crop.get_scaled_similar (uncropped_dim,
                                               Dimensions.for_rectangle (canvas.scaled_position));

        // get the custom width and height from the saved config and
        // set up the initial custom values with it.
        custom_width = crop_settings.get_int ("last-crop-width");
        custom_height = crop_settings.get_int ("last-crop-height");
        custom_init_width = custom_width;
        custom_init_height = custom_height;
        pre_aspect_ratio = ((float) custom_init_width) / ((float) custom_init_height);

        constraint_mode = ConstraintMode.NORMAL;

        base.activate (canvas);

        // make sure the window has its regular size before going into
        // custom mode, which will resize it and needs to save the old
        // size first.
        crop_tool_window.show_all ();
        crop_tool_window.hide ();

        // was 'custom' the most-recently-chosen menu item?
        if (!canvas.photo.has_crop ()) {
            ConstraintDescription? desc = get_last_constraint (null);
            if (desc != null && !desc.is_separator () && desc.aspect_ratio == CUSTOM_ASPECT_RATIO) {
                set_custom_constraint_mode ();
            }
        }

        // since we no longer just run with the default, but rather
        // a saved value, we'll behave as if the saved constraint has
        // just been changed to so that everything gets updated and
        // the canvas stays in sync.
        Box new_crop = constrain_crop (scaled_crop);

        crop_resized (new_crop);
        scaled_crop = new_crop;
        canvas.invalidate_area (new_crop);
        canvas.repaint ();

        pre_aspect_ratio = get_constraint_aspect_ratio ();
    }

    private void bind_canvas_handlers (PhotoCanvas canvas) {
        canvas.new_surface.connect (prepare_ctx);
        canvas.resized_scaled_pixbuf.connect (on_resized_pixbuf);
    }

    private void unbind_canvas_handlers (PhotoCanvas canvas) {
        canvas.new_surface.disconnect (prepare_ctx);
        canvas.resized_scaled_pixbuf.disconnect (on_resized_pixbuf);
    }

    private void bind_window_handlers () {
        crop_tool_window.crop_button.clicked.connect (on_crop_ok);
        crop_tool_window.cancel_button.clicked.connect (notify_cancel);
        crop_tool_window.constraint_combo.changed.connect (constraint_changed);
        crop_tool_window.pivot_reticle_button.clicked.connect (on_pivot_button_clicked);

        // set up the custom width and height entry boxes
        crop_tool_window.custom_width_entry.focus_out_event.connect (on_custom_entry_focus_out);
        crop_tool_window.custom_height_entry.focus_out_event.connect (on_custom_entry_focus_out);
        crop_tool_window.custom_width_entry.insert_text.connect (on_width_insert_text);
        crop_tool_window.custom_height_entry.insert_text.connect (on_height_insert_text);
    }

    private void unbind_window_handlers () {
        crop_tool_window.crop_button.clicked.disconnect (on_crop_ok);
        crop_tool_window.cancel_button.clicked.disconnect (notify_cancel);
        crop_tool_window.constraint_combo.changed.disconnect (constraint_changed);
        crop_tool_window.pivot_reticle_button.clicked.disconnect (on_pivot_button_clicked);

        // set up the custom width and height entry boxes
        crop_tool_window.custom_width_entry.focus_out_event.disconnect (on_custom_entry_focus_out);
        crop_tool_window.custom_height_entry.focus_out_event.disconnect (on_custom_entry_focus_out);
        crop_tool_window.custom_width_entry.insert_text.disconnect (on_width_insert_text);
    }

    private void on_pivot_button_clicked () {
        if (get_selected_constraint ().aspect_ratio == CUSTOM_ASPECT_RATIO) {
            string width_text = crop_tool_window.custom_width_entry.get_text ();
            string height_text = crop_tool_window.custom_height_entry.get_text ();
            crop_tool_window.custom_width_entry.set_text (height_text);
            crop_tool_window.custom_height_entry.set_text (width_text);

            int temp = custom_width;
            custom_width = custom_height;
            custom_height = temp;
        }
        reticle_orientation = reticle_orientation.toggle ();
        constraint_changed ();
    }

    public override void deactivate () {
        if (canvas != null) {
            unbind_canvas_handlers (canvas);
        }

        if (crop_tool_window != null) {
            unbind_window_handlers ();
            crop_tool_window.hide ();
            crop_tool_window.destroy ();
            crop_tool_window = null;
        }

        // make sure the cursor isn't set to a modify indicator
        if (canvas != null) {
            canvas.drawing_window.set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.LEFT_PTR));
        }

        crop_surface = null;

        base.deactivate ();
    }

    public override EditingToolWindow? get_tool_window () {
        return crop_tool_window;
    }

    public override Gdk.Pixbuf? get_display_pixbuf (Scaling scaling, Photo photo,
            out Dimensions max_dim) throws Error {
        max_dim = photo.get_dimensions (Photo.Exception.CROP);

        return photo.get_pixbuf_with_options (scaling, Photo.Exception.CROP);
    }

    private void prepare_ctx (Cairo.Context ctx, Dimensions dim) {
        wide_black_ctx = new Cairo.Context (ctx.get_target ());
        set_source_color_from_string (wide_black_ctx, "#000");
        wide_black_ctx.set_line_width (1 * scale_factor);

        wide_white_ctx = new Cairo.Context (ctx.get_target ());
        set_source_color_from_string (wide_white_ctx, "#FFF");
        wide_white_ctx.set_line_width (1 * scale_factor);

        thin_white_ctx = new Cairo.Context (ctx.get_target ());
        set_source_color_from_string (thin_white_ctx, "#FFF");
        thin_white_ctx.set_line_width (0.5 * scale_factor);

        text_ctx = new Cairo.Context (ctx.get_target ());
        text_ctx.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        text_ctx.set_font_size (10.0 * scale_factor);
    }

    private void on_resized_pixbuf (Dimensions old_dim, Gdk.Pixbuf scaled, Gdk.Rectangle scaled_position) {
        Dimensions new_dim = Dimensions.for_pixbuf (scaled);
        Dimensions uncropped_dim = canvas.photo.get_dimensions (Photo.Exception.CROP);

        // rescale to full crop
        Box crop = scaled_crop.get_scaled_similar (old_dim, uncropped_dim);

        // rescale back to new size
        scaled_crop = crop.get_scaled_similar (uncropped_dim, new_dim);
        if (crop_surface != null) {
            crop_surface = null;
        }

        crop_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, scaled.width, scaled.height);
        Cairo.Context ctx = new Cairo.Context (crop_surface);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 1.0);
        ctx.paint ();

    }

    public override void on_left_click (int x, int y) {
        x *= scale_factor;
        y *= scale_factor;

        Gdk.Rectangle scaled_pixbuf_pos = canvas.scaled_position;

        // scaled_crop is not maintained relative to photo's position on canvas
        Box offset_scaled_crop = scaled_crop.get_offset (scaled_pixbuf_pos.x, scaled_pixbuf_pos.y);

        // determine where the mouse down landed and store for future events
        in_manipulation = offset_scaled_crop.approx_location (x, y);
        last_grab_x = x -= scaled_pixbuf_pos.x;
        last_grab_y = y -= scaled_pixbuf_pos.y;

        // repaint because the crop changes on a mouse down
        canvas.repaint ();
    }

    public override void on_left_released (int x, int y) {
        x *= scale_factor;
        y *= scale_factor;

        // nothing to do if released outside of the crop box
        if (in_manipulation == BoxLocation.OUTSIDE) {
            return;
        }

        // end manipulation
        in_manipulation = BoxLocation.OUTSIDE;
        last_grab_x = -1;
        last_grab_y = -1;

        update_cursor (x, y);

        // repaint because crop changes when released
        canvas.repaint ();
    }

    public override void on_motion (int x, int y, Gdk.ModifierType mask) {
        x *= scale_factor;
        y *= scale_factor;

        // only deal with manipulating the crop tool when click-and-dragging one of the edges
        // or the interior
        if (in_manipulation != BoxLocation.OUTSIDE) {
            on_canvas_manipulation (x, y);
        }

        update_cursor (x, y);
        canvas.repaint ();
    }

    public override void paint (Cairo.Context default_ctx) {
        // fill region behind the crop surface with neutral color
        int w = canvas.drawing_window.get_width () * scale_factor;
        int h = canvas.drawing_window.get_height () * scale_factor;

        canvas.get_style_context ().render_background (default_ctx, 0, 0, w, h);

        Cairo.Context ctx = new Cairo.Context (crop_surface);
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 0.5);
        ctx.paint ();

        // paint exposed (cropped) part of pixbuf minus crop border
        ctx.set_source_rgba (0.0, 0.0, 0.0, 0.0);
        ctx.rectangle (scaled_crop.left, scaled_crop.top, scaled_crop.get_width (),
                       scaled_crop.get_height ());
        ctx.fill ();
        canvas.paint_surface (crop_surface, true);

        // paint crop tool last
        paint_crop_tool (scaled_crop);
    }

    private void on_crop_ok () {
        // user's clicked OK, save the combobox choice and width/height.
        // safe to do, even if not in 'custom' mode - the previous values
        // will just get saved again.
        crop_settings.set_int ("last-crop-menu-choice", crop_tool_window.constraint_combo.get_active ());
        crop_settings.set_int ("last-crop-width", custom_width);
        crop_settings.set_int ("last-crop-height", custom_height);

        // scale screen-coordinate crop to photo's coordinate system
        Box crop = scaled_crop.get_scaled_similar (
                       Dimensions.for_rectangle (canvas.scaled_position),
                       canvas.photo.get_dimensions (Photo.Exception.CROP));

        // crop the current pixbuf and offer it to the editing host
        Gdk.Pixbuf cropped = new Gdk.Pixbuf.subpixbuf (canvas.scaled_pixbuf, scaled_crop.left,
                scaled_crop.top, scaled_crop.get_width (), scaled_crop.get_height ());

        // signal host; we have a cropped image, but it will be scaled upward, and so a better one
        // should be fetched
        applied (new CropCommand (canvas.photo, crop, Resources.CROP_LABEL,
                                  Resources.CROP_TOOLTIP), cropped, crop.get_dimensions (), true);
    }

    private void update_cursor (int x, int y) {
        // scaled_crop is not maintained relative to photo's position on canvas
        Gdk.Rectangle scaled_pos = canvas.scaled_position;
        Box offset_scaled_crop = scaled_crop.get_offset (scaled_pos.x, scaled_pos.y);

        Gdk.CursorType cursor_type = Gdk.CursorType.LEFT_PTR;
        switch (offset_scaled_crop.approx_location (x, y)) {
            case BoxLocation.LEFT_SIDE:
                cursor_type = Gdk.CursorType.LEFT_SIDE;
                break;

            case BoxLocation.TOP_SIDE:
                cursor_type = Gdk.CursorType.TOP_SIDE;
                break;

            case BoxLocation.RIGHT_SIDE:
                cursor_type = Gdk.CursorType.RIGHT_SIDE;
                break;

            case BoxLocation.BOTTOM_SIDE:
                cursor_type = Gdk.CursorType.BOTTOM_SIDE;
                break;

            case BoxLocation.TOP_LEFT:
                cursor_type = Gdk.CursorType.TOP_LEFT_CORNER;
                break;

            case BoxLocation.BOTTOM_LEFT:
                cursor_type = Gdk.CursorType.BOTTOM_LEFT_CORNER;
                break;

            case BoxLocation.TOP_RIGHT:
                cursor_type = Gdk.CursorType.TOP_RIGHT_CORNER;
                break;

            case BoxLocation.BOTTOM_RIGHT:
                cursor_type = Gdk.CursorType.BOTTOM_RIGHT_CORNER;
                break;

            case BoxLocation.INSIDE:
                cursor_type = Gdk.CursorType.FLEUR;
                break;

            default:
                // use Gdk.CursorType.LEFT_PTR
                break;
        }

        if (cursor_type != current_cursor_type) {
            Gdk.Cursor cursor = new Gdk.Cursor.for_display (Gdk.Display.get_default (), cursor_type);
            canvas.drawing_window.set_cursor (cursor);
            current_cursor_type = cursor_type;
        }
    }

    private int eval_radial_line (double center_x, double center_y, double bounds_x,
                                  double bounds_y, double user_x) {
        double decision_slope = (bounds_y - center_y) / (bounds_x - center_x);
        double decision_intercept = bounds_y - (decision_slope * bounds_x);

        return (int) (decision_slope * user_x + decision_intercept);
    }

    // Return the dimensions of the uncropped source photo scaled to canvas coordinates.
    private Dimensions get_photo_dimensions () {
        Dimensions photo_dims = canvas.photo.get_dimensions (Photo.Exception.CROP);
        Dimensions surface_dims = canvas.surface_dim;
        double scale_factor = double.min ((double) surface_dims.width / photo_dims.width,
                                          (double) surface_dims.height / photo_dims.height);
        scale_factor = double.min (scale_factor, 1.0);

        photo_dims = canvas.photo.get_dimensions (
                         Photo.Exception.CROP | Photo.Exception.STRAIGHTEN);

        return { (int) (photo_dims.width * scale_factor),
                 (int) (photo_dims.height * scale_factor)
               };
    }

    private bool on_canvas_manipulation (int x, int y) {
        Gdk.Rectangle scaled_pos = canvas.scaled_position;

        // scaled_crop is maintained in coordinates non-relative to photo's position on canvas ...
        // but bound tool to photo itself
        x -= scaled_pos.x;
        if (x < 0) {
            x = 0;
        } else if (x >= scaled_pos.width) {
            x = scaled_pos.width - 1;
        }

        y -= scaled_pos.y;
        if (y < 0) {
            y = 0;
        } else if (y >= scaled_pos.height) {
            y = scaled_pos.height - 1;
        }

        // need to make manipulations outside of box structure, because its methods do sanity
        // checking
        int left = scaled_crop.left;
        int top = scaled_crop.top;
        int right = scaled_crop.right;
        int bottom = scaled_crop.bottom;

        // get extra geometric information needed to enforce constraints
        int center_x = (left + right) / 2;
        int center_y = (top + bottom) / 2;

        switch (in_manipulation) {
            case BoxLocation.LEFT_SIDE:
                left = x;
                if (get_constraint_aspect_ratio () != ANY_ASPECT_RATIO) {
                    float new_height = ((float) (right - left)) / get_constraint_aspect_ratio ();
                    bottom = top + ((int) new_height);
                }
                break;

            case BoxLocation.TOP_SIDE:
                top = y;
                if (get_constraint_aspect_ratio () != ANY_ASPECT_RATIO) {
                    float new_width = ((float) (bottom - top)) * get_constraint_aspect_ratio ();
                    right = left + ((int) new_width);
                }
                break;

            case BoxLocation.RIGHT_SIDE:
                right = x;
                if (get_constraint_aspect_ratio () != ANY_ASPECT_RATIO) {
                    float new_height = ((float) (right - left)) / get_constraint_aspect_ratio ();
                    bottom = top + ((int) new_height);
                }
                break;

            case BoxLocation.BOTTOM_SIDE:
                bottom = y;
                if (get_constraint_aspect_ratio () != ANY_ASPECT_RATIO) {
                    float new_width = ((float) (bottom - top)) * get_constraint_aspect_ratio ();
                    right = left + ((int) new_width);
                }
                break;

            case BoxLocation.TOP_LEFT:
                if (get_constraint_aspect_ratio () == ANY_ASPECT_RATIO) {
                    top = y;
                    left = x;
                } else {
                    if (y < eval_radial_line (center_x, center_y, left, top, x)) {
                        top = y;
                        float new_width = ((float) (bottom - top)) * get_constraint_aspect_ratio ();
                        left = right - ((int) new_width);
                    } else {
                        left = x;
                        float new_height = ((float) (right - left)) / get_constraint_aspect_ratio ();
                        top = bottom - ((int) new_height);
                    }
                }
                break;

            case BoxLocation.BOTTOM_LEFT:
                if (get_constraint_aspect_ratio () == ANY_ASPECT_RATIO) {
                    bottom = y;
                    left = x;
                } else {
                    if (y < eval_radial_line (center_x, center_y, left, bottom, x)) {
                        left = x;
                        float new_height = ((float) (right - left)) / get_constraint_aspect_ratio ();
                        bottom = top + ((int) new_height);
                    } else {
                        bottom = y;
                        float new_width = ((float) (bottom - top)) * get_constraint_aspect_ratio ();
                        left = right - ((int) new_width);
                    }
                }
                break;

            case BoxLocation.TOP_RIGHT:
                if (get_constraint_aspect_ratio () == ANY_ASPECT_RATIO) {
                    top = y;
                    right = x;
                } else {
                    if (y < eval_radial_line (center_x, center_y, right, top, x)) {
                        top = y;
                        float new_width = ((float) (bottom - top)) * get_constraint_aspect_ratio ();
                        right = left + ((int) new_width);
                    } else {
                        right = x;
                        float new_height = ((float) (right - left)) / get_constraint_aspect_ratio ();
                        top = bottom - ((int) new_height);
                    }
                }
                break;

            case BoxLocation.BOTTOM_RIGHT:
                if (get_constraint_aspect_ratio () == ANY_ASPECT_RATIO) {
                    bottom = y;
                    right = x;
                } else {
                    if (y < eval_radial_line (center_x, center_y, right, bottom, x)) {
                        right = x;
                        float new_height = ((float) (right - left)) / get_constraint_aspect_ratio ();
                        bottom = top + ((int) new_height);
                    } else {
                        bottom = y;
                        float new_width = ((float) (bottom - top)) * get_constraint_aspect_ratio ();
                        right = left + ((int) new_width);
                    }
                }
                break;

            case BoxLocation.INSIDE:
                assert (last_grab_x >= 0);
                assert (last_grab_y >= 0);

                int delta_x = (x - last_grab_x);
                int delta_y = (y - last_grab_y);

                last_grab_x = x;
                last_grab_y = y;

                int width = right - left + 1;
                int height = bottom - top + 1;

                left += delta_x;
                top += delta_y;
                right += delta_x;
                bottom += delta_y;

                // bound crop inside of photo
                if (left < 0) {
                    left = 0;
                }

                if (top < 0) {
                    top = 0;
                }

                if (right >= scaled_pos.width) {
                    right = scaled_pos.width - 1;
                }

                if (bottom >= scaled_pos.height) {
                    bottom = scaled_pos.height - 1;
                }

                int adj_width = right - left + 1;
                int adj_height = bottom - top + 1;

                // don't let adjustments affect the size of the crop
                if (adj_width != width) {
                    if (delta_x < 0) {
                        right = left + width - 1;
                    } else {
                        left = right - width + 1;
                    }
                }

                if (adj_height != height) {
                    if (delta_y < 0) {
                        bottom = top + height - 1;
                    } else {
                        top = bottom - height + 1;
                    }
                }
                break;

            default:
                // do nothing, not even a repaint
                return false;
        }

        // Check if the mouse has gone out of bounds, and if it has, make sure that the
        // crop reticle's edges stay within the photo bounds. This bounds check works
        // differently in constrained versus unconstrained mode. In unconstrained mode,
        // we need only to bounds clamp the one or two edge(s) that are actually out-of-bounds.
        // In constrained mode however, we need to bounds clamp the entire box, because the
        // positions of edges are all interdependent (so as to enforce the aspect ratio
        // constraint).
        int width = right - left + 1;
        int height = bottom - top + 1;

        Dimensions photo_dims = get_photo_dimensions ();
        double angle;
        canvas.photo.get_straighten (out angle);

        Box new_crop;
        if (get_constraint_aspect_ratio () == ANY_ASPECT_RATIO) {
            width = right - left + 1;
            height = bottom - top + 1;

            switch (in_manipulation) {
                case BoxLocation.LEFT_SIDE:
                case BoxLocation.TOP_LEFT:
                case BoxLocation.BOTTOM_LEFT:
                    if (width < CROP_MIN_SIZE) {
                        left = right - CROP_MIN_SIZE;
                    }
                    break;

                case BoxLocation.RIGHT_SIDE:
                case BoxLocation.TOP_RIGHT:
                case BoxLocation.BOTTOM_RIGHT:
                    if (width < CROP_MIN_SIZE) {
                        right = left + CROP_MIN_SIZE;
                    }
                    break;

                default:
                    break;
            }

            switch (in_manipulation) {
                case BoxLocation.TOP_SIDE:
                case BoxLocation.TOP_LEFT:
                case BoxLocation.TOP_RIGHT:
                    if (height < CROP_MIN_SIZE) {
                        top = bottom - CROP_MIN_SIZE;
                    }
                    break;

                case BoxLocation.BOTTOM_SIDE:
                case BoxLocation.BOTTOM_LEFT:
                case BoxLocation.BOTTOM_RIGHT:
                    if (height < CROP_MIN_SIZE) {
                        bottom = top + CROP_MIN_SIZE;
                    }
                    break;

                default:
                    break;
            }

            // preliminary crop region has been chosen, now clamp it inside the
            // image as needed.

            new_crop = clamp_inside_rotated_image (
                           Box (left, top, right, bottom),
                           photo_dims.width, photo_dims.height, angle,
                           in_manipulation == BoxLocation.INSIDE);

        } else {
            // one of the constrained modes is active; revert instead of clamping so
            // that aspect ratio stays intact

            new_crop = Box (left, top, right, bottom);
            Box adjusted = clamp_inside_rotated_image (new_crop,
                           photo_dims.width, photo_dims.height, angle,
                           in_manipulation == BoxLocation.INSIDE);

            if (adjusted != new_crop || width < CROP_MIN_SIZE || height < CROP_MIN_SIZE) {
                new_crop = scaled_crop;     // revert crop move
            }
        }

        if (in_manipulation != BoxLocation.INSIDE) {
            crop_resized (new_crop);
        } else {
            crop_moved (new_crop);
        }

        // load new values
        scaled_crop = new_crop;

        if (get_constraint_aspect_ratio () == ANY_ASPECT_RATIO) {
            custom_init_width = scaled_crop.get_width ();
            custom_init_height = scaled_crop.get_height ();
            custom_aspect_ratio = ((float) custom_init_width) / ((float) custom_init_height);
        }

        return false;
    }

    private void crop_resized (Box new_crop) {
        if (scaled_crop.equals (new_crop)) {
            // no change
            return;
        }

        canvas.invalidate_area (scaled_crop);

        Box horizontal;
        bool horizontal_enlarged;
        Box vertical;
        bool vertical_enlarged;
        BoxComplements complements = scaled_crop.resized_complements (new_crop, out horizontal,
                                     out horizontal_enlarged, out vertical, out vertical_enlarged);

        // this should never happen ... this means that the operation wasn't a resize
        assert (complements != BoxComplements.NONE);

        if (complements == BoxComplements.HORIZONTAL || complements == BoxComplements.BOTH) {
            set_area_alpha (horizontal, horizontal_enlarged ? 0.0 : 0.5);
        }

        if (complements == BoxComplements.VERTICAL || complements == BoxComplements.BOTH) {
            set_area_alpha (vertical, vertical_enlarged ? 0.0 : 0.5);
        }

        paint_crop_tool (new_crop);
        canvas.invalidate_area (new_crop);
    }

    private void crop_moved (Box new_crop) {
        if (scaled_crop.equals (new_crop)) {
            // no change
            return;
        }

        canvas.invalidate_area (scaled_crop);

        set_area_alpha (scaled_crop, 0.5);
        set_area_alpha (new_crop, 0.0);


        // paint crop in new location
        paint_crop_tool (new_crop);
        canvas.invalidate_area (new_crop);
    }

    private void set_area_alpha (Box area, double alpha) {
        Cairo.Context ctx = new Cairo.Context (crop_surface);
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.set_source_rgba (0.0, 0.0, 0.0, alpha);
        ctx.rectangle (area.left, area.top, area.get_width (), area.get_height ());
        ctx.fill ();
        canvas.paint_surface_area (crop_surface, area, true);
    }

    private void paint_crop_tool (Box crop) {
        // paint rule-of-thirds lines and current dimensions if user is manipulating the crop
        if (in_manipulation != BoxLocation.OUTSIDE) {
            int one_third_x = crop.get_width () / 3;
            int one_third_y = crop.get_height () / 3;

            canvas.draw_horizontal_line (thin_white_ctx, crop.left, crop.top + one_third_y, crop.get_width ());
            canvas.draw_horizontal_line (thin_white_ctx, crop.left, crop.top + (one_third_y * 2), crop.get_width ());

            canvas.draw_vertical_line (thin_white_ctx, crop.left + one_third_x, crop.top, crop.get_height ());
            canvas.draw_vertical_line (thin_white_ctx, crop.left + (one_third_x * 2), crop.top, crop.get_height ());

            // current dimensions
            // scale screen-coordinate crop to photo's coordinate system
            Box adj_crop = scaled_crop.get_scaled_similar (
                               Dimensions.for_rectangle (canvas.scaled_position),
                               canvas.photo.get_dimensions (Photo.Exception.CROP));
            string text = adj_crop.get_width ().to_string () + "x" + adj_crop.get_height ().to_string ();
            int x = crop.left + crop.get_width () / 2;
            int y = crop.top + crop.get_height () / 2;
            canvas.draw_text (text_ctx, text, x, y);
        }

        // outer rectangle ... outer line in black, inner in white, corners fully black
        canvas.draw_box (wide_black_ctx, crop);
        canvas.draw_box (wide_white_ctx, crop.get_reduced (1));
        canvas.draw_box (wide_white_ctx, crop.get_reduced (2));
    }

}
