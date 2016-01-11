/* Copyright 2016 elementary LLC
*
* This file is part of Pantheon Photos.
*
* Pantheon Photos is free software: you can redistribute it
* and/or modify it under the terms of the GNU Lesser General Public License as
* published by the Free Software Foundation, either version 2.1 of the
* License, or (at your option) any later version.
*
* Pantheon Photos is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General
* Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License along
* with Pantheon Photos. If not, see http://www.gnu.org/licenses/.
*/

public class TopDisplay : Gtk.Stack {
    private Gtk.Label app_label;
    private Gtk.Grid top_grid;
    private Gtk.Label background_progress_label;
    private Gtk.ProgressBar background_progress_bar;
    // If there are several events at the same time, show the one with the highest priority.
    private int current_priority = 0;
    private uint background_progress_pulse_id = 0U;
    private const int BACKGROUND_PROGRESS_PULSE_MSEC = 250;

#if UNITY_SUPPORT
    UnityProgressBar uniprobar;
#endif

    public TopDisplay () {
        
    }

    construct {
        hexpand = true;
        transition_type = Gtk.StackTransitionType.CROSSFADE;
        get_style_context ().add_class ("seek-bar");
        app_label = new Gtk.Label (_("Photos"));
        app_label.get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);
        top_grid = new Gtk.Grid ();
        top_grid.orientation = Gtk.Orientation.VERTICAL;
        top_grid.row_spacing = 6;
        top_grid.hexpand = true;
        top_grid.halign = Gtk.Align.CENTER;
        top_grid.set_size_request (200, -1);
        background_progress_label = new Gtk.Label (null);
        background_progress_label.hexpand = true;
        background_progress_bar = new Gtk.ProgressBar ();
        background_progress_bar.hexpand = true;
        top_grid.add (background_progress_label);
        top_grid.add (background_progress_bar);
        add (app_label);
        add (top_grid);
#if UNITY_SUPPORT
        uniprobar = UnityProgressBar.get_instance ();
#endif
    }

    public void set_title (string title) {
        app_label.label = title;
    }

    public void set_show_progress (bool show_progress) {
        if (show_progress) {
            set_visible_child (top_grid);
        } else {
            set_visible_child (app_label);
        }
    }

    public void start_pulse_background_progress_bar (string label, int priority) {
        if (priority < current_priority)
            return;

        stop_pulse_background_progress_bar (priority, false);

        current_priority = priority;

        background_progress_label.label = label;
        background_progress_bar.pulse ();
        set_show_progress (true);

        if (background_progress_pulse_id > 0) {
            Source.remove (background_progress_pulse_id);
        }

        background_progress_pulse_id = Timeout.add (BACKGROUND_PROGRESS_PULSE_MSEC,
                                       on_pulse_background_progress_bar);
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

    public void update_background_progress_bar (string label, int priority, double count,
            double total) {
        if (priority < current_priority)
            return;

        stop_pulse_background_progress_bar (priority, false);

        if (count <= 0.0 || total <= 0.0 || count >= total) {
            clear_background_progress_bar (priority);

            return;
        }

        current_priority = priority;

        double fraction = count / total;
        background_progress_bar.set_fraction (fraction);
        background_progress_label.label = _ ("%s (%d%%)").printf (label, (int) (fraction * 100.0));
        set_show_progress (true);

#if UNITY_SUPPORT
        //UnityProgressBar: try to draw & set progress
        uniprobar.set_visible (true);
        uniprobar.set_progress (fraction);
#endif
    }

    public void clear_background_progress_bar (int priority) {
        if (priority < current_priority)
            return;

        stop_pulse_background_progress_bar (priority, false);

        current_priority = 0;

        background_progress_bar.fraction = 0.0;
        background_progress_label.label = "";
        set_show_progress (false);

#if UNITY_SUPPORT
        //UnityProgressBar: reset
        uniprobar.reset ();
#endif
    }
}
