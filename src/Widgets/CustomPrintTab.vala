/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
*               2010-2013 Yorba Foundation
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

public class CustomPrintTab : Gtk.Fixed {
    private const int INCHES_COMBO_CHOICE = 0;
    private const int CENTIMETERS_COMBO_CHOICE = 1;

    private Gtk.RadioButton standard_size_radio = null;
    private Gtk.RadioButton custom_size_radio = null;
    private Gtk.RadioButton image_per_page_radio = null;
    private Gtk.ComboBox image_per_page_combo = null;
    private Gtk.ComboBox standard_sizes_combo = null;
    private Gtk.ComboBoxText units_combo = null;
    private Gtk.Entry custom_width_entry = null;
    private Gtk.Entry custom_height_entry = null;
    private Gtk.CheckButton aspect_ratio_check = null;
    private Gtk.CheckButton title_print_check = null;
    private Gtk.FontButton title_print_font = null;
    private Gtk.SpinButton ppi_entry;
    private Measurement local_content_width = Measurement (5.0, MeasurementUnit.INCHES);
    private Measurement local_content_height = Measurement (5.0, MeasurementUnit.INCHES);
    private bool is_text_insertion_in_progress = false;
    private PrintJob source_job;

    public CustomPrintTab (PrintJob source_job) {
        this.source_job = source_job;

        var printed_size_label = new Gtk.Label (_("Printed Image Size"));
        printed_size_label.xalign = 0;
        printed_size_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        standard_size_radio = new Gtk.RadioButton.with_mnemonic (null, _("Use a _standard size:"));
        standard_size_radio.margin_start = 12;

        custom_size_radio = new Gtk.RadioButton.with_mnemonic_from_widget (standard_size_radio, _("Use a c_ustom size:"));
        custom_size_radio.margin_start = 12;

        image_per_page_radio = new Gtk.RadioButton.with_mnemonic_from_widget (standard_size_radio, _("_Autosize:"));
        image_per_page_radio.margin_start = 12;

        var image_per_page_combo_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        foreach (PrintLayout layout in PrintLayout.get_all ()) {
            Gtk.TreeIter iter;
            image_per_page_combo_store.append (out iter);
            image_per_page_combo_store.set_value (iter, 0, layout.to_string ());
        }

        var image_per_page_combo_text_renderer = new Gtk.CellRendererText ();

        image_per_page_combo = new Gtk.ComboBox.with_model (image_per_page_combo_store);
        image_per_page_combo.pack_start (image_per_page_combo_text_renderer, true);
        image_per_page_combo.add_attribute (image_per_page_combo_text_renderer, "text", 0);

        StandardPrintSize[] standard_sizes = PrintManager.get_instance ().get_standard_sizes ();

        var standard_sizes_combo_store = new Gtk.ListStore (1, typeof (string), typeof (string));
        foreach (StandardPrintSize size in standard_sizes) {
            Gtk.TreeIter iter;
            standard_sizes_combo_store.append (out iter);
            standard_sizes_combo_store.set_value (iter, 0, size.name);
        }

        var standard_sizes_combo_text_renderer = new Gtk.CellRendererText ();

        standard_sizes_combo = new Gtk.ComboBox.with_model (standard_sizes_combo_store);
        standard_sizes_combo.pack_start (standard_sizes_combo_text_renderer, true);
        standard_sizes_combo.add_attribute (standard_sizes_combo_text_renderer, "text", 0);
        standard_sizes_combo.set_row_separator_func (standard_sizes_combo_separator_func);

        custom_width_entry = new Gtk.Entry ();
        var mult_label = new Gtk.Label ("×");
        custom_height_entry = new Gtk.Entry ();

        units_combo = new Gtk.ComboBoxText ();
        units_combo.append_text (_("in."));
        units_combo.append_text (_("cm"));
        units_combo.set_active (0);

        var custom_grid = new Gtk.Grid ();
        custom_grid.column_spacing = 3;
        custom_grid.add (custom_width_entry);
        custom_grid.add (mult_label);
        custom_grid.add (custom_height_entry);
        custom_grid.add (units_combo);

        aspect_ratio_check = new Gtk.CheckButton.with_mnemonic (_("_Match photo aspect ratio"));

        var titles_label = new Gtk.Label (_("Titles"));
        titles_label.xalign = 0;
        titles_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        title_print_check = new Gtk.CheckButton.with_mnemonic (_("Print image _title"));
        title_print_check.margin_start = 12;

        title_print_font = new Gtk.FontButton ();
        title_print_font.use_font = true;

        var resolution_label = new Gtk.Label (_("Pixel Resolution"));
        resolution_label.xalign = 0;
        resolution_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        ppi_entry = new Gtk.SpinButton.with_range (PrintSettings.MIN_CONTENT_PPI, PrintSettings.MAX_CONTENT_PPI, 100);
        ppi_entry.hexpand = true;

        var ppi_label = new Gtk.Label (_("_Output photo at:"));
        ppi_label.margin_start = 12;
        ppi_label.mnemonic_widget = ppi_entry;
        ppi_label.use_underline = true;
        ppi_label.xalign = 1;

        var unit_label = new Gtk.Label (_("pixels per inch"));
        unit_label.xalign = 0;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.row_spacing = 12;
        grid.margin = 12;
        grid.attach (printed_size_label, 0, 0, 3, 1);
        grid.attach (standard_size_radio, 0, 1);
        grid.attach (standard_sizes_combo, 1, 1, 2, 1);
        grid.attach (custom_size_radio, 0, 2);
        grid.attach (custom_grid, 1, 2, 2, 1);
        grid.attach (aspect_ratio_check, 1, 3, 2, 1);
        grid.attach (image_per_page_radio, 0, 4);
        grid.attach (image_per_page_combo, 1, 4, 2, 1);
        grid.attach (titles_label, 0, 5, 3, 1);
        grid.attach (title_print_check, 0, 6);
        grid.attach (title_print_font, 1, 6, 2, 1);
        grid.attach (resolution_label, 0, 7, 3, 1);
        grid.attach (ppi_label, 0, 8);
        grid.attach (ppi_entry, 1, 8);
        grid.attach (unit_label, 2, 8);

        add (grid);

        standard_size_radio.clicked.connect (on_radio_group_click);
        custom_size_radio.clicked.connect (on_radio_group_click);
        image_per_page_radio.clicked.connect (on_radio_group_click);
        custom_width_entry.insert_text.connect (on_entry_insert_text);
        custom_width_entry.focus_out_event.connect (on_width_entry_focus_out);
        custom_height_entry.insert_text.connect (on_entry_insert_text);
        custom_height_entry.focus_out_event.connect (on_height_entry_focus_out);
        units_combo.changed.connect (on_units_combo_changed);
        ppi_entry.insert_text.connect (on_ppi_entry_insert_text);

        sync_state_from_job (source_job);

        show_all ();

        /* connect this signal after state is sync'd */
        aspect_ratio_check.clicked.connect (on_aspect_ratio_check_clicked);
    }

