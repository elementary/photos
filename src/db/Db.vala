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

namespace Db {

public const string IN_MEMORY_NAME = ":memory:";

private string? filename = null;

// Passing null as the db_file will create an in-memory, non-persistent database.
public void preconfigure (File? db_file) {
    filename = (db_file != null) ? db_file.get_path () : IN_MEMORY_NAME;
}

public void init () throws Error {
    assert (filename != null);

    DatabaseTable.init (filename);
}

public void terminate () {
    DatabaseTable.terminate ();
}

public enum VerifyResult {
    OK,
    FUTURE_VERSION,
    UPGRADE_ERROR,
    NO_UPGRADE_AVAILABLE
}

public VerifyResult verify_database (out string app_version, out int schema_version) {
    VersionTable version_table = VersionTable.get_instance ();
    schema_version = version_table.get_version (out app_version);

    if (schema_version >= 0)
        debug ("Database schema version %d created by app version %s", schema_version, app_version);

    if (schema_version == -1) {
        // no version set, do it now (tables will be created on demand)
        debug ("Creating database schema version %d for app version %s", DatabaseTable.SCHEMA_VERSION,
               Resources.APP_VERSION);
        version_table.set_version (DatabaseTable.SCHEMA_VERSION, Resources.APP_VERSION);
        app_version = Resources.APP_VERSION;
        schema_version = DatabaseTable.SCHEMA_VERSION;
    } else if (schema_version > DatabaseTable.SCHEMA_VERSION) {
        // Back to the future
        return Db.VerifyResult.FUTURE_VERSION;
    } else if (schema_version < DatabaseTable.SCHEMA_VERSION) {
        // Past is present
        VerifyResult result = upgrade_database (schema_version);
        if (result != VerifyResult.OK)
            return result;
    }

    return VerifyResult.OK;
}

private VerifyResult upgrade_database (int input_version) {
    assert (input_version < DatabaseTable.SCHEMA_VERSION);

    //
    // Version 18:
    // * Added comment column to EventTable
    //

    if (!DatabaseTable.has_column ("EventTable", "comment")) {
        message ("upgrade_database: adding comment column to EventTable");
        if (!DatabaseTable.add_column ("EventTable", "comment", "TEXT"))
            return VerifyResult.UPGRADE_ERROR;
    }

    int version = 18;

    //
    // Version 19:
    // * Deletion and regeneration of camera-raw thumbnails from previous versions,
    //   since they're likely to be incorrect.
    //
    //   The database itself doesn't change; this is to force the thumbnail fixup to
    //   occur.
    //

    if (input_version < 19) {
        ((Photos.Application) GLib.Application.get_default ()).set_raw_thumbs_fix_required (true);
    }

    version = 19;

    //
    // Version 20:
    // * No change to database schema but fixing issue #6541 ("Saved searches should be aware of
    //   comments") added a new enumeration value that is stored in the SavedSearchTable. The
    //   presence of this heretofore unseen enumeration value will cause prior versions of
    //   Photos to yarf, so we bump the version here to ensure this doesn't happen
    //

    version = 20;

    //
    // Finalize the upgrade process
    //

    //
    // Version 21:
    // * Added enhanced column to PhotoTable for reverting
    //   the enhance toggle button
    //
    if (!DatabaseTable.has_column ("PhotoTable", "enhanced")) {
        message ("upgrade_database: adding enhanced column to PhotoTable");
        if (!DatabaseTable.add_column ("PhotoTable", "enhanced", "INTEGER DEFAULT 0"))
            return VerifyResult.UPGRADE_ERROR;
    }

    if (!DatabaseTable.has_column ("PhotoTable", "original_transforms")) {
        message ("upgrade_database: adding original_transforms column to PhotoTable");
        if (!DatabaseTable.add_column ("PhotoTable", "original_transforms", "TEXT"))
            return VerifyResult.UPGRADE_ERROR;
    }
    version = 21;

    assert (version == DatabaseTable.SCHEMA_VERSION);
    VersionTable.get_instance ().update_version (version, Resources.APP_VERSION);

    message ("Database upgrade to schema version %d successful", version);

    return VerifyResult.OK;
}
}
