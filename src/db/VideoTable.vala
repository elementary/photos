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

public struct VideoID {
    public const int64 INVALID = -1;

    public int64 id;

    public VideoID (int64 id = INVALID) {
        this.id = id;
    }

    public bool is_invalid () {
        return (id == INVALID);
    }

    public bool is_valid () {
        return (id != INVALID);
    }

    public static uint hash (VideoID? a) {
        return int64_hash (a.id);
    }

    public static bool equal (void *a, void *b) {
        return ((VideoID *) a)->id == ((VideoID *) b)->id;
    }

    public static string upgrade_video_id_to_source_id (VideoID video_id) {
        return ("%s-%016" + int64.FORMAT_MODIFIER + "x").printf (Video.TYPENAME, video_id.id);
    }
}

public class VideoRow {
    public VideoID video_id;
    public string filepath;
    public int64 filesize;
    public int64 timestamp;
    public int width;
    public int height;
    public double clip_duration;
    public bool is_interpretable;
    public int64 exposure_time;
    public ImportID import_id;
    public EventID event_id;
    public string md5;
    public int64 time_created;
    public string title;
    public string? backlinks;
    public int64 time_reimported;
    public uint64 flags;
    public string comment;
}

public class VideoTable : DatabaseTable {
    private static VideoTable instance = null;

    private VideoTable () {
        var stmt = create_stmt ("CREATE TABLE IF NOT EXISTS VideoTable ("
                                 + "id INTEGER PRIMARY KEY, "
                                 + "filename TEXT UNIQUE NOT NULL, "
                                 + "width INTEGER, "
                                 + "height INTEGER, "
                                 + "clip_duration REAL, "
                                 + "is_interpretable INTEGER, "
                                 + "filesize INTEGER, "
                                 + "timestamp INTEGER, "
                                 + "exposure_time INTEGER, "
                                 + "import_id INTEGER, "
                                 + "event_id INTEGER, "
                                 + "md5 TEXT, "
                                 + "time_created INTEGER, "
                                 + "title TEXT, "
                                 + "backlinks TEXT, "
                                 + "time_reimported INTEGER, "
                                 + "flags INTEGER DEFAULT 0, "
                                 + "comment TEXT "
                                 + ")");

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            fatal ("VideoTable constructor", res);

        // index on event_id
        stmt = create_stmt ("CREATE INDEX IF NOT EXISTS VideoEventIDIndex ON VideoTable (event_id)");
        res = stmt.step ();
        if (res != Sqlite.DONE)
            fatal ("VideoTable constructor", res);

        set_table_name ("VideoTable");
    }

    public static VideoTable get_instance () {
        if (instance == null)
            instance = new VideoTable ();

        return instance;
    }

