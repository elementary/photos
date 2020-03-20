/*
* Copyright (c) 2011-2013 Yorba Foundation
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

private class ShotwellTransitions : Object, Spit.Module {
    private Spit.Pluggable[] pluggables = new Spit.Pluggable[0];

    public ShotwellTransitions (GLib.File module_file) {
        Gtk.IconTheme.get_default ().add_resource_path ("/io/elementary/photos/plugins/transitions/icons");
        GLib.File resource_directory = module_file.get_parent ();

        pluggables += new FadeEffectDescriptor (resource_directory);
        pluggables += new SlideEffectDescriptor (resource_directory);
        pluggables += new CrumbleEffectDescriptor (resource_directory);
        pluggables += new BlindsEffectDescriptor (resource_directory);
        pluggables += new CircleEffectDescriptor (resource_directory);
        pluggables += new CirclesEffectDescriptor (resource_directory);
        pluggables += new ClockEffectDescriptor (resource_directory);
        pluggables += new SquaresEffectDescriptor (resource_directory);
        pluggables += new ChessEffectDescriptor (resource_directory);
        pluggables += new StripesEffectDescriptor (resource_directory);
    }

    public unowned string get_module_name () {
        return _ ("Core Slideshow Transitions");
    }

    public unowned string get_version () {
        return _VERSION;
    }

    public unowned string get_id () {
        return "io.elementary.photos.transitions";
    }

    public unowned Spit.Pluggable[]? get_pluggables () {
        return pluggables;
    }
}

// This entry point is required for all SPIT modules.
public Spit.Module? spit_entry_point (Spit.EntryPointParams *params) {
    params->module_spit_interface = Spit.negotiate_interfaces (params->host_min_spit_interface,
                                    params->host_max_spit_interface, Spit.CURRENT_INTERFACE);

    return (params->module_spit_interface != Spit.UNSUPPORTED_INTERFACE)
           ? new ShotwellTransitions (params->module_file) : null;
}

// Base class for all transition descriptors in this module
public abstract class ShotwellTransitionDescriptor : Object, Spit.Pluggable, Spit.Transitions.Descriptor {
    private GLib.Icon icon;

    protected ShotwellTransitionDescriptor (GLib.File resource_directory) {
        icon = new ThemedIcon ("slideshow-plugin");
    }

    public int get_pluggable_interface (int min_host_interface, int max_host_interface) {
        return Spit.negotiate_interfaces (min_host_interface, max_host_interface,
                                          Spit.Transitions.CURRENT_INTERFACE);
    }

    public abstract unowned string get_id ();

    public abstract unowned string get_pluggable_name ();

    public void get_info (ref Spit.PluggableInfo info) {
        info.authors = "Maxim Kartashev";
        info.copyright = _ ("Copyright 2010 Maxim Kartashev, Copyright 2011-2013 Yorba Foundation");
        info.translators = Resources.TRANSLATORS;
        info.version = _VERSION;
        info.website_name = Resources.WEBSITE_NAME;
        info.website_url = Resources.WEBSITE_URL;
        info.is_license_wordwrapped = false;
        info.license = Resources.LICENSE;
        info.icon = icon;
    }

    public void activation (bool enabled) {
    }

    public abstract Spit.Transitions.Effect create (Spit.HostInterface host);
}
