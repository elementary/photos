/*
* Copyright (c) 2009-2013 Yorba Foundation
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

public errordomain ConfigurationError {
    PROPERTY_HAS_NO_VALUE,
    /**
      * the underlying configuration engine reported an error; the error is
      * specific to the configuration engine in use (e.g., GSettings)
      * and is usually meaningless to client code */
    ENGINE_ERROR,
}

public enum ConfigurableProperty {
    AUTO_IMPORT_FROM_LIBRARY = 0,
    COMMIT_METADATA_TO_MASTERS,
    DIRECTORY_PATTERN,
    DIRECTORY_PATTERN_CUSTOM,
    IMPORT_DIR,
    RAW_DEVELOPER_DEFAULT,
    USE_LOWERCASE_FILENAMES,

    NUM_PROPERTIES;

    public string to_string () {
        switch (this) {
        case AUTO_IMPORT_FROM_LIBRARY:
            return "AUTO_IMPORT_FROM_LIBRARY";

        case COMMIT_METADATA_TO_MASTERS:
            return "COMMIT_METADATA_TO_MASTERS";

        case DIRECTORY_PATTERN:
            return "DIRECTORY_PATTERN";

        case DIRECTORY_PATTERN_CUSTOM:
            return "DIRECTORY_PATTERN_CUSTOM";

        case IMPORT_DIR:
            return "IMPORT_DIR";

        case RAW_DEVELOPER_DEFAULT:
            return "RAW_DEVELOPER_DEFAULT";

        case USE_LOWERCASE_FILENAMES:
            return "USE_LOWERCASE_FILENAMES";

        default:
            error ("unknown ConfigurableProperty enumeration value");
        }
    }
}

public interface ConfigurationEngine : GLib.Object {
    public signal void property_changed (ConfigurableProperty p);

    public abstract string get_name ();

    public abstract int get_int_property (ConfigurableProperty p) throws ConfigurationError;
    public abstract void set_int_property (ConfigurableProperty p, int val) throws ConfigurationError;

    public abstract string get_string_property (ConfigurableProperty p) throws ConfigurationError;
    public abstract void set_string_property (ConfigurableProperty p, string val) throws ConfigurationError;

    public abstract bool get_bool_property (ConfigurableProperty p) throws ConfigurationError;
    public abstract void set_bool_property (ConfigurableProperty p, bool val) throws ConfigurationError;

    public abstract double get_double_property (ConfigurableProperty p) throws ConfigurationError;
    public abstract void set_double_property (ConfigurableProperty p, double val) throws ConfigurationError;

    public abstract bool get_plugin_bool (string domain, string id, string key, bool def);
    public abstract void set_plugin_bool (string domain, string id, string key, bool val);
    public abstract double get_plugin_double (string domain, string id, string key, double def);
    public abstract void set_plugin_double (string domain, string id, string key, double val);
    public abstract int get_plugin_int (string domain, string id, string key, int def);
    public abstract void set_plugin_int (string domain, string id, string key, int val);
    public abstract string? get_plugin_string (string domain, string id, string key, string? def);
    public abstract void set_plugin_string (string domain, string id, string key, string? val);
    public abstract void unset_plugin_key (string domain, string id, string key);
}

public abstract class ConfigurationFacade : Object {
    private ConfigurationEngine engine;

    public signal void auto_import_from_library_changed ();
    public signal void commit_metadata_to_masters_changed ();
    public signal void import_directory_changed ();

    protected ConfigurationFacade (ConfigurationEngine engine) {
        this.engine = engine;

        engine.property_changed.connect (on_property_changed);
    }

    private void on_property_changed (ConfigurableProperty p) {
        debug ("ConfigurationFacade: engine reports property '%s' changed.", p.to_string ());

        switch (p) {
        case ConfigurableProperty.AUTO_IMPORT_FROM_LIBRARY:
            auto_import_from_library_changed ();
            break;

        case ConfigurableProperty.COMMIT_METADATA_TO_MASTERS:
            commit_metadata_to_masters_changed ();
            break;

        case ConfigurableProperty.IMPORT_DIR:
            import_directory_changed ();
            break;
        }
    }

    protected ConfigurationEngine get_engine () {
        return engine;
    }

    protected void on_configuration_error (ConfigurationError err) {
        if (err is ConfigurationError.PROPERTY_HAS_NO_VALUE) {
            message ("configuration engine '%s' reports PROPERTY_HAS_NO_VALUE error: %s",
                     engine.get_name (), err.message);
        } else if (err is ConfigurationError.ENGINE_ERROR) {
            critical ("configuration engine '%s' reports ENGINE_ERROR: %s",
                      engine.get_name (), err.message);
        } else {
            critical ("configuration engine '%s' reports unknown error: %s",
                      engine.get_name (), err.message);
        }
    }

    //
    // auto import from library
    //
    public virtual bool get_auto_import_from_library () {
        try {
            return get_engine ().get_bool_property (ConfigurableProperty.AUTO_IMPORT_FROM_LIBRARY);
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return false;
        }
    }