    private void on_aspect_ratio_check_clicked () {
        if (aspect_ratio_check.get_active ()) {
            local_content_width =
                Measurement (local_content_height.value * source_job.get_source_aspect_ratio (),
                             local_content_height.unit);
            custom_width_entry.set_text (format_measurement (local_content_width));
        }
    }

    private bool on_width_entry_focus_out (Gdk.EventFocus event) {
        if (custom_width_entry.get_text () == (format_measurement_as (local_content_width,
                                              get_user_unit_choice ())))
            return false;

        Measurement new_width = get_width_entry_value ();
        Measurement min_width = source_job.get_local_settings ().get_minimum_content_dimension ();
        Measurement max_width = source_job.get_local_settings ().get_maximum_content_dimension ();

        if (new_width.is_less_than (min_width) || new_width.is_greater_than (max_width)) {
            custom_width_entry.set_text (format_measurement (local_content_width));
            return false;
        }

        if (is_match_aspect_ratio_enabled ()) {
            Measurement new_height =
                Measurement (new_width.value / source_job.get_source_aspect_ratio (),
                             new_width.unit);
            local_content_height = new_height;
            custom_height_entry.set_text (format_measurement (new_height));
        }

        local_content_width = new_width;
        custom_width_entry.set_text (format_measurement (new_width));
        return false;
    }

