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

public class GSettingsConfigurationEngine : ConfigurationEngine, GLib.Object {
    public const string ROOT_SCHEMA_NAME = "io.elementary.photos";
    public const string PREFS_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".preferences";
    public const string UI_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".ui";
    public const string SLIDESHOW_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".slideshow";
    public const string WINDOW_PREFS_SCHEMA_NAME =  PREFS_SCHEMA_NAME + ".window";
    public const string FILES_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".files";
    public const string DB_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".database";
    public const string VIDEO_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".video";
    public const string PRINTING_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".printing";
    public const string SHARING_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".sharing";
    public const string CROP_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".crop-settings";
    public const string PLUGINS_ENABLE_DISABLE_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".plugins.enable-state";

    private void check_key_valid (string schema, string key) throws ConfigurationError {
        var schema_source = SettingsSchemaSource.get_default ();
        var settings_scheme = schema_source.lookup (schema, true);
        if (settings_scheme == null) {
            throw new ConfigurationError.ENGINE_ERROR ("schema '%s' is not installed".printf(schema));
        }

        if (!settings_scheme.has_key (key)) {
            throw new ConfigurationError.ENGINE_ERROR ("schema '%s' does not define key '%s'".printf (
                schema, key));
        }
    }

    private bool get_gs_bool (string schema, string key) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        return schema_object.get_boolean (key);
    }

    private void set_gs_bool (string schema, string key, bool value) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        schema_object.set_boolean (key, value);
    }

    private int get_gs_int (string schema, string key) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        return schema_object.get_int (key);
    }

    private void set_gs_int (string schema, string key, int value) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        schema_object.set_int (key, value);
    }

    private double get_gs_double (string schema, string key) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        return schema_object.get_double (key);
    }

    private void set_gs_double (string schema, string key, double value) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        schema_object.set_double (key, value);
    }

    private string get_gs_string (string schema, string key) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        return schema_object.get_string (key);
    }

    private void set_gs_string (string schema, string key, string value) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        schema_object.set_string (key, value);
    }

    private void reset_gs_to_default (string schema, string key) throws ConfigurationError {
        check_key_valid (schema, key);

        Settings schema_object = new Settings (schema);

        schema_object.reset (key);
    }

    private static string make_plugin_schema_name (string domain, string id) {
        string? cleaned_id = Plugins.PluggableRep.clean_plugin_id (id);
        if (cleaned_id == null)
            cleaned_id = "default";
        cleaned_id = cleaned_id.replace (".", "-");

        return "io.elementary.photos.%s.%s".printf (domain, cleaned_id);
    }

    private static string make_gsettings_key (string gconf_key) {
        return gconf_key.replace ("_", "-");
    }

    public bool get_plugin_bool (string domain, string id, string key, bool def) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            return get_gs_bool (schema_name, make_gsettings_key (key));
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
            return def;
        }
    }

    public void set_plugin_bool (string domain, string id, string key, bool val) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            set_gs_bool (schema_name, make_gsettings_key (key), val);
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
        }
    }

    public double get_plugin_double (string domain, string id, string key, double def) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            return get_gs_double (schema_name, make_gsettings_key (key));
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
            return def;
        }
    }

    public void set_plugin_double (string domain, string id, string key, double val) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            set_gs_double (schema_name, make_gsettings_key (key), val);
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
        }
    }

    public int get_plugin_int (string domain, string id, string key, int def) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            return get_gs_int (schema_name, make_gsettings_key (key));
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
            return def;
        }
    }

    public void set_plugin_int (string domain, string id, string key, int val) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            set_gs_int (schema_name, make_gsettings_key (key), val);
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
        }
    }

    public string? get_plugin_string (string domain, string id, string key, string? def) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            return get_gs_string (schema_name, make_gsettings_key (key));
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
            return def;
        }
    }

    public void set_plugin_string (string domain, string id, string key, string? val) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            set_gs_string (schema_name, make_gsettings_key (key), val);
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
        }
    }

    public void unset_plugin_key (string domain, string id, string key) {
        string schema_name = make_plugin_schema_name (domain, id);

        try {
            reset_gs_to_default (schema_name, make_gsettings_key (key));
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
        }
    }
}
