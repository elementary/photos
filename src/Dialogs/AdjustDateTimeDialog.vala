/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary  LLC. (https://launchpad.net/pantheon-photos)
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

public class AdjustDateTimeDialog : Gtk.Dialog {
    private const int64 SECONDS_IN_DAY = 60 * 60 * 24;
    private const int64 SECONDS_IN_HOUR = 60 * 60;
    private const int64 SECONDS_IN_MINUTE = 60;
    private const int YEAR_OFFSET = 1900;
    private bool no_original_time = false;

    private const int CALENDAR_THUMBNAIL_SCALE = 1;

    time_t original_time;
    Gtk.Label original_time_label;
    Gtk.Calendar calendar;
    Gtk.SpinButton hour;
    Gtk.SpinButton minute;
    Gtk.SpinButton second;
    Gtk.ComboBoxText system;
    Gtk.RadioButton relativity_radio_button;
    Gtk.RadioButton batch_radio_button;
    Gtk.CheckButton modify_originals_check_button;
    Gtk.Label notification;

    private enum TimeSystem {
        AM,
        PM,
        24HR;
    }

    TimeSystem previous_time_system;

    public AdjustDateTimeDialog (Dateable source, int photo_count, bool display_options = true,
                                 bool contains_video = false, bool only_video = false) {
        assert (source != null);

        set_modal (true);
        set_resizable (false);
        set_deletable (false);
        set_transient_for (AppWindow.get_instance ());

        add_buttons ((_ ("_Cancel")), Gtk.ResponseType.CANCEL,
                     (_ ("_Apply")), Gtk.ResponseType.OK);
        set_title (Resources.ADJUST_DATE_TIME_LABEL);

        calendar = new Gtk.Calendar ();
        calendar.day_selected.connect (on_time_changed);
        calendar.month_changed.connect (on_time_changed);
        calendar.next_year.connect (on_time_changed);
        calendar.prev_year.connect (on_time_changed);

        if (Config.Facade.get_instance ().get_use_24_hour_time ())
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

        Gtk.Box clock = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        clock.pack_start (hour, false, false, 3);
        clock.pack_start (new Gtk.Label (":"), false, false, 3); // internationalize?
        clock.pack_start (minute, false, false, 3);
        clock.pack_start (new Gtk.Label (":"), false, false, 3);
        clock.pack_start (second, false, false, 3);
        clock.pack_start (system, false, false, 3);

        set_default_response (Gtk.ResponseType.OK);

        relativity_radio_button = new Gtk.RadioButton.with_mnemonic (null,
                _ ("_Shift photos/videos by the same amount"));
        relativity_radio_button.set_active (Config.Facade.get_instance ().get_keep_relativity ());
        relativity_radio_button.sensitive = display_options && photo_count > 1;

        batch_radio_button = new Gtk.RadioButton.with_mnemonic (relativity_radio_button.get_group (),
                _ ("Set _all photos/videos to this time"));
        batch_radio_button.set_active (!Config.Facade.get_instance ().get_keep_relativity ());
        batch_radio_button.sensitive = display_options && photo_count > 1;
        batch_radio_button.toggled.connect (on_time_changed);

        if (contains_video) {
            modify_originals_check_button = new Gtk.CheckButton.with_mnemonic ((photo_count == 1) ?
                    _ ("_Modify original photo file") : _ ("_Modify original photo files"));
        } else {
            modify_originals_check_button = new Gtk.CheckButton.with_mnemonic ((photo_count == 1) ?
                    _ ("_Modify original file") : _ ("_Modify original files"));
        }

        modify_originals_check_button.set_active (Config.Facade.get_instance ().get_commit_metadata_to_masters () &&
                display_options);
        modify_originals_check_button.sensitive = (!only_video) &&
                (!Config.Facade.get_instance ().get_commit_metadata_to_masters () && display_options);

        Gtk.Box time_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        time_content.pack_start (calendar, true, false, 3);
        time_content.pack_start (clock, true, false, 3);

        if (display_options) {
            time_content.pack_start (relativity_radio_button, true, false, 3);
            time_content.pack_start (batch_radio_button, true, false, 3);
            time_content.pack_start (modify_originals_check_button, true, false, 3);
        }

        Gdk.Pixbuf preview = null;
        try {
            // Instead of calling get_pixbuf () here, we use the thumbnail instead;
            // this was needed for Videos, since they don't support get_pixbuf ().
            preview = source.get_thumbnail (CALENDAR_THUMBNAIL_SCALE);
        } catch (Error err) {
            warning ("Unable to fetch preview for %s", source.to_string ());
        }

        Gtk.Box image_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        Gtk.Image image = (preview != null) ? new Gtk.Image.from_pixbuf (preview) : new Gtk.Image ();
        original_time_label = new Gtk.Label (null);
        image_content.pack_start (image, true, false, 3);
        image_content.pack_start (original_time_label, true, false, 3);

        Gtk.Box hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.pack_start (image_content, true, false, 6);
        hbox.pack_start (time_content, true, false, 6);

        Gtk.Alignment hbox_alignment = new Gtk.Alignment (0.5f, 0.5f, 0, 0);
        hbox_alignment.set_padding (6, 3, 6, 6);
        hbox_alignment.add (hbox);

        ((Gtk.Box) get_content_area ()).pack_start (hbox_alignment, true, false, 6);

        notification = new Gtk.Label ("");
        notification.set_line_wrap (true);
        notification.set_justify (Gtk.Justification.CENTER);
        notification.set_size_request (-1, -1);
        notification.set_padding (12, 6);

        ((Gtk.Box) get_content_area ()).pack_start (notification, true, true, 0);

        original_time = source.get_exposure_time ();

        if (original_time == 0) {
            original_time = time_t ();
            no_original_time = true;
        }

        set_time (Time.local (original_time));
        set_original_time_label (Config.Facade.get_instance ().get_use_24_hour_time ());
    }

    private void set_time (Time time) {
        calendar.select_month (time.month, time.year + YEAR_OFFSET);
        calendar.select_day (time.day);

        if (Config.Facade.get_instance ().get_use_24_hour_time ()) {
            hour.set_value (time.hour);
            system.set_active (TimeSystem.24HR);
        } else {
            int AMPM_hour = time.hour % 12;
            hour.set_value ((AMPM_hour == 0) ? 12 : AMPM_hour);
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
                Config.Facade.get_instance ().set_keep_relativity (keep_relativity);

            modify_originals = modify_originals_check_button.get_active ();

            if (modify_originals_check_button.sensitive)
                Config.Facade.get_instance ().set_modify_originals (modify_originals);

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

        Config.Facade.get_instance ().set_use_24_hour_time (system.get_active () == TimeSystem.24HR);

        if (system.get_active () == TimeSystem.24HR) {
            int time = (hour.get_value () == 12.0) ? 0 : (int) hour.get_value ();
            time = time + ((previous_time_system == TimeSystem.PM) ? 12 : 0);

            hour.set_range (0, 23);
            set_original_time_label (true);

            hour.set_value (time);
        } else {
            int AMPM_hour = ((int) hour.get_value ()) % 12;

            hour.set_range (1, 12);
            set_original_time_label (false);

            hour.set_value ((AMPM_hour == 0) ? 12 : AMPM_hour);
        }

        on_time_changed ();
    }
}