    private string format_measurement (Measurement measurement) {
        return "%.2f".printf (measurement.value);
    }

    private string format_measurement_as (Measurement measurement, MeasurementUnit to_unit) {
        Measurement converted_measurement = (measurement.unit == to_unit) ? measurement :
                                            measurement.convert_to (to_unit);
        return format_measurement (converted_measurement);
    }

    private void on_ppi_entry_insert_text (Gtk.Editable editable, string text, int length,
                                           ref int position) {
        Gtk.Entry sender = (Gtk.Entry) editable;

        if (is_text_insertion_in_progress)
            return;

        is_text_insertion_in_progress = true;

        if (length == -1)
            length = (int) text.length;

        string new_text = "";
        for (int ctr = 0; ctr < length; ctr++) {
            if (text[ctr].isdigit ())
                new_text += ((char) text[ctr]).to_string ();
        }

        if (new_text.length > 0)
            sender.insert_text (new_text, (int) new_text.length, ref position);

        Signal.stop_emission_by_name (sender, "insert-text");

        is_text_insertion_in_progress = false;
    }

    private bool on_height_entry_focus_out (Gdk.EventFocus event) {
        if (custom_height_entry.get_text () == (format_measurement_as (local_content_height,
                                               get_user_unit_choice ())))
            return false;

        Measurement new_height = get_height_entry_value ();
        Measurement min_height = source_job.get_local_settings ().get_minimum_content_dimension ();
        Measurement max_height = source_job.get_local_settings ().get_maximum_content_dimension ();

        if (new_height.is_less_than (min_height) || new_height.is_greater_than (max_height)) {
            custom_height_entry.set_text (format_measurement (local_content_height));
            return false;
        }

        if (is_match_aspect_ratio_enabled ()) {
            Measurement new_width =
                Measurement (new_height.value * source_job.get_source_aspect_ratio (),
                             new_height.unit);
            local_content_width = new_width;
            custom_width_entry.set_text (format_measurement (new_width));
        }

        local_content_height = new_height;
        custom_height_entry.set_text (format_measurement (new_height));
        return false;
    }

    private MeasurementUnit get_user_unit_choice () {
        if (units_combo.get_active () == INCHES_COMBO_CHOICE) {
            return MeasurementUnit.INCHES;
        } else if (units_combo.get_active () == CENTIMETERS_COMBO_CHOICE) {
            return MeasurementUnit.CENTIMETERS;
        } else {
            error ("unknown unit combo box choice");
        }
    }

    private void set_user_unit_choice (MeasurementUnit unit) {
        if (unit == MeasurementUnit.INCHES) {
            units_combo.set_active (INCHES_COMBO_CHOICE);
        } else if (unit == MeasurementUnit.CENTIMETERS) {
            units_combo.set_active (CENTIMETERS_COMBO_CHOICE);
        } else {
            error ("unknown MeasurementUnit enumeration");
        }
    }

    private Measurement get_width_entry_value () {
        return Measurement (double.parse (custom_width_entry.get_text ()), get_user_unit_choice ());
    }

    private Measurement get_height_entry_value () {
        return Measurement (double.parse (custom_height_entry.get_text ()), get_user_unit_choice ());
    }

