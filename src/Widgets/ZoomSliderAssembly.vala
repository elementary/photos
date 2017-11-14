public class ZoomSliderAssembly : Gtk.Grid {
    private Gtk.Scale slider;
    private Gtk.EventBox zoom_out_box;
    private Gtk.EventBox zoom_in_box;
    private Gtk.EventBox active_zoom_widget;
    private uint zoom_click_id = 0;
    private uint zoom_initial_wait_id = 0;
    private Gtk.Settings settings;

    public signal void value_changed ();

    public string tooltip {
        set {
            slider.tooltip_text = value;
        }
    }

    public double zoom_value {
        get {
            return slider.get_value ();
        }
        set {
            slider.set_value (value);
        }
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        margin_top = 5;
        margin_bottom = 5;
    }

    public ZoomSliderAssembly (double min, double max, double step, double initial_val) {
        settings = get_settings ();

        Gtk.Image zoom_out = new Gtk.Image.from_icon_name (Resources.ICON_ZOOM_OUT, Gtk.IconSize.MENU);
        zoom_out_box = new Gtk.EventBox ();
        zoom_out_box.set_above_child (true);
        zoom_out_box.set_visible_window (false);
        zoom_out_box.add (zoom_out);
        zoom_out_box.button_press_event.connect ((event) => on_zoom_button_pressed (event, zoom_out_box));
        zoom_out_box.button_release_event.connect ((event) => on_zoom_button_released (event, zoom_out_box));

        add (zoom_out_box);

        slider = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, new Gtk.Adjustment (initial_val, min, max, step, step, 0));
        slider.value_changed.connect (on_slider_value_changed);
        slider.set_draw_value (false);
        slider.set_size_request (200, -1);

        add (slider);

        Gtk.Image zoom_in = new Gtk.Image.from_icon_name (Resources.ICON_ZOOM_IN, Gtk.IconSize.MENU);
        zoom_in_box = new Gtk.EventBox ();
        zoom_in_box.set_above_child (true);
        zoom_in_box.set_visible_window (false);
        zoom_in_box.add (zoom_in);
        zoom_in_box.button_press_event.connect ((event) => on_zoom_button_pressed (event, zoom_in_box));
        zoom_in_box.button_release_event.connect ((event) => on_zoom_button_released (event, zoom_in_box));

        add (zoom_in_box);
    }

    private void on_slider_value_changed () {
        value_changed ();
    }

    private bool zoom_callback () {
        if (active_zoom_widget == zoom_in_box) {
            increase_step ();
        } else {
            decrease_step ();
        }

        return true;
    }

    public void increase_step () {
        var new_value = slider.adjustment.value + slider.adjustment.step_increment;

        slider.set_value (new_value);
    }

    public void decrease_step () {
        var new_value = slider.adjustment.value - slider.adjustment.step_increment;

        slider.set_value (new_value);
    }

    private bool on_zoom_button_pressed (Gdk.EventButton event, Gtk.EventBox sender) {
        clear_zoom_timeouts ();

        active_zoom_widget = sender;
        zoom_initial_wait_id = Timeout.add (settings.gtk_timeout_initial, () => {
            zoom_click_id = Timeout.add (settings.gtk_timeout_repeat, zoom_callback);
            zoom_initial_wait_id = 0;
            return false;
        });

        zoom_callback ();

        return true;
    }

    private bool on_zoom_button_released (Gdk.EventButton event, Gtk.EventBox sender) {
        clear_zoom_timeouts ();

        return true;
    }

    private void clear_zoom_timeouts () {
        if (zoom_initial_wait_id != 0) {
            Source.remove (zoom_initial_wait_id);
            zoom_initial_wait_id = 0;
        }

        if (zoom_click_id != 0) {
            Source.remove (zoom_click_id);
            zoom_click_id = 0;
        }
    }

}
