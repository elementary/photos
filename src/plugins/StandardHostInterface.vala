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

namespace Plugins {

public class StandardHostInterface : Object, Spit.HostInterface {
    private string config_domain;
    private string config_id;
    private File module_file;
    private Spit.PluggableInfo info;

    public StandardHostInterface (Spit.Pluggable pluggable, string config_domain) {
        this.config_domain = config_domain;
        config_id = parse_key (pluggable.get_id ());
        module_file = get_pluggable_module_file (pluggable);
        pluggable.get_info (ref info);
    }

    private static string parse_key (string id) {
        // special case: legacy plugins (Web publishers moved into SPIT) have special names
        // new plugins will use their full ID
        switch (id) {
        case "io.elementary.photos.publishing.facebook":
            return "facebook";

        case "io.elementary.photos.publishing.picasa":
            return "picasa";

        case "io.elementary.photos.publishing.flickr":
            return "flickr";

        case "io.elementary.photos.publishing.piwigo":
            return "piwigo";

        case "io.elementary.photos.publishing.youtube":
            return "youtube";

        default:
            return id;
        }
    }

    public File get_module_file () {
        return module_file;
    }

    public bool get_config_bool (string key, bool def) {
        return Config.Facade.get_instance ().get_plugin_bool (config_domain, config_id, key, def);
    }

    public void set_config_bool (string key, bool val) {
        Config.Facade.get_instance ().set_plugin_bool (config_domain, config_id, key, val);
    }

    public int get_config_int (string key, int def) {
        return Config.Facade.get_instance ().get_plugin_int (config_domain, config_id, key, def);
    }

    public void set_config_int (string key, int val) {
        Config.Facade.get_instance ().set_plugin_int (config_domain, config_id, key, val);
    }

    public string? get_config_string (string key, string? def) {
        return Config.Facade.get_instance ().get_plugin_string (config_domain, config_id, key, def);
    }

    public void set_config_string (string key, string? val) {
        Config.Facade.get_instance ().set_plugin_string (config_domain, config_id, key, val);
    }

    public double get_config_double (string key, double def) {
        return Config.Facade.get_instance ().get_plugin_double (config_domain, config_id, key, def);
    }

    public void set_config_double (string key, double val) {
        Config.Facade.get_instance ().set_plugin_double (config_domain, config_id, key, val);
    }

    public void unset_config_key (string key) {
        Config.Facade.get_instance ().unset_plugin_key (config_domain, config_id, key);
    }
}

}