    private void on_entry_insert_text (Gtk.Editable editable, string text, int length,
                                       ref int position) {

        Gtk.Entry sender = (Gtk.Entry) editable;

        if (is_text_insertion_in_progress)
            return;

        is_text_insertion_in_progress = true;

        if (length == -1)
            length = (int) text.length;

        string decimal_point = Intl.localeconv ().decimal_point;
        bool contains_decimal_point = sender.get_text ().contains (decimal_point);

        string new_text = "";
        for (int ctr = 0; ctr < length; ctr++) {
            if (text[ctr].isdigit ()) {
                new_text += ((char) text[ctr]).to_string ();
            } else if ((!contains_decimal_point) && (text[ctr] == decimal_point[0])) {
                new_text += ((char) text[ctr]).to_string ();
            }
        }

        if (new_text.length > 0)
            sender.insert_text (new_text, (int) new_text.length, ref position);

        Signal.stop_emission_by_name (sender, "insert-text");

        is_text_insertion_in_progress = false;
    }

    private void sync_state_from_job (PrintJob job) {
        assert (job.get_local_settings ().get_content_width ().unit ==
                job.get_local_settings ().get_content_height ().unit);

        Measurement constrained_width = job.get_local_settings ().get_content_width ();
        if (job.get_local_settings ().is_match_aspect_ratio_enabled ())
            constrained_width = Measurement (job.get_local_settings ().get_content_height ().value *
                                             job.get_source_aspect_ratio (), job.get_local_settings ().get_content_height ().unit);
        set_content_width (constrained_width);
        set_content_height (job.get_local_settings ().get_content_height ());
        set_content_layout (job.get_local_settings ().get_content_layout ());
        ppi_entry.value = job.get_local_settings ().get_content_ppi ();
        set_image_per_page_selection (job.get_local_settings ().get_image_per_page_selection ());
        set_size_selection (job.get_local_settings ().get_size_selection ());
        set_match_aspect_ratio_enabled (job.get_local_settings ().is_match_aspect_ratio_enabled ());
        set_print_titles_enabled (job.get_local_settings ().is_print_titles_enabled ());
        set_print_titles_font (job.get_local_settings ().get_print_titles_font ());
    }

    private void on_radio_group_click (Gtk.Button b) {
        Gtk.RadioButton sender = (Gtk.RadioButton) b;

        if (sender == standard_size_radio) {
            set_content_layout_control_state (ContentLayout.STANDARD_SIZE);
            standard_sizes_combo.grab_focus ();
        } else if (sender == custom_size_radio) {
            set_content_layout_control_state (ContentLayout.CUSTOM_SIZE);
            custom_height_entry.grab_focus ();
        } else if (sender == image_per_page_radio) {
            set_content_layout_control_state (ContentLayout.IMAGE_PER_PAGE);
        }
    }

    private void on_units_combo_changed () {
        custom_height_entry.set_text (format_measurement_as (local_content_height,
                                      get_user_unit_choice ()));
        custom_width_entry.set_text (format_measurement_as (local_content_width,
                                     get_user_unit_choice ()));
    }

    private void set_content_layout_control_state (ContentLayout layout) {
        switch (layout) {
        case ContentLayout.STANDARD_SIZE:
            standard_sizes_combo.set_sensitive (true);
            units_combo.set_sensitive (false);
            custom_width_entry.set_sensitive (false);
            custom_height_entry.set_sensitive (false);
            aspect_ratio_check.set_sensitive (false);
            image_per_page_combo.set_sensitive (false);
            break;

        case ContentLayout.CUSTOM_SIZE:
            standard_sizes_combo.set_sensitive (false);
            units_combo.set_sensitive (true);
            custom_width_entry.set_sensitive (true);
            custom_height_entry.set_sensitive (true);
            aspect_ratio_check.set_sensitive (true);
            image_per_page_combo.set_sensitive (false);
            break;

        case ContentLayout.IMAGE_PER_PAGE:
            standard_sizes_combo.set_sensitive (false);
            units_combo.set_sensitive (false);
            custom_width_entry.set_sensitive (false);
            custom_height_entry.set_sensitive (false);
            aspect_ratio_check.set_sensitive (false);
            image_per_page_combo.set_sensitive (true);
            break;

        default:
            error ("unknown ContentLayout enumeration value");
        }
    }

