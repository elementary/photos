/*
* Copyright (c) 2016-2017 elementary LLC. (https://elementary.io)
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

public class TopDisplay : Gtk.Stack {
    private Gtk.Label title_label;
    private Gtk.Label background_progress_label;
    private Gtk.ProgressBar background_progress_bar;
    // If there are several events at the same time, show the one with the highest priority.
    private int current_priority = 0;
    private uint background_progress_pulse_id = 0U;
    private const int BACKGROUND_PROGRESS_PULSE_MSEC = 250;

#if UNITY_SUPPORT
    UnityProgressBar uniprobar;
#endif

    private bool show_progress {
        set {
            if (value) {
                visible_child_name = "progress";
            } else {
                visible_child = title_label;
            }
        }
    }

    public string title {
        set {
            title_label.label = value;
        }
    }

    public TopDisplay () {
        Object (transition_type: Gtk.StackTransitionType.CROSSFADE);
    }

    construct {
        hexpand = false;

        title_label = new Gtk.Label (_("Photos"));
        title_label.set_ellipsize (Pango.EllipsizeMode.MIDDLE);
        title_label.get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);

        background_progress_label = new Gtk.Label (null);
        background_progress_label.hexpand = true;

        background_progress_bar = new Gtk.ProgressBar ();
        background_progress_bar.hexpand = true;

        var progress_grid = new Gtk.Grid ();
        progress_grid.orientation = Gtk.Orientation.VERTICAL;
        progress_grid.row_spacing = 6;
        progress_grid.width_request = 200;
        progress_grid.add (background_progress_label);
        progress_grid.add (background_progress_bar);

        add (title_label);
        add_named (progress_grid, "progress");
#if UNITY_SUPPORT
        uniprobar = UnityProgressBar.get_instance ();
#endif
    }

    public void start_pulse_background_progress_bar (string label, int priority) {
        if (priority < current_priority)
            return;

        stop_pulse_background_progress_bar (priority, false);

        current_priority = priority;

        background_progress_label.label = label;
        background_progress_bar.pulse ();
        show_progress = true;

        if (background_progress_pulse_id > 0) {
            Source.remove (background_progress_pulse_id);
        }

        background_progress_pulse_id = Timeout.add (BACKGROUND_PROGRESS_PULSE_MSEC, on_pulse_background_progress_bar);
    }

    private bool on_pulse_background_progress_bar () {
        background_progress_bar.pulse ();
        return true;
    }

    public void stop_pulse_background_progress_bar (int priority, bool clear) {
        if (priority < current_priority)
            return;

        if (background_progress_pulse_id > 0) {
            Source.remove (background_progress_pulse_id);
            background_progress_pulse_id = 0;
        }

        if (clear)
            clear_background_progress_bar (priority);
    }

    public void update_background_progress_bar (string label, int priority, double count, double total) {
        if (priority < current_priority) {
            return;
        }

        stop_pulse_background_progress_bar (priority, false);

        if (count <= 0.0 || total <= 0.0 || count >= total) {
            clear_background_progress_bar (priority);
            return;
        }

        current_priority = priority;

        double fraction = count / total;
        background_progress_bar.set_fraction (fraction);
        background_progress_label.label = _ ("%s (%d%%)").printf (label, (int) (fraction * 100.0));
        show_progress = true;

#if UNITY_SUPPORT
        //UnityProgressBar: try to draw & set progress
        uniprobar.set_visible (true);
        uniprobar.set_progress (fraction);
#endif
    }

    public void clear_background_progress_bar (int priority) {
        if (priority < current_priority) {
            return;
        }

        stop_pulse_background_progress_bar (priority, false);

        current_priority = 0;

        background_progress_bar.fraction = 0.0;
        background_progress_label.label = "";
        show_progress = false;

#if UNITY_SUPPORT
        //UnityProgressBar: reset
        uniprobar.reset ();
#endif
    }
}
