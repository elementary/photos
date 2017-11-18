/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary LLC. (https://elementary.io)
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

private class SlideshowSettingsDialog : Gtk.Dialog {
    private const double SLIDESHOW_DELAY_MAX = 30.0;
    private const double SLIDESHOW_DELAY_MIN = 1.0;
    private const double SLIDESHOW_TRANSITION_DELAY_MAX = 1.0;
    private const double SLIDESHOW_TRANSITION_DELAY_MIN = 0.1;

    private Gtk.Builder builder = null;
    Gtk.SpinButton delay_entry;
    Gtk.Scale delay_hscale;
    Gtk.ComboBoxText transition_effect_selector;
    Gtk.Scale transition_effect_hscale;
    Gtk.SpinButton transition_effect_entry;
    Gtk.Adjustment transition_effect_adjustment;
    Gtk.CheckButton show_title_button;
    Gtk.Box pane;
    private GLib.Settings slideshow_settings;

    construct {
        slideshow_settings = new GLib.Settings (GSettingsConfigurationEngine.SLIDESHOW_PREFS_SCHEMA_NAME);
    }

    public SlideshowSettingsDialog () {
        builder = AppWindow.create_builder ();
        pane = builder.get_object ("slideshow_settings_pane") as Gtk.Box;
        get_content_area ().add (pane);

        double delay = slideshow_settings.get_double ("delay");

        set_modal (true);
        set_transient_for (AppWindow.get_fullscreen ());

        add_buttons (_("Cancel"), Gtk.ResponseType.CANCEL,
                     _("Save Settings"), Gtk.ResponseType.OK);
        set_title (_ ("Settings"));

        Gtk.Adjustment adjustment = new Gtk.Adjustment (delay, SLIDESHOW_DELAY_MIN, SLIDESHOW_DELAY_MAX, 0.1, 1, 0);
        delay_hscale = builder.get_object ("delay_hscale") as Gtk.Scale;
        delay_hscale.adjustment = adjustment;

        delay_entry = builder.get_object ("delay_entry") as Gtk.SpinButton;
        delay_entry.adjustment = adjustment;
        delay_entry.set_value (delay);
        delay_entry.set_numeric (true);
        delay_entry.set_activates_default (true);

        transition_effect_selector = builder.get_object ("transition_effect_selector") as Gtk.ComboBoxText;

        // get last effect id
        string effect_id = slideshow_settings.get_string ("transition-effect-id");

        // null effect first, always, and set active in case no other one is found
        string null_display_name = TransitionEffectsManager.get_instance ().get_effect_name (
                                       TransitionEffectsManager.NULL_EFFECT_ID);
        transition_effect_selector.append_text (null_display_name);
        transition_effect_selector.set_active (0);

        int i = 1;
        foreach (string display_name in
                 TransitionEffectsManager.get_instance ().get_effect_names (utf8_ci_compare)) {
            if (display_name == null_display_name)
                continue;

            transition_effect_selector.append_text (display_name);
            if (effect_id == TransitionEffectsManager.get_instance ().get_id_for_effect_name (display_name))
                transition_effect_selector.set_active (i);

            ++i;
        }
        transition_effect_selector.changed.connect (on_transition_changed);

        double transition_delay = slideshow_settings.get_double ("transition-delay");
        transition_effect_adjustment = new Gtk.Adjustment (transition_delay, SLIDESHOW_TRANSITION_DELAY_MIN, 
                                                           SLIDESHOW_TRANSITION_DELAY_MAX, 0.1, 1, 0);

        transition_effect_hscale = builder.get_object ("transition_effect_hscale") as Gtk.Scale;
        transition_effect_hscale.adjustment = transition_effect_adjustment;

        transition_effect_entry = builder.get_object ("transition_effect_entry") as Gtk.SpinButton;
        transition_effect_entry.adjustment = transition_effect_adjustment;
        transition_effect_entry.set_value (transition_delay);
        transition_effect_entry.set_numeric (true);
        transition_effect_entry.set_activates_default (true);

        bool show_title = slideshow_settings.get_boolean ("show-title");
        show_title_button = builder.get_object ("show_title_button") as  Gtk.CheckButton;
        show_title_button.active = show_title;

        set_default_response (Gtk.ResponseType.OK);

        on_transition_changed ();
    }

    private void on_transition_changed () {
        string selected = transition_effect_selector.get_active_text ();
        bool sensitive = selected != null
                         && selected != TransitionEffectsManager.NULL_EFFECT_ID;

        transition_effect_hscale.sensitive = sensitive;
        transition_effect_entry.sensitive = sensitive;
    }

    public double get_delay () {
        return delay_entry.get_value ();
    }

    public double get_transition_delay () {
        return transition_effect_entry.get_value ();
    }

    public string get_transition_effect_id () {
        string? active = transition_effect_selector.get_active_text ();
        if (active == null)
            return TransitionEffectsManager.NULL_EFFECT_ID;

        string? id = TransitionEffectsManager.get_instance ().get_id_for_effect_name (active);

        return (id != null) ? id : TransitionEffectsManager.NULL_EFFECT_ID;
    }

    public bool get_show_title () {
        return show_title_button.active;
    }
}
