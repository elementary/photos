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

public struct TombstoneID {
    public const int64 INVALID = -1;

    public int64 id;

    public TombstoneID (int64 id = INVALID) {
        this.id = id;
    }

    public bool is_invalid () {
        return (id == INVALID);
    }

    public bool is_valid () {
        return (id != INVALID);
    }
}

public class TombstoneRow {
    public TombstoneID id;
    public string filepath;
    public int64 filesize;
    public string? md5;
    public time_t time_created;
    public Tombstone.Reason reason;
}

public class TombstoneTable : DatabaseTable {
    private static TombstoneTable instance = null;

    private TombstoneTable () {
        set_table_name ("TombstoneTable");

        var stmt = create_stmt ("CREATE TABLE IF NOT EXISTS "
                                 + "TombstoneTable "
                                 + "("
                                 + "id INTEGER PRIMARY KEY, "
                                 + "filepath TEXT NOT NULL, "
                                 + "filesize INTEGER, "
                                 + "md5 TEXT, "
                                 + "time_created INTEGER, "
                                 + "reason INTEGER DEFAULT 0 "
                                 + ")");

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            fatal ("create TombstoneTable", res);
    }

    public static TombstoneTable get_instance () {
        if (instance == null)
            instance = new TombstoneTable ();

        return instance;
    }

    public TombstoneRow add (string filepath, int64 filesize, string? md5, Tombstone.Reason reason)
        throws DatabaseError {

        var stmt = create_stmt ("INSERT INTO TombstoneTable "
        + "(filepath, filesize, md5, time_created, reason) "
        + "VALUES (?, ?, ?, ?, ?)");

        time_t time_created = (time_t) now_sec ();

        bind_text (stmt, 1, filepath);
        bind_int64 (stmt, 2, filesize);
        bind_text (stmt, 3, md5);
        bind_int64 (stmt, 4, (int64) time_created);
        bind_int (stmt, 5, reason.serialize ());

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            throw_error ("TombstoneTable.add", res);

        TombstoneRow row = new TombstoneRow ();
        row.id = TombstoneID (db.last_insert_rowid ());
        row.filepath = filepath;
        row.filesize = filesize;
        row.md5 = md5;
        row.time_created = time_created;
        row.reason = reason;

        return row;
    }

    public TombstoneRow[]? fetch_all () throws DatabaseError {
        int row_count = get_row_count ();
        if (row_count == 0)
            return null;

        var stmt = create_stmt ("SELECT id, filepath, filesize, md5, time_created, reason "
        + "FROM TombstoneTable");

        TombstoneRow[] rows = new TombstoneRow[row_count];

        int index = 0;
        for (;;) {
            var res = stmt.step ();
            if (res == Sqlite.DONE)
                break;
            else if (res != Sqlite.ROW)
                throw_error ("TombstoneTable.fetch_all", res);

            TombstoneRow row = new TombstoneRow ();
            row.id = TombstoneID (stmt.column_int64 (0));
            row.filepath = stmt.column_text (1);
            row.filesize = stmt.column_int64 (2);
            row.md5 = stmt.column_text (3);
            row.time_created = (time_t) stmt.column_int64 (4);
            row.reason = Tombstone.Reason.unserialize (stmt.column_int (5));

            rows[index++] = row;
        }

        assert (index == row_count);

        return rows;
    }

    public void update_file (TombstoneID tombstone_id, string filepath) throws DatabaseError {
        update_text_by_id_2 (tombstone_id.id, "filepath", filepath);
    }

    public void remove (TombstoneID tombstone_id) throws DatabaseError {
        delete_by_id (tombstone_id.id);
    }
}