    // VideoRow.video_id, event_id, time_created are ignored on input. All fields are set on exit
    // with values stored in the database.
    public VideoID add (VideoRow video_row) throws DatabaseError {
        var stmt = create_stmt (
            "INSERT INTO VideoTable (filename, width, height, clip_duration, is_interpretable, "
            + "filesize, timestamp, exposure_time, import_id, event_id, md5, time_created, title, comment) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

        int64 time_created = now_sec ();

        bind_text (stmt, 1, video_row.filepath);
        bind_int (stmt, 2, video_row.width);
        bind_int (stmt, 3, video_row.height);
        bind_double (stmt, 4, video_row.clip_duration);
        bind_int (stmt, 5, (video_row.is_interpretable) ? 1 : 0);
        bind_int64 (stmt, 6, video_row.filesize);
        bind_int64 (stmt, 7, video_row.timestamp);
        bind_int64 (stmt, 8, video_row.exposure_time);
        bind_int64 (stmt, 9, video_row.import_id.id);
        bind_int64 (stmt, 10, EventID.INVALID);
        bind_text (stmt, 11, video_row.md5);
        bind_int64 (stmt, 12, time_created);
        bind_text (stmt, 13, video_row.title);
        bind_text (stmt, 14, video_row.comment);

        var res = stmt.step ();
        if (res != Sqlite.DONE) {
            if (res != Sqlite.CONSTRAINT)
                throw_error ("VideoTable.add", res);
        }

        // fill in ignored fields with database values
        video_row.video_id = VideoID (db.last_insert_rowid ());
        video_row.event_id = EventID ();
        video_row.time_created = time_created;
        video_row.flags = 0;

        return video_row.video_id;
    }

    public bool drop_event (EventID event_id) {
        var stmt = create_stmt ("UPDATE VideoTable SET event_id = ? WHERE event_id = ?");

        bind_int64 (stmt, 1, EventID.INVALID);
        bind_int64 (stmt, 2, event_id.id);

        var res = stmt.step ();
        if (res != Sqlite.DONE) {
            fatal ("VideoTable.drop_event", res);

            return false;
        }

        return true;
    }

    public VideoRow? get_row (VideoID video_id) {
        var stmt = create_stmt (
                      "SELECT filename, width, height, clip_duration, is_interpretable, filesize, timestamp, "
                      + "exposure_time, import_id, event_id, md5, time_created, title, backlinks, "
                      + "time_reimported, flags, comment FROM VideoTable WHERE id=?");

        bind_int64 (stmt, 1, video_id.id);

        if (stmt.step () != Sqlite.ROW)
            return null;

        VideoRow row = new VideoRow ();
        row.video_id = video_id;
        row.filepath = stmt.column_text (0);
        row.width = stmt.column_int (1);
        row.height = stmt.column_int (2);
        row.clip_duration = stmt.column_double (3);
        row.is_interpretable = (stmt.column_int (4) == 1);
        row.filesize = stmt.column_int64 (5);
        row.timestamp = stmt.column_int64 (6);
        row.exposure_time = stmt.column_int64 (7);
        row.import_id.id = stmt.column_int64 (8);
        row.event_id.id = stmt.column_int64 (9);
        row.md5 = stmt.column_text (10);
        row.time_created = stmt.column_int64 (11);
        row.title = stmt.column_text (12);
        row.backlinks = stmt.column_text (13);
        row.time_reimported = stmt.column_int64 (14);
        row.flags = stmt.column_int64 (15);
        row.comment = stmt.column_text (16);

        return row;
    }

    public Gee.ArrayList < VideoRow?> get_all () {

        var stmt = create_stmt (
                      "SELECT id, filename, width, height, clip_duration, is_interpretable, filesize, "
                      + "timestamp, exposure_time, import_id, event_id, md5, time_created, title, "
                      + "backlinks, time_reimported, flags, comment FROM VideoTable");

        Gee.ArrayList < VideoRow?> all = new Gee.ArrayList < VideoRow?> ();

        while (stmt.step () == Sqlite.ROW) {
            VideoRow row = new VideoRow ();
            row.video_id.id = stmt.column_int64 (0);
            row.filepath = stmt.column_text (1);
            row.width = stmt.column_int (2);
            row.height = stmt.column_int (3);
            row.clip_duration = stmt.column_double (4);
            row.is_interpretable = (stmt.column_int (5) == 1);
            row.filesize = stmt.column_int64 (6);
            row.timestamp = (int64) stmt.column_int64 (7);
            row.exposure_time = (int64) stmt.column_int64 (8);
            row.import_id.id = stmt.column_int64 (9);
            row.event_id.id = stmt.column_int64 (10);
            row.md5 = stmt.column_text (11);
            row.time_created = (int64) stmt.column_int64 (12);
            row.title = stmt.column_text (13);
            row.backlinks = stmt.column_text (14);
            row.time_reimported = (int64) stmt.column_int64 (15);
            row.flags = stmt.column_int64 (16);
            row.comment = stmt.column_text (17);

            all.add (row);
        }

        return all;
    }

    public void set_filepath (VideoID video_id, string filepath) throws DatabaseError {
        update_text_by_id_2 (video_id.id, "filename", filepath);
    }

    public void set_title (VideoID video_id, string? new_title) throws DatabaseError {
        update_text_by_id_2 (video_id.id, "title", new_title != null ? new_title : "");
    }

    public void set_comment (VideoID video_id, string? new_comment) throws DatabaseError {
        update_text_by_id_2 (video_id.id, "comment", new_comment != null ? new_comment : "");
    }

    public void set_exposure_time (VideoID video_id, int64 time) throws DatabaseError {
        update_int64_by_id_2 (video_id.id, "exposure_time", time);
    }

    public void set_flags (VideoID video_id, uint64 flags) throws DatabaseError {
        update_int64_by_id_2 (video_id.id, "flags", (int64) flags);
    }

    public void update_backlinks (VideoID video_id, string? backlinks) throws DatabaseError {
        update_text_by_id_2 (video_id.id, "backlinks", backlinks != null ? backlinks : "");
    }

    public void update_is_interpretable (VideoID video_id, bool is_interpretable) throws DatabaseError {
        update_int_by_id_2 (video_id.id, "is_interpretable", (is_interpretable) ? 1 : 0);
    }

    public bool set_event (VideoID video_id, EventID event_id) {
        return update_int64_by_id (video_id.id, "event_id", event_id.id);
    }

    public void remove_by_file (File file) throws DatabaseError {
        var stmt = create_stmt ("DELETE FROM VideoTable WHERE filename=?");

        bind_text (stmt, 1, file.get_path ());

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            throw_error ("VideoTable.remove_by_file", res);
    }

    public void remove (VideoID video_id) throws DatabaseError {
        var stmt = create_stmt ("DELETE FROM VideoTable WHERE id=?");

        bind_int64 (stmt, 1, video_id.id);

        var res = stmt.step ();
        if (res != Sqlite.DONE)
            throw_error ("VideoTable.remove", res);
    }

    public bool is_video_stored (File file) {
        return get_id (file).is_valid ();
    }

    public VideoID get_id (File file) {
        var stmt = create_stmt ("SELECT ID FROM VideoTable WHERE filename=?");

        bind_text (stmt, 1, file.get_path ());

        var res = stmt.step ();
        return (res == Sqlite.ROW) ? VideoID (stmt.column_int64 (0)) : VideoID ();
    }

    public Gee.ArrayList < VideoID?> get_videos () throws DatabaseError {
        var stmt = create_stmt ("SELECT id FROM VideoTable");

        Gee.ArrayList < VideoID?> video_ids = new Gee.ArrayList < VideoID?> ();
        for (;;) {
            var res = stmt.step ();
            if (res == Sqlite.DONE) {
                break;
            } else if (res != Sqlite.ROW) {
                throw_error ("VideoTable.get_videos", res);
            }

            video_ids.add (VideoID (stmt.column_int64 (0)));
        }

        return video_ids;
    }

    private Sqlite.Statement get_duplicate_stmt (File? file, string? md5) {
        assert (file != null || md5 != null);

        string sql = "SELECT id FROM VideoTable WHERE";
        bool first = true;

        if (file != null) {
            sql += " filename=?";
            first = false;
        }

        if (md5 != null) {
            if (!first)
                sql += " OR ";

            sql += " md5=?";
        }


        var stmt = create_stmt (sql);

        int col = 1;

        if (file != null) {
            bind_text (stmt, col++, file.get_path ());
        }

        if (md5 != null) {
            bind_text (stmt, col++, md5);
        }

        return stmt;
    }

    public bool has_duplicate (File? file, string? md5) {
        Sqlite.Statement stmt = get_duplicate_stmt (file, md5);
        int res = stmt.step ();

        if (res == Sqlite.DONE) {
            // not found
            return false;
        } else if (res == Sqlite.ROW) {
            // at least one found
            return true;
        } else {
            fatal ("VideoTable.has_duplicate", res);
        }

        return false;
    }

    public VideoID[] get_duplicate_ids (File? file, string? md5) {
        Sqlite.Statement stmt = get_duplicate_stmt (file, md5);

        VideoID[] ids = new VideoID[0];

        int res = stmt.step ();
        while (res == Sqlite.ROW) {
            ids += VideoID (stmt.column_int64 (0));
            res = stmt.step ();
        }

        return ids;
    }

    public Gee.ArrayList<string> get_event_source_ids (EventID event_id) {
        var stmt = create_stmt ("SELECT id FROM VideoTable WHERE event_id = ?");

        bind_int64 (stmt, 1, event_id.id);

        Gee.ArrayList<string> result = new Gee.ArrayList<string> ();
        for (;;) {
            var res = stmt.step ();
            if (res == Sqlite.DONE) {
                break;
            } else if (res != Sqlite.ROW) {
                fatal ("get_event_source_ids", res);

                break;
            }

            result.add (VideoID.upgrade_video_id_to_source_id (VideoID (stmt.column_int64 (0))));
        }

        return result;
    }

    public void set_timestamp (VideoID video_id, int64 timestamp) throws DatabaseError {
        update_int64_by_id_2 (video_id.id, "timestamp", timestamp);
    }
}
