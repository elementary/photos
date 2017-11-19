/*
* Copyright (c) 2010-2013 Yorba Foundation
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

public enum ContentLayout {
    STANDARD_SIZE,
    CUSTOM_SIZE,
    IMAGE_PER_PAGE
}

public class PrintSettings {
    public const int MIN_CONTENT_PPI = 72;    /* 72 ppi is the pixel resolution of a 14" VGA
                                                 display -- it's standard for historical reasons */
    public const int MAX_CONTENT_PPI = 1200;  /* 1200 ppi is appropriate for a 3600 dpi imagesetter
                                                 used to produce photographic plates for commercial
                                                 printing -- it's the highest pixel resolution
                                                 commonly used */
    private ContentLayout content_layout;
    private Measurement content_width;
    private Measurement content_height;
    private int content_ppi;
    private int image_per_page_selection;
    private int size_selection;
    private bool match_aspect_ratio;
    private bool print_titles;
    private string print_titles_font;
    private GLib.Settings print_settings;

    public PrintSettings () {
        print_settings = new GLib.Settings (GSettingsConfigurationEngine.PRINTING_SCHEMA_NAME);

        var units = (MeasurementUnit) print_settings.get_int ("content-units") - 1;
        content_width = Measurement (print_settings.get_double ("content-width"), units);
        content_height = Measurement (print_settings.get_double ("content-height"), units);
        size_selection = print_settings.get_int ("size-selection") - 1;
        content_layout = (ContentLayout) (print_settings.get_int ("content-layout") - 1);
        match_aspect_ratio = print_settings.get_boolean ("match-aspect-ratio");
        print_titles = print_settings.get_boolean ("print-titles");
        print_titles_font = print_settings.get_string ("titles-font");
        image_per_page_selection = print_settings.get_int ("images-per-page") - 1;
        content_ppi = print_settings.get_int ("content-ppi");
    }

    public void save () {
        print_settings.set_int ("content-units", content_width.unit + 1);
        print_settings.set_double ("content-width", content_width.value);
        print_settings.set_double ("content-height", content_height.value);
        print_settings.set_int ("size-selection", size_selection + 1);
        print_settings.set_int ("content-layout", content_layout + 1);
        print_settings.set_boolean ("match-aspect-ratio", match_aspect_ratio);
        print_settings.set_boolean ("print-titles", print_titles);
        print_settings.set_string ("titles-font", print_titles_font);
        print_settings.set_int ("images-per-page", image_per_page_selection + 1);
        print_settings.set_int ("content-ppi", content_ppi);
    }


    public Measurement get_content_width () {
        switch (get_content_layout ()) {
        case ContentLayout.STANDARD_SIZE:
        case ContentLayout.IMAGE_PER_PAGE:
            return (PrintManager.get_instance ().get_standard_sizes ()[
                        get_size_selection ()]).width;

        case ContentLayout.CUSTOM_SIZE:
            return content_width;

        default:
            error ("unknown ContentLayout enumeration value");
        }
    }

    public Measurement get_content_height () {
        switch (get_content_layout ()) {
        case ContentLayout.STANDARD_SIZE:
        case ContentLayout.IMAGE_PER_PAGE:
            return (PrintManager.get_instance ().get_standard_sizes ()[
                        get_size_selection ()]).height;

        case ContentLayout.CUSTOM_SIZE:
            return content_height;

        default:
            error ("unknown ContentLayout enumeration value");
        }
    }

    public Measurement get_minimum_content_dimension () {
        return Measurement (0.5, MeasurementUnit.INCHES);
    }

    public Measurement get_maximum_content_dimension () {
        return Measurement (30, MeasurementUnit.INCHES);
    }

    public bool is_match_aspect_ratio_enabled () {
        return match_aspect_ratio;
    }

    public bool is_print_titles_enabled () {
        return print_titles;
    }

    public int get_content_ppi () {
        return content_ppi;
    }

    public int get_image_per_page_selection () {
        return image_per_page_selection;
    }

    public int get_size_selection () {
        return size_selection;
    }

    public ContentLayout get_content_layout () {
        return content_layout;
    }

    public void set_content_layout (ContentLayout content_layout) {
        this.content_layout = content_layout;
    }

    public void set_content_width (Measurement content_width) {
        this.content_width = content_width;
    }

    public void set_content_height (Measurement content_height) {
        this.content_height = content_height;
    }

    public void set_content_ppi (int content_ppi) {
        this.content_ppi = content_ppi;
    }

    public void set_image_per_page_selection (int image_per_page_selection) {
        this.image_per_page_selection = image_per_page_selection;
    }

    public void set_size_selection (int size_selection) {
        this.size_selection = size_selection;
    }

    public void set_match_aspect_ratio_enabled (bool enable_state) {
        this.match_aspect_ratio = enable_state;
    }

    public void set_print_titles_enabled (bool print_titles) {
        this.print_titles = print_titles;
    }

    public void set_print_titles_font (string fontname) {
        this.print_titles_font = fontname;
    }

    public string get_print_titles_font () {
        return this.print_titles_font;
    }
}

