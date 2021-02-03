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

public class AdjustDateTimeDialog : Granite.Dialog {
    private const int64 SECONDS_IN_DAY = 60 * 60 * 24;
    private const int64 SECONDS_IN_HOUR = 60 * 60;
    private const int64 SECONDS_IN_MINUTE = 60;
    private const int YEAR_OFFSET = 1900;
    private bool no_original_time = false;

    private const int CALENDAR_THUMBNAIL_SCALE = 1;

    private time_t original_time;
    private Gtk.Label original_time_label;
    private Gtk.Calendar calendar;
    private Gtk.SpinButton hour;
    private Gtk.SpinButton minute;
    private Gtk.SpinButton second;
    private Gtk.ComboBoxText system;
    private Gtk.RadioButton relativity_radio_button;
    private Gtk.RadioButton batch_radio_button;
    private Gtk.CheckButton modify_originals_check_button;
    private Gtk.Label notification;
    private GLib.Settings ui_settings;
    private GLib.Settings file_settings;

    private enum TimeSystem {
        AM,
        PM,
        24HR;
    }

    private TimeSystem previous_time_system;

    construct {
        ui_settings = new GLib.Settings (GSettingsConfigurationEngine.UI_PREFS_SCHEMA_NAME);
        file_settings = new GLib.Settings (GSettingsConfigurationEngine.FILES_PREFS_SCHEMA_NAME);

        add_buttons (
            (_("_Cancel")), Gtk.ResponseType.CANCEL,
            (_("_Apply")), Gtk.ResponseType.OK
        );

        deletable = false;
        modal = true;
        resizable = false;
        title = _(Resources.ADJUST_DATE_TIME_LABEL);
        transient_for = AppWindow.get_instance ();
        set_default_response (Gtk.ResponseType.OK);
    }

    public AdjustDateTimeDialog (Dateable source, int photo_count, bool display_options = true,
                                 bool contains_video = false, bool only_video = false) {
        assert (source != null);

        calendar = new Gtk.Calendar ();
        calendar.day_selected.connect (on_time_changed);
        calendar.month_changed.connect (on_time_changed);
        calendar.next_year.connect (on_time_changed);
        calendar.prev_year.connect (on_time_changed);

        if (ui_settings.get_boolean ("use-24-hour-time"))
            hour = new Gtk.SpinButton.with_range (0, 23, 1);
        else
            hour = new Gtk.SpinButton.with_range (1, 12, 1);

        hour.output.connect (on_spin_button_output);
        hour.set_width_chars (2);

        minute = new Gtk.SpinButton.with_range (0, 59, 1);
        minute.set_width_chars (2);
        minute.output.connect (on_spin_button_output);

        second = new Gtk.SpinButton.with_range (0, 59, 1);
        second.set_width_chars (2);
        second.output.connect (on_spin_button_output);

        system = new Gtk.ComboBoxText ();
        system.append_text (_ ("AM"));
        system.append_text (_ ("PM"));
        system.append_text (_ ("24 Hr"));
        system.changed.connect (on_time_system_changed);

        relativity_radio_button = new Gtk.RadioButton.with_mnemonic (null,
                _ ("_Shift photos/videos by the same amount"));
        relativity_radio_button.set_active (ui_settings.get_boolean ("keep-relativity"));
        relativity_radio_button.sensitive = display_options && photo_count > 1;

        batch_radio_button = new Gtk.RadioButton.with_mnemonic (relativity_radio_button.get_group (),
                _ ("Set _all photos/videos to this time"));
        batch_radio_button.set_active (!ui_settings.get_boolean ("keep-relativity"));
        batch_radio_button.sensitive = display_options && photo_count > 1;
        batch_radio_button.toggled.connect (on_time_changed);

        if (contains_video) {
            modify_originals_check_button = new Gtk.CheckButton.with_mnemonic (ngettext (
                    "_Modify original photo file", "_Modify original photo files", photo_count));
        } else {
            modify_originals_check_button = new Gtk.CheckButton.with_mnemonic (ngettext (
                    "_Modify original file", "_Modify original files", photo_count));
        }

        modify_originals_check_button.set_active (file_settings.get_boolean ("commit-metadata") && display_options);
        modify_originals_check_button.sensitive = (!only_video) &&
                (!file_settings.get_boolean ("commit-metadata") && display_options);

        Gdk.Pixbuf preview = null;
        try {
            // Instead of calling get_pixbuf () here, we use the thumbnail instead;
            // this was needed for Videos, since they don't support get_pixbuf ().
            preview = source.get_thumbnail (CALENDAR_THUMBNAIL_SCALE);
        } catch (Error err) {
            warning ("Unable to fetch preview for %s", source.to_string ());
        }

        var image = (preview != null) ? new Gtk.Image.from_pixbuf (preview) : new Gtk.Image ();
        original_time_label = new Gtk.Label (null);

        notification = new Gtk.Label ("");
        notification.set_line_wrap (true);
        notification.set_justify (Gtk.Justification.CENTER);
        notification.set_size_request (-1, -1);
        notification.set_padding (12, 6);

        var clock_grid = new Gtk.Grid ();
        clock_grid.column_spacing = 3;
        clock_grid.add (hour);
        clock_grid.add (new Gtk.Label (":")); // internationalize?
        clock_grid.add (minute);
        clock_grid.add (new Gtk.Label (":"));
        clock_grid.add (second);
        clock_grid.add (system);

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.row_spacing = 12;
        grid.margin = 6;
        grid.attach (image, 0, 0);
        grid.attach (original_time_label, 0, 1);
        grid.attach (calendar, 1, 0);
        grid.attach (clock_grid, 1, 1);
        grid.attach (notification, 0, 5, 2, 1);

        if (display_options) {
            grid.attach (relativity_radio_button, 1, 2);
            grid.attach (batch_radio_button, 1, 3);
            grid.attach (modify_originals_check_button, 1, 4);
        }

        get_content_area ().add (grid);

        original_time = source.get_exposure_time ();

        if (original_time == 0) {
            original_time = time_t ();
            no_original_time = true;
        }

        set_time (Time.local (original_time));
        set_original_time_label (ui_settings.get_boolean ("use-24-hour-time"));
    }

