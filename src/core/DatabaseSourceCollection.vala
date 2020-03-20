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

public delegate int64 GetSourceDatabaseKey (DataSource source);

// A DatabaseSourceCollection is a SourceCollection that understands database keys (IDs) and the
// nature that a row in a database can only be instantiated once in the system, and so it tracks
// their existence in a map so they can be fetched by their key.
//
// TODO: This would be better implemented as an observer class, possibly with an interface to
// force subclasses to provide a fetch_by_key () method.
public abstract class DatabaseSourceCollection : SourceCollection {
    private unowned GetSourceDatabaseKey source_key_func;
    private Gee.HashMap < int64?, DataSource > map = new Gee.HashMap < int64?, DataSource > (int64_hash,
            int64_equal);

    protected DatabaseSourceCollection (string name, GetSourceDatabaseKey source_key_func) {
        base (name);

        this.source_key_func = source_key_func;
    }

    public override void notify_items_added (Gee.Iterable<DataObject> added) {
        foreach (DataObject object in added) {
            DataSource source = (DataSource) object;
            int64 key = source_key_func (source);

            assert (!map.has_key (key));

            map.set (key, source);
        }

        base.notify_items_added (added);
    }

    public override void notify_items_removed (Gee.Iterable<DataObject> removed) {
        foreach (DataObject object in removed) {
            int64 key = source_key_func ((DataSource) object);

            bool is_removed = map.unset (key);
            assert (is_removed);
        }

        base.notify_items_removed (removed);
    }

    protected DataSource fetch_by_key (int64 key) {
        return map.get (key);
    }
}

public class DatabaseSourceHoldingTank : SourceHoldingTank {
    private unowned GetSourceDatabaseKey get_key;
    private Gee.HashMap < int64?, DataSource > map = new Gee.HashMap < int64?, DataSource > (int64_hash,
            int64_equal);

    public DatabaseSourceHoldingTank (SourceCollection sources,
                                      SourceHoldingTank.CheckToKeep check_to_keep, GetSourceDatabaseKey get_key) {
        base (sources, check_to_keep);

        this.get_key = get_key;
    }

    public DataSource? get_by_id (int64 id) {
        return map.get (id);
    }

    protected override void notify_contents_altered (Gee.Collection<DataSource>? added,
            Gee.Collection<DataSource>? removed) {
        if (added != null) {
            foreach (DataSource source in added)
                map.set (get_key (source), source);
        }

        if (removed != null) {
            foreach (DataSource source in removed)
                map.unset (get_key (source));
        }

        base.notify_contents_altered (added, removed);
    }
}