/* we define our own measurement enum instead of using the Gtk.Unit enum
   provided by Gtk+ 2.0 because Gtk.Unit doesn't define a CENTIMETERS
   constant (thout it does define an MM for millimeters). This is
   unfortunate, because in metric countries people like to think about
   paper sizes for printing in CM not MM. so, to avoid having to
   multiply and divide everything by 10 (which is error prone) to convert
   from CM to MM and vice-versa whenever we read or write measurements, we
   eschew Gtk.Unit and substitute our own */
public enum MeasurementUnit {
    INCHES,
    CENTIMETERS
}

public struct Measurement {
    private const double CENTIMETERS_PER_INCH = 2.54;
    private const double INCHES_PER_CENTIMETER = (1.0 / 2.54);

    public double value;
    public MeasurementUnit unit;

    public Measurement (double value, MeasurementUnit unit) {
        this.value = value;
        this.unit = unit;
    }

    public Measurement convert_to (MeasurementUnit to_unit) {
        if (unit == to_unit)
            return this;

        if (to_unit == MeasurementUnit.INCHES) {
            return Measurement (value * INCHES_PER_CENTIMETER, MeasurementUnit.INCHES);
        } else if (to_unit == MeasurementUnit.CENTIMETERS) {
            return Measurement (value * CENTIMETERS_PER_INCH, MeasurementUnit.CENTIMETERS);
        } else {
            error ("unrecognized unit");
        }
    }

    public bool is_less_than (Measurement rhs) {
        Measurement converted_rhs = (unit == rhs.unit) ? rhs : rhs.convert_to (unit);
        return (value < converted_rhs.value);
    }

    public bool is_greater_than (Measurement rhs) {
        Measurement converted_rhs = (unit == rhs.unit) ? rhs : rhs.convert_to (unit);
        return (value > converted_rhs.value);
    }
}

private enum PrintLayout {
    ENTIRE_PAGE,
    TWO_PER_PAGE,
    FOUR_PER_PAGE,
    SIX_PER_PAGE,
    EIGHT_PER_PAGE,
    SIXTEEN_PER_PAGE,
    THIRTY_TWO_PER_PAGE;

    public static PrintLayout[] get_all () {
        return {
            ENTIRE_PAGE,
            TWO_PER_PAGE,
            FOUR_PER_PAGE,
            SIX_PER_PAGE,
            EIGHT_PER_PAGE,
            SIXTEEN_PER_PAGE,
            THIRTY_TWO_PER_PAGE
        };
    }

    public int get_per_page () {
        int[] per_page = { 1, 2, 4, 6, 8, 16, 32 };

        return per_page[this];
    }

    public int get_x () {
        int[] x = { 1, 1, 2, 2, 2, 4, 4 };

        return x[this];
    }

    public int get_y () {
        int[] y = { 1, 2, 2, 3, 4, 4, 8 };

        return y[this];
    }