    private static bool standard_sizes_combo_separator_func (Gtk.TreeModel model,
            Gtk.TreeIter iter) {
        Value val;
        model.get_value (iter, 0, out val);

        return (val.dup_string () == "-");
    }

    private void set_content_layout (ContentLayout content_layout) {
        set_content_layout_control_state (content_layout);
        switch (content_layout) {
        case ContentLayout.STANDARD_SIZE:
            standard_size_radio.set_active (true);
            break;

        case ContentLayout.CUSTOM_SIZE:
            custom_size_radio.set_active (true);
            break;

        case ContentLayout.IMAGE_PER_PAGE:
            image_per_page_radio.set_active (true);
            break;

        default:
            error ("unknown ContentLayout enumeration value");
        }
    }

    private ContentLayout get_content_layout () {
        if (standard_size_radio.get_active ())
            return ContentLayout.STANDARD_SIZE;
        if (custom_size_radio.get_active ())
            return ContentLayout.CUSTOM_SIZE;
        if (image_per_page_radio.get_active ())
            return ContentLayout.IMAGE_PER_PAGE;

        error ("inconsistent content layout radio button group state");
    }

    private void set_content_width (Measurement content_width) {
        if (content_width.unit != local_content_height.unit) {
            set_user_unit_choice (content_width.unit);
            local_content_height = local_content_height.convert_to (content_width.unit);
            custom_height_entry.set_text (format_measurement (local_content_height));
        }
        local_content_width = content_width;
        custom_width_entry.set_text (format_measurement (content_width));
    }

    private Measurement get_content_width () {
        return local_content_width;
    }

    private void set_content_height (Measurement content_height) {
        if (content_height.unit != local_content_width.unit) {
            set_user_unit_choice (content_height.unit);
            local_content_width = local_content_width.convert_to (content_height.unit);
            custom_width_entry.set_text (format_measurement (local_content_width));
        }
        local_content_height = content_height;
        custom_height_entry.set_text (format_measurement (content_height));
    }

    private Measurement get_content_height () {
        return local_content_height;
    }

    private void set_image_per_page_selection (int image_per_page) {
        image_per_page_combo.set_active (image_per_page);
    }

    private int get_image_per_page_selection () {
        return image_per_page_combo.get_active ();
    }

    private void set_size_selection (int size_selection) {
        standard_sizes_combo.set_active (size_selection);
    }

    private int get_size_selection () {
        return standard_sizes_combo.get_active ();
    }

    private void set_match_aspect_ratio_enabled (bool enable_state) {
        aspect_ratio_check.set_active (enable_state);
    }

    private void set_print_titles_enabled (bool print_titles) {
        title_print_check.set_active (print_titles);
    }

    private void set_print_titles_font (string fontname) {
        title_print_font.font = fontname;
    }


    private bool is_match_aspect_ratio_enabled () {
        return aspect_ratio_check.get_active ();
    }

    private bool is_print_titles_enabled () {
        return title_print_check.get_active ();
    }

    private string get_print_titles_font () {
        return title_print_font.font;
    }

    public PrintJob get_source_job () {
        return source_job;
    }

    public PrintSettings get_local_settings () {
        PrintSettings result = new PrintSettings ();

        result.set_content_width (get_content_width ());
        result.set_content_height (get_content_height ());
        result.set_content_layout (get_content_layout ());
        result.set_content_ppi ((int) ppi_entry.value);
        result.set_image_per_page_selection (get_image_per_page_selection ());
        result.set_size_selection (get_size_selection ());
        result.set_match_aspect_ratio_enabled (is_match_aspect_ratio_enabled ());
        result.set_print_titles_enabled (is_print_titles_enabled ());
        result.set_print_titles_font (get_print_titles_font ());

        return result;
    }
}