    private void set_time (Time time) {
        calendar.select_month (time.month, time.year + YEAR_OFFSET);
        calendar.select_day (time.day);

        if (ui_settings.get_boolean ("use-24-hour-time")) {
            hour.set_value (time.hour);
            system.set_active (TimeSystem.24HR);
        } else {
            int ampm_hour = time.hour % 12;
            hour.set_value ((ampm_hour == 0) ? 12 : ampm_hour);
            system.set_active ((time.hour >= 12) ? TimeSystem.PM : TimeSystem.AM);
        }

        minute.set_value (time.minute);
        second.set_value (time.second);

        previous_time_system = (TimeSystem) system.get_active ();
    }

    private void set_original_time_label (bool use_24_hr_format) {
        if (no_original_time)
            return;

        original_time_label.set_text (_ ("Original: ") +
                                      Time.local (original_time).format (use_24_hr_format ? _ ("%m/%d/%Y, %H:%M:%S") :
                                              _ ("%m/%d/%Y, %I:%M:%S %p")));
    }

    private time_t get_time () {
        Time time = Time ();

        time.second = (int) second.get_value ();
        time.minute = (int) minute.get_value ();

        // convert to 24 hr
        int hour = (int) hour.get_value ();
        time.hour = (hour == 12 && system.get_active () != TimeSystem.24HR) ? 0 : hour;
        time.hour += ((system.get_active () == TimeSystem.PM) ? 12 : 0);

        uint year, month, day;
        calendar.get_date (out year, out month, out day);
        time.year = ((int) year) - YEAR_OFFSET;
        time.month = (int) month;
        time.day = (int) day;

        time.isdst = -1;

        return time.mktime ();
    }

    public bool execute (out int64 time_shift, out bool keep_relativity,
                         out bool modify_originals) {
        show_all ();

        bool response = false;

        if (run () == Gtk.ResponseType.OK) {
            if (no_original_time)
                time_shift = (int64) get_time ();
            else
                time_shift = (int64) (get_time () - original_time);

            keep_relativity = relativity_radio_button.get_active ();

            if (relativity_radio_button.sensitive)
                ui_settings.set_boolean ("keep-relativity", keep_relativity);

            modify_originals = modify_originals_check_button.get_active ();

            if (modify_originals_check_button.sensitive)
                ui_settings.set_boolean ("modify-originals", modify_originals);

            response = true;
        } else {
            time_shift = 0;
            keep_relativity = true;
            modify_originals = false;
        }

        destroy ();

        return response;
    }

    private bool on_spin_button_output (Gtk.SpinButton button) {
        button.set_text ("%02d".printf ((int) button.get_value ()));

        on_time_changed ();

        return true;
    }

    private void on_time_changed () {
        int64 time_shift = ((int64) get_time () - (int64) original_time);

        previous_time_system = (TimeSystem) system.get_active ();

        if (time_shift == 0 || no_original_time || (batch_radio_button.get_active () &&
                batch_radio_button.sensitive)) {
            notification.hide ();
        } else {
            bool forward = time_shift > 0;
            int days, hours, minutes, seconds;

            time_shift = time_shift.abs ();

            days = (int) (time_shift / SECONDS_IN_DAY);
            time_shift = time_shift % SECONDS_IN_DAY;
            hours = (int) (time_shift / SECONDS_IN_HOUR);
            time_shift = time_shift % SECONDS_IN_HOUR;
            minutes = (int) (time_shift / SECONDS_IN_MINUTE);
            seconds = (int) (time_shift % SECONDS_IN_MINUTE);

            string shift_status = (forward) ?
                                  _ ("Exposure time will be shifted forward by\n%d %s, %d %s, %d %s, and %d %s.") :
                                  _ ("Exposure time will be shifted backward by\n%d %s, %d %s, %d %s, and %d %s.");

            notification.set_text (shift_status.printf (days, ngettext ("day", "days", days),
                                   hours, ngettext ("hour", "hours", hours), minutes,
                                   ngettext ("minute", "minutes", minutes), seconds,
                                   ngettext ("second", "seconds", seconds)));

            notification.show ();
        }
    }

    private void on_time_system_changed () {
        if (previous_time_system == system.get_active ())
            return;

        ui_settings.set_boolean ("use-24-hour-time", system.get_active () == TimeSystem.24HR);

        if (system.get_active () == TimeSystem.24HR) {
            int time = (hour.get_value () == 12.0) ? 0 : (int) hour.get_value ();
            time = time + ((previous_time_system == TimeSystem.PM) ? 12 : 0);

            hour.set_range (0, 23);
            set_original_time_label (true);

            hour.set_value (time);
        } else {
            int ampm_hour = ((int) hour.get_value ()) % 12;

            hour.set_range (1, 12);
            set_original_time_label (false);

            hour.set_value ((ampm_hour == 0) ? 12 : ampm_hour);
        }

        on_time_changed ();
    }
}
