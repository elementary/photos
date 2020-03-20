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

public struct TagID {
    public const int64 INVALID = -1;

    public int64 id;

    public TagID (int64 id = INVALID) {
        this.id = id;
    }

    public bool is_invalid () {
        return (id == INVALID);
    }

    public bool is_valid () {
        return (id != INVALID);
    }
}

public class TagRow {
    public TagID tag_id;
    public string name;
    public Gee.Set<string>? source_id_list;
    public time_t time_created;
}

public class TagTable : DatabaseTable {
    private static TagTable instance = null;

    private TagTable () {
        set_table_name ("TagTable");

        var stmt = create_stmt ("CREATE TABLE IF NOT EXISTS "
                                 + "TagTable "
                                 + "("
                                 + "id INTEGER PRIMARY KEY, "
                                 + "name TEXT UNIQUE NOT NULL, "
                                 + "photo_id_list TEXT, "
                                 + "time_created INTEGER"
                                 + ")");

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            fatal ("create TagTable", res);
    }

    public static TagTable get_instance () {
        if (instance == null)
            instance = new TagTable ();

        return instance;
    }

    public static void upgrade_for_htags () {
        TagTable table = get_instance ();

        try {
            Gee.List < TagRow?> rows = table.get_all_rows ();

            foreach (TagRow row in rows) {
                row.name = row.name.replace (Tag.PATH_SEPARATOR_STRING, "-");
                table.rename (row.tag_id, row.name);
            }
        } catch (DatabaseError e) {
            error ("TagTable: can't upgrade tag names for hierarchical tag support: %s", e.message);
        }
    }

    public TagRow add (string name) throws DatabaseError {
        var stmt = create_stmt ("INSERT INTO TagTable (name, time_created) VALUES (?, ?)");

        time_t time_created = (time_t) now_sec ();

        bind_text (stmt, 1, name);
        bind_int64 (stmt, 2, time_created);

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            throw_error ("TagTable.add", res);

        TagRow row = new TagRow ();
        row.tag_id = TagID (db.last_insert_rowid ());
        row.name = name;
        row.source_id_list = null;
        row.time_created = time_created;

        return row;
    }

    // All fields but tag_id are respected in TagRow.
    public TagID create_from_row (TagRow row) throws DatabaseError {
        var stmt = create_stmt ("INSERT INTO TagTable (name, photo_id_list, time_created) VALUES (?, ?, ?)");

        bind_text (stmt, 1, row.name);
        bind_text (stmt, 2, serialize_source_ids (row.source_id_list));
        bind_int64 (stmt, 3, row.time_created);

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            throw_error ("TagTable.create_from_row", res);

        return TagID (db.last_insert_rowid ());
    }

    public void remove (TagID tag_id) throws DatabaseError {
        delete_by_id (tag_id.id);
    }

    public string? get_name (TagID tag_id) throws DatabaseError {
        Sqlite.Statement stmt;
        if (!select_by_id (tag_id.id, "name", out stmt))
            return null;

        return stmt.column_text (0);
    }

    public TagRow? get_row (TagID tag_id) throws DatabaseError {
        var stmt = create_stmt ("SELECT name, photo_id_list, time_created FROM TagTable WHERE id=?");

        bind_int64 (stmt, 1, tag_id.id);

        var res = stmt.step ();
        if (res == Sqlite.DONE)
            return null;
        else if (res != Sqlite.ROW)
            throw_error ("TagTable.get_row", res);

        TagRow row = new TagRow ();
        row.tag_id = tag_id;
        row.name = stmt.column_text (0);
        row.source_id_list = unserialize_source_ids (stmt.column_text (1));
        row.time_created = (time_t) stmt.column_int64 (2);

        return row;
    }

    public Gee.List < TagRow?> get_all_rows () throws DatabaseError {
        var stmt = create_stmt ("SELECT id, name, photo_id_list, time_created FROM TagTable");

        Gee.List < TagRow?> rows = new Gee.ArrayList < TagRow?> ();

        for (;;) {
            var res = stmt.step ();
            if (res == Sqlite.DONE)
                break;
            else if (res != Sqlite.ROW)
                throw_error ("TagTable.get_all_rows", res);

            // res == Sqlite.ROW
            TagRow row = new TagRow ();
            row.tag_id = TagID (stmt.column_int64 (0));
            row.name = stmt.column_text (1);
            row.source_id_list = unserialize_source_ids (stmt.column_text (2));
            row.time_created = (time_t) stmt.column_int64 (3);

            rows.add (row);
        }

        return rows;
    }

    public void rename (TagID tag_id, string new_name) throws DatabaseError {
        update_text_by_id_2 (tag_id.id, "name", new_name);
    }

    public void set_tagged_sources (TagID tag_id, Gee.Collection<string> source_ids) throws DatabaseError {
        var stmt = create_stmt ("UPDATE TagTable SET photo_id_list=? WHERE id=?");

        var serialized = serialize_source_ids (source_ids);
        if (serialized == null) {
            bind_null (stmt, 1);
        } else {
            bind_text (stmt, 1, serialized);
        }

        bind_int64 (stmt, 2, tag_id.id);

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            throw_error ("TagTable.set_tagged_photos", res);
    }

    private string? serialize_source_ids (Gee.Collection<string>? source_ids) {
        if (source_ids == null)
            return null;

        StringBuilder result = new StringBuilder ();

        foreach (string source_id in source_ids) {
            result.append (source_id);
            result.append (",");
        }

        return (result.len != 0) ? result.str : null;
    }

    private Gee.Set<string> unserialize_source_ids (string? text_list) {
        Gee.Set<string> result = new Gee.HashSet<string> ();

        if (text_list == null)
            return result;

        string[] split = text_list.split (",");
        foreach (string token in split) {
            if (is_string_empty (token))
                continue;

            // handle current and legacy encoding of source ids -- in the past, we only stored
            // LibraryPhotos in tags so we only needed to store the numeric database key of the
            // photo to uniquely identify it. Now, however, tags can store arbitrary MediaSources,
            // so instead of simply storing a number we store the source id, a string that contains
            // a typename followed by an identifying number (e.g., "video-022354").
            if (token[0].isdigit ()) {
                // this is a legacy entry
                result.add (PhotoID.upgrade_photo_id_to_source_id (PhotoID (parse_int64 (token, 10))));
            } else if (token[0].isalpha ()) {
                // this is a modern entry
                result.add (token);
            }
        }

        return result;
    }
}
