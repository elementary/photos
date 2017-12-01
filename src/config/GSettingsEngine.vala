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
    public const string ROOT_SCHEMA_NAME = "org.pantheon.photos";
    public const string PREFS_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".preferences";
    public const string UI_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".ui";
    public const string SLIDESHOW_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".slideshow";
    public const string WINDOW_PREFS_SCHEMA_NAME =  PREFS_SCHEMA_NAME + ".window";
    public const string FILES_PREFS_SCHEMA_NAME = PREFS_SCHEMA_NAME + ".files";
    public const string VIDEO_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".video";
    public const string PRINTING_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".printing";
    public const string SHARING_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".sharing";
    public const string CROP_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".crop-settings";
    public const string PLUGINS_ENABLE_DISABLE_SCHEMA_NAME = ROOT_SCHEMA_NAME + ".plugins.enable-state";

    private Gee.Set<string> known_schemas;
    private string[] schema_names;
    private string[] key_names;

    public GSettingsConfigurationEngine () {
        known_schemas = new Gee.HashSet<string> ();

        foreach (string current_schema in Settings.list_schemas ())
            known_schemas.add (current_schema);

        schema_names = new string[ConfigurableProperty.NUM_PROPERTIES];

        schema_names[ConfigurableProperty.AUTO_IMPORT_FROM_LIBRARY] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.COMMIT_METADATA_TO_MASTERS] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.DIRECTORY_PATTERN] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.DIRECTORY_PATTERN_CUSTOM] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.IMPORT_DIR] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.RAW_DEVELOPER_DEFAULT] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.USE_LOWERCASE_FILENAMES] = FILES_PREFS_SCHEMA_NAME;
        schema_names[ConfigurableProperty.VIDEO_INTERPRETER_STATE_COOKIE] = VIDEO_SCHEMA_NAME;

        key_names = new string[ConfigurableProperty.NUM_PROPERTIES];

        key_names[ConfigurableProperty.AUTO_IMPORT_FROM_LIBRARY] = "auto-import";
        key_names[ConfigurableProperty.COMMIT_METADATA_TO_MASTERS] = "commit-metadata";
        key_names[ConfigurableProperty.DIRECTORY_PATTERN] = "directory-pattern";
        key_names[ConfigurableProperty.DIRECTORY_PATTERN_CUSTOM] = "directory-pattern-custom";
        key_names[ConfigurableProperty.IMPORT_DIR] = "import-dir";
        key_names[ConfigurableProperty.RAW_DEVELOPER_DEFAULT] = "raw-developer-default";
        key_names[ConfigurableProperty.USE_LOWERCASE_FILENAMES] = "use-lowercase-filenames";
        key_names[ConfigurableProperty.VIDEO_INTERPRETER_STATE_COOKIE] = "interpreter-state-cookie";
    }

    private bool schema_has_key (Settings schema_object, string key) {
        foreach (string current_key in schema_object.list_keys ()) {
            if (current_key == key)
                return true;
        }

        return false;
    }

    private void check_key_valid (string schema, string key) throws ConfigurationError {
        if (!known_schemas.contains (schema))
            throw new ConfigurationError.ENGINE_ERROR ("schema '%s' is not installed".printf (schema));

        Settings schema_object = new Settings (schema);

        if (!schema_has_key (schema_object, key))
            throw new ConfigurationError.ENGINE_ERROR ("schema '%s' does not define key '%s'".printf (
                schema, key));
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

    private static string? clean_plugin_id (string id) {
        string cleaned = id.replace ("/", "-");
        cleaned = cleaned.strip ();

        return !is_string_empty (cleaned) ? cleaned : null;
    }

    private static string get_plugin_enable_disable_name (string id) {
        string? cleaned_id = clean_plugin_id (id);
        if (cleaned_id == null)
            cleaned_id = "default";

        cleaned_id = cleaned_id.replace ("org.pantheon.photos.", "");
        cleaned_id = cleaned_id.replace (".", "-");

        return cleaned_id;
    }

    private static string make_plugin_schema_name (string domain, string id) {
        string? cleaned_id = clean_plugin_id (id);
        if (cleaned_id == null)
            cleaned_id = "default";
        cleaned_id = cleaned_id.replace (".", "-");

        return "org.pantheon.photos.%s.%s".printf (domain, cleaned_id);
    }

    private static string make_gsettings_key (string gconf_key) {
        return gconf_key.replace ("_", "-");
    }

    public string get_name () {
        return "GSettings";
    }

    public int get_int_property (ConfigurableProperty p) throws ConfigurationError {
        return get_gs_int (schema_names[p], key_names[p]);
    }

    public void set_int_property (ConfigurableProperty p, int val) throws ConfigurationError {
        set_gs_int (schema_names[p], key_names[p], val);
        property_changed (p);
    }

    public string get_string_property (ConfigurableProperty p) throws ConfigurationError {
        return get_gs_string (schema_names[p], key_names[p]);
    }

    public void set_string_property (ConfigurableProperty p, string val) throws ConfigurationError {
        set_gs_string (schema_names[p], key_names[p], val);
        property_changed (p);
    }

    public bool get_bool_property (ConfigurableProperty p) throws ConfigurationError {
        return get_gs_bool (schema_names[p], key_names[p]);
    }

    public void set_bool_property (ConfigurableProperty p, bool val) throws ConfigurationError {
        set_gs_bool (schema_names[p], key_names[p], val);
        property_changed (p);
    }

    public double get_double_property (ConfigurableProperty p) throws ConfigurationError {
        return get_gs_double (schema_names[p], key_names[p]);
    }

    public void set_double_property (ConfigurableProperty p, double val) throws ConfigurationError {
        set_gs_double (schema_names[p], key_names[p], val);
        property_changed (p);
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

    public FuzzyPropertyState is_plugin_enabled (string id) {
        string enable_disable_name = get_plugin_enable_disable_name (id);

        try {
            return (get_gs_bool (PLUGINS_ENABLE_DISABLE_SCHEMA_NAME, enable_disable_name)) ?
                   FuzzyPropertyState.ENABLED : FuzzyPropertyState.DISABLED;
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
            return FuzzyPropertyState.UNKNOWN;
        }
    }

    public void set_plugin_enabled (string id, bool enabled) {
        string enable_disable_name = get_plugin_enable_disable_name (id);

        try {
            set_gs_bool (PLUGINS_ENABLE_DISABLE_SCHEMA_NAME, enable_disable_name, enabled);
        } catch (ConfigurationError err) {
            critical ("GSettingsConfigurationEngine: error: %s", err.message);
        }
    }

}
