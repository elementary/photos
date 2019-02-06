/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017-2018 elementary, Inc. (https://elementary.io)
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

public class ProgressDialog : Gtk.Dialog {
    private Gtk.ProgressBar progress_bar;
    private Gtk.Button cancel_button = null;
    private Cancellable cancellable;
    private uint64 last_count = uint64.MAX;
    private int update_every = 1;
    private int minimum_on_screen_time_msec = 500;
    private ulong time_started;
#if UNITY_SUPPORT
    UnityProgressBar uniprobar = UnityProgressBar.get_instance ();
#endif

    public ProgressDialog (Gtk.Window? owner, string text, Cancellable? cancellable = null) {
        this.cancellable = cancellable;

        deletable = false;
        resizable = false;
        modal = true;

        if (owner != null) {
            set_transient_for (owner);
        }

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.width_request = 300;
        progress_bar.show_text = true;

        var primary_text_label = new Gtk.Label (text);
        primary_text_label.xalign = 0;
        primary_text_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 12;
        grid.margin = 12;
        grid.margin_top = 0;
        grid.add (primary_text_label);
        grid.add (progress_bar);

        get_content_area ().add (grid);

        if (cancellable != null) {
            cancel_button = (Gtk.Button) add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
            cancel_button.clicked.connect (on_cancel);
            delete_event.connect (on_window_closed);
        }

        time_started = now_ms ();
    }

    public override void realize () {
        base.realize ();

        // if unable to cancel the progress bar, remove the close button
        if (cancellable == null)
            get_window ().set_functions (Gdk.WMFunction.MOVE);
    }

    public void update_display_every (int update_every) {
        assert (update_every >= 1);

        this.update_every = update_every;
    }

    public void set_minimum_on_screen_time_msec (int minimum_on_screen_time_msec) {
        this.minimum_on_screen_time_msec = minimum_on_screen_time_msec;
    }

    public void set_fraction (int current, int total) {
        set_percentage ((double) current / (double) total);
    }

    public void set_percentage (double pct) {
        pct = pct.clamp (0.0, 1.0);

        maybe_show_all (pct);

        progress_bar.set_fraction (pct);
        progress_bar.set_text (_ ("%d%%").printf ((int) (pct * 100.0)));

#if UNITY_SUPPORT
        //UnityProgressBar: set progress
        uniprobar.set_progress (pct);
#endif
    }

    public void set_status (string text) {
        progress_bar.set_text (text);

#if UNITY_SUPPORT
        //UnityProgressBar: try to draw progress bar
        uniprobar.set_visible (true);
#endif
        show_all ();
    }

    // This can be used as a ProgressMonitor delegate.
    public bool monitor (uint64 count, uint64 total, bool do_event_loop = true) {
        if ((last_count == uint64.MAX) || (count - last_count) >= update_every) {
            set_percentage ((double) count / (double) total);
            last_count = count;
        }

        bool keep_going = (cancellable != null) ? !cancellable.is_cancelled () : true;

        // TODO: get rid of this.  non-trivial, as some progress-monitor operations are blocking
        // and need to allow the event loop to spin
        //
        // Important: Since it's possible the progress dialog might be destroyed inside this call,
        // avoid referring to "this" afterwards at all costs (in case all refs have been dropped)

        if (do_event_loop)
            spin_event_loop ();

        return keep_going;
    }

    public new void close () {
#if UNITY_SUPPORT
        //UnityProgressBar: reset
        uniprobar.reset ();
#endif
        hide ();
        destroy ();
    }

    private bool on_window_closed () {
        on_cancel ();
        return false; // return false so that the system handler will remove the window from
        // the screen
    }

    private void on_cancel () {
        if (cancellable != null)
            cancellable.cancel ();

        cancel_button.sensitive = false;
    }

    private void maybe_show_all (double pct) {
        // Appear only after a while because some jobs may take only a
        // fraction of second to complete so there's no point in showing progress.
        if (!this.visible && now_ms () - time_started > minimum_on_screen_time_msec) {
            // calculate percents completed in one ms
            double pps = pct * 100.0 / minimum_on_screen_time_msec;
            // calculate [very rough] estimate of time to complete in ms
            double ttc = 100.0 / pps;
            // If there is still more work to do for at least MINIMUM_ON_SCREEN_TIME_MSEC,
            // finally display the dialog.
            if (ttc > minimum_on_screen_time_msec) {
#if UNITY_SUPPORT
                //UnityProgressBar: try to draw progress bar
                uniprobar.set_visible (true);
#endif
                show_all ();
                spin_event_loop ();
            }
        }
    }
}
