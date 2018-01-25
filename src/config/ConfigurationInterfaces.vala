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
     * and is usually meaningless to client code
     */
    ENGINE_ERROR,
}

public interface ConfigurationEngine : GLib.Object {
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

    protected ConfigurationFacade (ConfigurationEngine engine) {
        this.engine = engine;
    }

    protected ConfigurationEngine get_engine () {
        return engine;
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