    public string to_string () {
        string[] labels = {
            _ ("Fill the entire page"),
            _ ("2 images per page"),
            _ ("4 images per page"),
            _ ("6 images per page"),
            _ ("8 images per page"),
            _ ("16 images per page"),
            _ ("32 images per page")
        };

        return labels[this];
    }
}

public class CustomPrintTab : Gtk.Fixed {
    private const int INCHES_COMBO_CHOICE = 0;
    private const int CENTIMETERS_COMBO_CHOICE = 1;

    private Gtk.Box custom_image_settings_pane = null;
    private Gtk.RadioButton standard_size_radio = null;
    private Gtk.RadioButton custom_size_radio = null;
    private Gtk.RadioButton image_per_page_radio = null;
    private Gtk.ComboBox image_per_page_combo = null;
    private Gtk.ComboBox standard_sizes_combo = null;
    private Gtk.ComboBoxText units_combo = null;
    private Gtk.Entry custom_width_entry = null;
    private Gtk.Entry custom_height_entry = null;
    private Gtk.Entry ppi_entry;
    private Gtk.CheckButton aspect_ratio_check = null;
    private Gtk.CheckButton title_print_check = null;
    private Gtk.FontButton title_print_font = null;
    private Measurement local_content_width = Measurement (5.0, MeasurementUnit.INCHES);
    private Measurement local_content_height = Measurement (5.0, MeasurementUnit.INCHES);
    private int local_content_ppi;
    private bool is_text_insertion_in_progress = false;
    private PrintJob source_job;