    public virtual void set_auto_import_from_library (bool auto_import) {
        try {
            get_engine ().set_bool_property (ConfigurableProperty.AUTO_IMPORT_FROM_LIBRARY,
                                             auto_import);
        } catch (ConfigurationError err) {
            on_configuration_error (err);
            return;
        }
    }

    //
    // commit metadata to masters
    //
    public virtual bool get_commit_metadata_to_masters () {
        try {
            return get_engine ().get_bool_property (ConfigurableProperty.COMMIT_METADATA_TO_MASTERS);
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return false;
        }
    }

    public virtual void set_commit_metadata_to_masters (bool commit_metadata) {
        try {
            get_engine ().set_bool_property (ConfigurableProperty.COMMIT_METADATA_TO_MASTERS,
                                             commit_metadata);
        } catch (ConfigurationError err) {
            on_configuration_error (err);
            return;
        }
    }

    //
    // directory pattern
    //
    public virtual string? get_directory_pattern () {
        try {
            string s = get_engine ().get_string_property (ConfigurableProperty.DIRECTORY_PATTERN);
            return (s == "") ? null : s;
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return "";
        }
    }

    public virtual void set_directory_pattern (string? s) {
        try {
            if (s == null)
                s = "";

            get_engine ().set_string_property (ConfigurableProperty.DIRECTORY_PATTERN, s);
        } catch (ConfigurationError err) {
            on_configuration_error (err);
        }
    }

    //
    // directory pattern custom
    //
    public virtual string get_directory_pattern_custom () {
        try {
            return get_engine ().get_string_property (ConfigurableProperty.DIRECTORY_PATTERN_CUSTOM);
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return "";
        }
    }

    public virtual void set_directory_pattern_custom (string s) {
        try {
            get_engine ().set_string_property (ConfigurableProperty.DIRECTORY_PATTERN_CUSTOM, s);
        } catch (ConfigurationError err) {
            on_configuration_error (err);
        }
    }

    //
    // Default RAW developer.
    //
    public virtual RawDeveloper get_default_raw_developer () {
        try {
            return RawDeveloper.from_string (get_engine ().get_string_property (
                                                 ConfigurableProperty.RAW_DEVELOPER_DEFAULT));
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return RawDeveloper.CAMERA;
        }
    }

    public virtual void set_default_raw_developer (RawDeveloper d) {
        try {
            get_engine ().set_string_property (ConfigurableProperty.RAW_DEVELOPER_DEFAULT,
                                               d.to_string ());
        } catch (ConfigurationError err) {
            on_configuration_error (err);
            return;
        }
    }

    //
    // import dir
    //
    public virtual string get_import_dir () {
        try {
            return get_engine ().get_string_property (ConfigurableProperty.IMPORT_DIR);
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return "";
        }
    }

    public virtual void set_import_dir (string import_dir) {
        try {
            get_engine ().set_string_property (ConfigurableProperty.IMPORT_DIR, import_dir);
        } catch (ConfigurationError err) {
            on_configuration_error (err);
        }
    }

    //
    // use lowercase filenames
    //
    public virtual bool get_use_lowercase_filenames () {
        try {
            return get_engine ().get_bool_property (ConfigurableProperty.USE_LOWERCASE_FILENAMES);
        } catch (ConfigurationError err) {
            on_configuration_error (err);

            return false;
        }
    }

    public virtual void set_use_lowercase_filenames (bool b) {
        try {
            get_engine ().set_bool_property (ConfigurableProperty.USE_LOWERCASE_FILENAMES, b);
        } catch (ConfigurationError err) {
            on_configuration_error (err);
        }
    }

    //
    // allow plugins to get & set arbitrary properties
    //
    public virtual bool get_plugin_bool (string domain, string id, string key, bool def) {
        return get_engine ().get_plugin_bool (domain, id, key, def);
    }

    public virtual void set_plugin_bool (string domain, string id, string key, bool val) {
        get_engine ().set_plugin_bool (domain, id, key, val);
    }

    public virtual double get_plugin_double (string domain, string id, string key, double def) {
        return get_engine ().get_plugin_double (domain, id, key, def);
    }

    public virtual void set_plugin_double (string domain, string id, string key, double val) {
        get_engine ().set_plugin_double (domain, id, key, val);
    }

    public virtual int get_plugin_int (string domain, string id, string key, int def) {
        return get_engine ().get_plugin_int (domain, id, key, def);
    }

    public virtual void set_plugin_int (string domain, string id, string key, int val) {
        get_engine ().set_plugin_int (domain, id, key, val);
    }

    public virtual string? get_plugin_string (string domain, string id, string key, string? def) {
        string? result = get_engine ().get_plugin_string (domain, id, key, def);
        return (result == "") ? null : result;
    }

    public virtual void set_plugin_string (string domain, string id, string key, string? val) {
        if (val == null)
            val = "";

        get_engine ().set_plugin_string (domain, id, key, val);
    }

    public virtual void unset_plugin_key (string domain, string id, string key) {
        get_engine ().unset_plugin_key (domain, id, key);
    }
}
