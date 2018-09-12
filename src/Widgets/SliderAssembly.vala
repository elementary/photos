/* Copyright 2017 elementary LLC. (https://elementary.io)
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
* Authored by: David Hewitt <davidmhewitt@gmail.com>
*/

public class SliderAssembly : Gtk.Grid {
    private Gtk.Scale slider;
    private Gtk.EventBox decrease_box;
    private Gtk.EventBox increase_box;
    private Gtk.EventBox active_box;
    private uint click_id = 0;
    private uint initial_wait_id = 0;

    public signal void value_changed ();

    public string tooltip {
        set {
            slider.tooltip_text = value;
        }
    }

    public bool inverted {
        set {
            slider.inverted = value;
        }
        private get {
            return slider.inverted;
        }
    }

    public double slider_value {
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

        var decrease = new Gtk.Image.from_icon_name (Resources.ICON_ZOOM_OUT, Gtk.IconSize.MENU);
        decrease_box = new Gtk.EventBox ();
        decrease_box.above_child = true;
        decrease_box.visible_window = false;
        decrease_box.add (decrease);
        decrease_box.button_press_event.connect (on_button_pressed);
        decrease_box.button_release_event.connect (on_button_released);
        decrease_box.leave_notify_event.connect (() => {
            clear_timeouts ();

            return false;
        });

        add (decrease_box);

        slider = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
        slider.value_changed.connect (on_slider_value_changed);
        slider.draw_value = false;
        slider.set_size_request (150, -1);

        add (slider);

        var increase = new Gtk.Image.from_icon_name (Resources.ICON_ZOOM_IN, Gtk.IconSize.MENU);
        increase_box = new Gtk.EventBox ();
        increase_box.above_child = true;
        increase_box.visible_window = false;
        increase_box.add (increase);
        increase_box.button_press_event.connect (on_button_pressed);
        increase_box.button_release_event.connect (on_button_released);
        increase_box.leave_notify_event.connect (() => {
            clear_timeouts ();

            return false;
        });

        add (increase_box);
    }

    public SliderAssembly (double min, double max, double step, double initial_val) {
        slider.set_range (min, max);
        slider.set_increments (step, step);
        slider_value = initial_val;
    }

    private void on_slider_value_changed () {
        value_changed ();
    }

    private bool step_callback () {
        if (active_box == increase_box) {
            increase_step ();
        } else {
            decrease_step ();
        }

        return true;
    }

    public void increase_step () {
        double new_value;
        if (!inverted) {
            new_value = slider.adjustment.value + slider.adjustment.step_increment;
        } else {
            new_value = slider.adjustment.value - slider.adjustment.step_increment;
        }

        slider.set_value (new_value);
    }

    public void decrease_step () {
        double new_value;
        if (!inverted) {
            new_value = slider.adjustment.value - slider.adjustment.step_increment;
        } else {
            new_value = slider.adjustment.value + slider.adjustment.step_increment;
        }

        slider.set_value (new_value);
    }

    private bool on_button_pressed (Gtk.Widget sender, Gdk.EventButton event) {
        clear_timeouts ();

        active_box = (Gtk.EventBox)sender;
        initial_wait_id = Timeout.add (200, () => {
            click_id = Timeout.add (20, step_callback);
            initial_wait_id = 0;
            return false;
        });

        step_callback ();

        return true;
    }

    private bool on_button_released (Gtk.Widget sender, Gdk.EventButton event) {
        clear_timeouts ();

        return true;
    }

    private void clear_timeouts () {
        clear_timeout (ref initial_wait_id);
        clear_timeout (ref click_id);
    }

    private static void clear_timeout (ref uint id) {
        if (id != 0) {
            Source.remove (id);
            id = 0;
        }
    }
}