    public CustomPrintTab (PrintJob source_job) {
        this.source_job = source_job;
        Gtk.Builder builder = AppWindow.create_builder ();

        // an enclosing box for every widget on this tab...
        custom_image_settings_pane = builder.get_object ("box_ImgSettingsPane") as Gtk.Box;

        standard_size_radio = builder.get_object ("radio_UseStandardSize") as Gtk.RadioButton;
        standard_size_radio.clicked.connect (on_radio_group_click);

        custom_size_radio = builder.get_object ("radio_UseCustomSize") as Gtk.RadioButton;
        custom_size_radio.clicked.connect (on_radio_group_click);

        image_per_page_radio = builder.get_object ("radio_Autosize") as Gtk.RadioButton;
        image_per_page_radio.clicked.connect (on_radio_group_click);

        image_per_page_combo = builder.get_object ("combo_Autosize") as Gtk.ComboBox;
        Gtk.CellRendererText image_per_page_combo_text_renderer =
            new Gtk.CellRendererText ();
        image_per_page_combo.pack_start (image_per_page_combo_text_renderer, true);
        image_per_page_combo.add_attribute (image_per_page_combo_text_renderer,
                                            "text", 0);
        Gtk.ListStore image_per_page_combo_store = new Gtk.ListStore (2, typeof (string),
                typeof (string));
        foreach (PrintLayout layout in PrintLayout.get_all ()) {
            Gtk.TreeIter iter;
            image_per_page_combo_store.append (out iter);
            image_per_page_combo_store.set_value (iter, 0, layout.to_string ());
        }
        image_per_page_combo.set_model (image_per_page_combo_store);

        StandardPrintSize[] standard_sizes = PrintManager.get_instance ().get_standard_sizes ();
        standard_sizes_combo = builder.get_object ("combo_StdSizes") as Gtk.ComboBox;
        Gtk.CellRendererText standard_sizes_combo_text_renderer =
            new Gtk.CellRendererText ();
        standard_sizes_combo.pack_start (standard_sizes_combo_text_renderer, true);
        standard_sizes_combo.add_attribute (standard_sizes_combo_text_renderer,
                                            "text", 0);
        standard_sizes_combo.set_row_separator_func (standard_sizes_combo_separator_func);
        Gtk.ListStore standard_sizes_combo_store = new Gtk.ListStore (1, typeof (string),
                typeof (string));
        foreach (StandardPrintSize size in standard_sizes) {
            Gtk.TreeIter iter;
            standard_sizes_combo_store.append (out iter);
            standard_sizes_combo_store.set_value (iter, 0, size.name);
        }
        standard_sizes_combo.set_model (standard_sizes_combo_store);

        custom_width_entry = builder.get_object ("entry_CustomWidth") as Gtk.Entry;
        custom_width_entry.insert_text.connect (on_entry_insert_text);
        custom_width_entry.focus_out_event.connect (on_width_entry_focus_out);

        custom_height_entry = builder.get_object ("entry_CustomHeight") as Gtk.Entry;
        custom_height_entry.insert_text.connect (on_entry_insert_text);
        custom_height_entry.focus_out_event.connect (on_height_entry_focus_out);

        units_combo = builder.get_object ("combo_Units") as Gtk.ComboBoxText;
        units_combo.append_text (_ ("in."));
        units_combo.append_text (_ ("cm"));
        units_combo.set_active (0);
        units_combo.changed.connect (on_units_combo_changed);

        aspect_ratio_check = builder.get_object ("check_MatchAspectRatio") as Gtk.CheckButton;
        title_print_check = builder.get_object ("check_PrintImageTitle") as Gtk.CheckButton;
        title_print_font = builder.get_object ("fntbn_TitleFont") as Gtk.FontButton;

        ppi_entry = builder.get_object ("entry_PixelsPerInch") as Gtk.Entry;
        ppi_entry.insert_text.connect (on_ppi_entry_insert_text);
        ppi_entry.focus_out_event.connect (on_ppi_entry_focus_out);

        this.add (custom_image_settings_pane);

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

    private bool on_ppi_entry_focus_out (Gdk.EventFocus event) {
        set_content_ppi (int.parse (ppi_entry.get_text ()));
        return false;
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
        set_content_ppi (job.get_local_settings ().get_content_ppi ());
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

    private void set_content_ppi (int content_ppi) {
        local_content_ppi = content_ppi.clamp (PrintSettings.MIN_CONTENT_PPI,
                                               PrintSettings.MAX_CONTENT_PPI);

        ppi_entry.set_text ("%d".printf (local_content_ppi));
    }

    private int get_content_ppi () {
        return local_content_ppi;
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
        title_print_font.set_font_name (fontname);
    }


    private bool is_match_aspect_ratio_enabled () {
        return aspect_ratio_check.get_active ();
    }

    private bool is_print_titles_enabled () {
        return title_print_check.get_active ();
    }

    private string get_print_titles_font () {
        return title_print_font.get_font_name ();
    }

    public PrintJob get_source_job () {
        return source_job;
    }

    public PrintSettings get_local_settings () {
        PrintSettings result = new PrintSettings ();

        result.set_content_width (get_content_width ());
        result.set_content_height (get_content_height ());
        result.set_content_layout (get_content_layout ());
        result.set_content_ppi (get_content_ppi ());
        result.set_image_per_page_selection (get_image_per_page_selection ());
        result.set_size_selection (get_size_selection ());
        result.set_match_aspect_ratio_enabled (is_match_aspect_ratio_enabled ());
        result.set_print_titles_enabled (is_print_titles_enabled ());
        result.set_print_titles_font (get_print_titles_font ());

        return result;
    }
}

public class PrintJob : Gtk.PrintOperation {
    private PrintSettings settings;
    private Gee.ArrayList<Photo> photos = new Gee.ArrayList<Photo> ();

    public PrintJob (Gee.Collection<Photo> to_print) {
        this.settings = PrintManager.get_instance ().get_global_settings ();
        photos.add_all (to_print);

        set_embed_page_setup (true);
        double photo_aspect_ratio =  photos[0].get_dimensions ().get_aspect_ratio ();
        if (photo_aspect_ratio < 1.0)
            photo_aspect_ratio = 1.0 / photo_aspect_ratio;
    }

    public Gee.List<Photo> get_photos () {
        return photos;
    }

    public Photo get_source_photo () {
        return photos[0];
    }

    public double get_source_aspect_ratio () {
        double aspect_ratio = photos[0].get_dimensions ().get_aspect_ratio ();
        return (aspect_ratio < 1.0) ? (1.0 / aspect_ratio) : aspect_ratio;
    }

    public PrintSettings get_local_settings () {
        return settings;
    }

    public void set_local_settings (PrintSettings settings) {
        this.settings = settings;
    }
}

public class StandardPrintSize {
    public StandardPrintSize (string name, Measurement width, Measurement height) {
        this.name = name;
        this.width = width;
        this.height = height;
    }

    public string name;
    public Measurement width;
    public Measurement height;
}

public class PrintManager {
    private const double IMAGE_DISTANCE = 0.24;

    private static PrintManager instance = null;

    private PrintSettings settings;
    private Gtk.PageSetup user_page_setup;
    private CustomPrintTab custom_tab;
    private ProgressDialog? progress_dialog = null;
    private Cancellable? cancellable = null;

    private PrintManager () {
        user_page_setup = new Gtk.PageSetup ();
        settings = new PrintSettings ();
    }

    public StandardPrintSize[] get_standard_sizes () {
        StandardPrintSize[] result = new StandardPrintSize[0];

        result += new StandardPrintSize (_ ("Wallet (2 x 3 in.)"),
                                         Measurement (3, MeasurementUnit.INCHES),
                                         Measurement (2, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("Notecard (3 x 5 in.)"),
                                         Measurement (5, MeasurementUnit.INCHES),
                                         Measurement (3, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("4 x 6 in."),
                                         Measurement (6, MeasurementUnit.INCHES),
                                         Measurement (4, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("5 x 7 in."),
                                         Measurement (7, MeasurementUnit.INCHES),
                                         Measurement (5, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("8 x 10 in."),
                                         Measurement (10, MeasurementUnit.INCHES),
                                         Measurement (8, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("11 x 14 in."),
                                         Measurement (14, MeasurementUnit.INCHES),
                                         Measurement (11, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("16 x 20 in."),
                                         Measurement (20, MeasurementUnit.INCHES),
                                         Measurement (16, MeasurementUnit.INCHES));
        result += new StandardPrintSize (("-"),
                                         Measurement (0, MeasurementUnit.INCHES),
                                         Measurement (0, MeasurementUnit.INCHES));
        result += new StandardPrintSize (_ ("Metric Wallet (9 x 13 cm)"),
                                         Measurement (13, MeasurementUnit.CENTIMETERS),
                                         Measurement (9, MeasurementUnit.CENTIMETERS));
        result += new StandardPrintSize (_ ("Postcard (10 x 15 cm)"),
                                         Measurement (15, MeasurementUnit.CENTIMETERS),
                                         Measurement (10, MeasurementUnit.CENTIMETERS));
        result += new StandardPrintSize (_ ("13 x 18 cm"),
                                         Measurement (18, MeasurementUnit.CENTIMETERS),
                                         Measurement (13, MeasurementUnit.CENTIMETERS));
        result += new StandardPrintSize (_ ("18 x 24 cm"),
                                         Measurement (24, MeasurementUnit.CENTIMETERS),
                                         Measurement (18, MeasurementUnit.CENTIMETERS));
        result += new StandardPrintSize (_ ("20 x 30 cm"),
                                         Measurement (30, MeasurementUnit.CENTIMETERS),
                                         Measurement (20, MeasurementUnit.CENTIMETERS));
        result += new StandardPrintSize (_ ("24 x 40 cm"),
                                         Measurement (40, MeasurementUnit.CENTIMETERS),
                                         Measurement (24, MeasurementUnit.CENTIMETERS));
        result += new StandardPrintSize (_ ("30 x 40 cm"),
                                         Measurement (40, MeasurementUnit.CENTIMETERS),
                                         Measurement (30, MeasurementUnit.CENTIMETERS));

        return result;
    }

    public static PrintManager get_instance () {
        if (instance == null)
            instance = new PrintManager ();

        return instance;
    }

    public void spool_photo (Gee.Collection<Photo> to_print) {
        PrintJob job = new PrintJob (to_print);
        job.set_custom_tab_label (_ ("Image Settings"));
        job.set_unit (Gtk.Unit.INCH);
        job.set_n_pages (1);
        job.set_job_name (job.get_source_photo ().get_name ());
        job.set_default_page_setup (user_page_setup);
        job.begin_print.connect (on_begin_print);
        job.draw_page.connect (on_draw_page);
        job.create_custom_widget.connect (on_create_custom_widget);
        job.status_changed.connect (on_status_changed);

        AppWindow.get_instance ().set_busy_cursor ();

        cancellable = new Cancellable ();
        progress_dialog = new ProgressDialog (AppWindow.get_instance (), _ ("Printing..."), cancellable);

        string? err_msg = null;
        try {
            Gtk.PrintOperationResult result = job.run (Gtk.PrintOperationAction.PRINT_DIALOG,
                                              AppWindow.get_instance ());
            if (result == Gtk.PrintOperationResult.APPLY)
                user_page_setup = job.get_default_page_setup ();
        } catch (Error e) {
            job.cancel ();
            err_msg = e.message;
        }

        progress_dialog.close ();
        progress_dialog = null;
        cancellable = null;

        AppWindow.get_instance ().set_normal_cursor ();

        if (err_msg != null)
            AppWindow.error_message (_ ("Unable to print photo:\n\n%s").printf (err_msg));
    }

    private void on_begin_print (Gtk.PrintOperation emitting_object, Gtk.PrintContext job_context) {
        debug ("on_begin_print");

        PrintJob job = (PrintJob) emitting_object;

        // cancel () can only be called from "begin-print", "paginate", or "draw-page"
        if (cancellable != null && cancellable.is_cancelled ()) {
            job.cancel ();

            return;
        }

        Gee.List<Photo> photos = job.get_photos ();
        if (job.get_local_settings ().get_content_layout () == ContentLayout.IMAGE_PER_PAGE) {
            PrintLayout layout = (PrintLayout) job.get_local_settings ().get_image_per_page_selection ();
            job.set_n_pages ((int) Math.ceil ((double) photos.size / (double) layout.get_per_page ()));
        } else {
            job.set_n_pages (photos.size);
        }

        spin_event_loop ();
    }

    private void on_status_changed (Gtk.PrintOperation job) {
        debug ("on_status_changed: %s", job.get_status_string ());

        if (progress_dialog != null) {
            progress_dialog.set_status (job.get_status_string ());
            spin_event_loop ();
        }
    }

    private void on_draw_page (Gtk.PrintOperation emitting_object, Gtk.PrintContext job_context,
                               int page_num) {
        debug ("on_draw_page");

        PrintJob job = (PrintJob) emitting_object;

        // cancel () can only be called from "begin-print", "paginate", or "draw-page"
        if (cancellable != null && cancellable.is_cancelled ()) {
            job.cancel ();

            return;
        }

        spin_event_loop ();

        Gtk.PageSetup page_setup = job_context.get_page_setup ();
        double page_width = page_setup.get_page_width (Gtk.Unit.INCH);
        double page_height = page_setup.get_page_height (Gtk.Unit.INCH);

        double dpi = job.get_local_settings ().get_content_ppi ();
        double inv_dpi = 1.0 / dpi;
        Cairo.Context dc = job_context.get_cairo_context ();
        dc.scale (inv_dpi, inv_dpi);
        Gee.List<Photo> photos = job.get_photos ();

        ContentLayout content_layout = job.get_local_settings ().get_content_layout ();
        switch (content_layout) {
        case ContentLayout.STANDARD_SIZE:
        case ContentLayout.CUSTOM_SIZE:
            double canvas_width, canvas_height;
            if (content_layout == ContentLayout.STANDARD_SIZE) {
                canvas_width = get_standard_sizes ()[job.get_local_settings ().get_size_selection ()].width.convert_to (
                                   MeasurementUnit.INCHES).value;
                canvas_height = get_standard_sizes ()[job.get_local_settings ().get_size_selection ()].height.convert_to (
                                    MeasurementUnit.INCHES).value;
            } else {
                assert (content_layout == ContentLayout.CUSTOM_SIZE);
                canvas_width = job.get_local_settings ().get_content_width ().convert_to (
                                   MeasurementUnit.INCHES).value;
                canvas_height = job.get_local_settings ().get_content_height ().convert_to (
                                    MeasurementUnit.INCHES).value;
            }

            if (page_num < photos.size) {
                Dimensions photo_dimensions = photos[page_num].get_dimensions ();
                double photo_aspect_ratio = photo_dimensions.get_aspect_ratio ();
                double canvas_aspect_ratio = ((double) canvas_width) / canvas_height;
                if (Math.floor (canvas_aspect_ratio) != Math.floor (photo_aspect_ratio)) {
                    double canvas_tmp = canvas_width;
                    canvas_width = canvas_height;
                    canvas_height = canvas_tmp;
                }

                double dx = (page_width - canvas_width) / 2.0;
                double dy = (page_height - canvas_height) / 2.0;
                fit_image_to_canvas (photos[page_num], dx, dy, canvas_width, canvas_height, true,
                                     job, job_context);
                if (job.get_local_settings ().is_print_titles_enabled ()) {
                    add_title_to_canvas (page_width / 2, page_height, photos[page_num].get_name (),
                                         job, job_context);
                }
            }

            if (progress_dialog != null)
                progress_dialog.monitor (page_num, photos.size);
            break;

        case ContentLayout.IMAGE_PER_PAGE:
            PrintLayout layout = (PrintLayout) job.get_local_settings ().get_image_per_page_selection ();
            int nx = layout.get_x ();
            int ny = layout.get_y ();
            int start = page_num * layout.get_per_page ();
            double canvas_width = (double) (page_width - IMAGE_DISTANCE * (nx - 1)) / nx;
            double canvas_height = (double) (page_height - IMAGE_DISTANCE * (ny - 1)) / ny;
            for (int y = 0; y < ny; y++) {
                for (int x = 0; x < nx; x++) {
                    int i = start + y * nx + x;
                    if (i < photos.size) {
                        double dx = x * (canvas_width) + x * IMAGE_DISTANCE;
                        double dy = y * (canvas_height) + y * IMAGE_DISTANCE;
                        fit_image_to_canvas (photos[i], dx, dy, canvas_width, canvas_height, false,
                                             job, job_context);
                        if (job.get_local_settings ().is_print_titles_enabled ()) {
                            add_title_to_canvas (dx + canvas_width / 2, dy + canvas_height,
                                                 photos[i].get_name (), job, job_context);
                        }
                    }

                    if (progress_dialog != null)
                        progress_dialog.monitor (i, photos.size);
                }
            }
            break;

        default:
            error ("unknown or unsupported layout mode");
        }
    }

    private unowned Object on_create_custom_widget (Gtk.PrintOperation emitting_object) {
        custom_tab = new CustomPrintTab ((PrintJob) emitting_object);
        ((PrintJob) emitting_object).custom_widget_apply.connect (on_custom_widget_apply);
        return custom_tab;
    }

    private void on_custom_widget_apply (Gtk.Widget custom_widget) {
        CustomPrintTab tab = (CustomPrintTab) custom_widget;
        tab.get_source_job ().set_local_settings (tab.get_local_settings ());
        set_global_settings (tab.get_local_settings ());
    }

    private void fit_image_to_canvas (Photo photo, double x, double y, double canvas_width, double canvas_height, bool crop, PrintJob job, Gtk.PrintContext job_context) {
        Cairo.Context dc = job_context.get_cairo_context ();
        Dimensions photo_dimensions = photo.get_dimensions ();
        double photo_aspect_ratio = photo_dimensions.get_aspect_ratio ();
        double canvas_aspect_ratio = ((double) canvas_width) / canvas_height;

        double target_width = 0.0;
        double target_height = 0.0;
        double dpi = job.get_local_settings ().get_content_ppi ();

        if (!crop) {
            if (canvas_aspect_ratio < photo_aspect_ratio) {
                target_width = canvas_width;
                target_height = target_width * (1.0 / photo_aspect_ratio);
            } else {
                target_height = canvas_height;
                target_width = target_height * photo_aspect_ratio;
            }
            x += (canvas_width - target_width) / 2.0;
            y += (canvas_height - target_height) / 2.0;
        }

        double x_offset = dpi * x;
        double y_offset = dpi * y;
        dc.save ();
        dc.translate (x_offset, y_offset);

        int w = (int) (dpi * canvas_width);
        int h = (int) (dpi * canvas_height);
        Dimensions viewport = Dimensions (w, h);

        try {
            if (crop && !are_approximately_equal (canvas_aspect_ratio, photo_aspect_ratio)) {
                Scaling pixbuf_scaling = Scaling.to_fill_viewport (viewport);
                Gdk.Pixbuf photo_pixbuf = photo.get_pixbuf (pixbuf_scaling);
                Dimensions scaled_photo_dimensions = Dimensions.for_pixbuf (photo_pixbuf);
                int shave_vertical = 0;
                int shave_horizontal = 0;
                if (canvas_aspect_ratio < photo_aspect_ratio) {
                    shave_vertical = (int) ((scaled_photo_dimensions.width - (scaled_photo_dimensions.height * canvas_aspect_ratio)) / 2.0);
                } else {
                    shave_horizontal = (int) ((scaled_photo_dimensions.height - (scaled_photo_dimensions.width * (1.0 / canvas_aspect_ratio))) / 2.0);
                }
                Gdk.Pixbuf shaved_pixbuf = new Gdk.Pixbuf.subpixbuf (photo_pixbuf, shave_vertical, shave_horizontal, scaled_photo_dimensions.width - (2 * shave_vertical), scaled_photo_dimensions.height - (2 * shave_horizontal));

                photo_pixbuf = pixbuf_scaling.perform_on_pixbuf (shaved_pixbuf, Gdk.InterpType.HYPER, true);
                Gdk.cairo_set_source_pixbuf (dc, photo_pixbuf, 0.0, 0.0);
            } else {
                Scaling pixbuf_scaling = Scaling.for_viewport (viewport, true);
                Gdk.Pixbuf photo_pixbuf = photo.get_pixbuf (pixbuf_scaling);
                photo_pixbuf = pixbuf_scaling.perform_on_pixbuf (photo_pixbuf, Gdk.InterpType.HYPER, true);
                Gdk.cairo_set_source_pixbuf (dc, photo_pixbuf, 0.0, 0.0);
            }
            dc.paint ();

        } catch (Error e) {
            job.cancel ();
            AppWindow.error_message (_ ("Unable to print photo:\n\n%s").printf (e.message));
        }
        dc.restore ();
    }

    private void add_title_to_canvas (double x, double y, string title, PrintJob job, Gtk.PrintContext job_context) {
        Cairo.Context dc = job_context.get_cairo_context ();
        double dpi = job.get_local_settings ().get_content_ppi ();
        var title_font_description = Pango.FontDescription.from_string (job.get_local_settings ().get_print_titles_font ());
        var title_layout = Pango.cairo_create_layout (dc);
        Pango.Context context = title_layout.get_context ();
        Pango.cairo_context_set_resolution (context, dpi);
        title_layout.set_font_description (title_font_description);
        title_layout.set_text (title, -1);
        int title_width, title_height;
        title_layout.get_pixel_size (out title_width, out title_height);
        double tx = dpi * x - title_width / 2;
        double ty = dpi * y - title_height;

        // Transparent title text background
        dc.rectangle (tx - 10, ty + 2, title_width + 20, title_height);
        dc.set_source_rgba (1, 1, 1, 1);
        dc.set_line_width (2);
        dc.stroke_preserve ();
        dc.set_source_rgba (1, 1, 1, 0.5);
        dc.fill ();
        dc.set_source_rgba (0, 0, 0, 1);

        dc.move_to (tx, ty + 2);
        Pango.cairo_show_layout (dc, title_layout);
    }

    private bool are_approximately_equal (double val1, double val2) {
        double accept_err = 0.005;
        return (Math.fabs (val1 - val2) <= accept_err);
    }

    public PrintSettings get_global_settings () {
        return settings;
    }

    public void set_global_settings (PrintSettings settings) {
        this.settings = settings;
        settings.save ();
    }
}
