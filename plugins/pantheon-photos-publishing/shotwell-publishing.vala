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

// "core services" are: Facebook, Flickr, Picasa Web Albums, Piwigo and YouTube
private class ShotwellPublishingCoreServices : Object, Spit.Module {
    private Spit.Pluggable[] pluggables = new Spit.Pluggable[0];

    // we need to get a module file handle because our pluggables have to load resources from the
    // module file directory
    public ShotwellPublishingCoreServices (GLib.File module_file) {
        Gtk.IconTheme.get_default ().add_resource_path ("/io/elementary/photos/plugins/publishing/icons");
        GLib.File resource_directory = module_file.get_parent ();

        pluggables += new FacebookService (resource_directory);
        pluggables += new PicasaService (resource_directory);
        pluggables += new FlickrService (resource_directory);
        pluggables += new YouTubeService (resource_directory);
        pluggables += new PiwigoService (resource_directory);
    }

    public unowned string get_module_name () {
        return _ ("Core Publishing Services");
    }

    public unowned string get_version () {
        return _VERSION;
    }

    public unowned string get_id () {
        return "io.elementary.photos.publishing.core_services";
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
           ? new ShotwellPublishingCoreServices (params->module_file) : null;
}
