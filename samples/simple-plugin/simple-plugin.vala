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

extern const string _VERSION;

//
// Each .so has a Spit.Module that describes the module and offers zero or more Spit.Pluggables
// to Shotwell to extend its functionality,
//

private class SimplePluginModule : Object, Spit.Module {
    public unowned string get_module_name () {
        return "Simple Plugin Sample";
    }

    public unowned string get_version () {
        return _VERSION;
    }

    // Every module needs to have a unique ID.
    public unowned string get_id () {
        return "io.elementary.photos.samples.simple-plugin";
    }

    public unowned Spit.Pluggable[]? get_pluggables () {
        return null;
    }
}

//
// spit_entry_point () is required for all SPIT modules.
//

public Spit.Module? spit_entry_point (Spit.EntryPointParams *params) {
    // Spit.negotiate_interfaces is a simple way to deal with the parameters from the host
    params->module_spit_interface = Spit.negotiate_interfaces (params->host_min_spit_interface,
                                    params->host_max_spit_interface, Spit.CURRENT_INTERFACE);

    return (params->module_spit_interface != Spit.UNSUPPORTED_INTERFACE)
           ? new SimplePluginModule () : null;
}

// This is here to keep valac happy.
private void dummy_main () {
}
