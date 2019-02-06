/*
* Copyright (c) 2010-2013 Yorba Foundation
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

//
// Going forward, Photos will use MediaInterfaces, which allow for various operations and features
// to be added only to the MediaSources that support them (or make sense for).  For example, adding
// a library-mode photo or video to an Event makes perfect sense, but does not make sense for a
// direct-mode photo.  All three are MediaSources, and to make DirectPhoto descend from another
// base class is only inviting chaos and a tremendous amount of replicated code.
//
// A key point to make of all MediaInterfaces is that they require MediaSource as a base class.
// Thus, any code dealing with one of these interfaces knows they are also dealing with a
// MediaSource.
//
// TODO: Make Eventable and Taggable interfaces, which are the only types Event and Tag will deal
// with (rather than MediaSources).
//
// TODO: Make Trashable interface, which are much like Flaggable.
//
// TODO: ContainerSources may also have specific needs in the future; an interface-based system
// may make sense as well when that need arises.
//

//
// TransactionController
//
// Because many operations in Photos need to be performed on collections of objects all at once,
// and that most of these objects are backed by a database, the TransactionController object gives
// a way to generically group a series of operations on one or more similar objects into a single
// transaction. This class is listed here because it's used by the various media interfaces to offer
// multiple operations.
//
// begin () and commit () may be called multiple times in layering fashion.  The implementation
// accounts for this.  If either throws an exception it should be assumed that the object is in
// a "clean" state; that is, if begin () throws an exception, there is no need to call commit (),
// and if commit () throws an exception, it does not need to be called again to revert the object
// state.
//
// This means that any user who calls begin () *must* match it with a corresponding commit (), even
// if there is an error during the transaction.  It is up to the user to back out any undesired
// changes.
//
// Because of the nature of this object, it's assumed that every object type will share one
// between all callers.
//
// The object is thread-safe.  There is no guarantee that the underlying persistent store is,
// however.
public abstract class TransactionController {
    private int count = 0;

    public TransactionController () {
    }

    ~TransactionController () {
        lock (count) {
            assert (count == 0);
        }
    }

    public void begin () {
        lock (count) {
            if (count++ != 0)
                return;

            try {
                begin_impl ();
            } catch (Error err) {
                // unwind
                count--;

                if (err is DatabaseError)
                    AppWindow.database_error ((DatabaseError) err);
                else
                    AppWindow.panic ("%s".printf (err.message));
            }
        }
    }

    // For thread safety, this method will only be called under the protection of a mutex.
    public abstract void begin_impl () throws Error;

    public void commit () {
        lock (count) {
            assert (count > 0);
            if (--count != 0)
                return;

            // no need to unwind the count here; it's already unwound.
            try {
                commit_impl ();
            } catch (Error err) {
                if (err is DatabaseError)
                    AppWindow.database_error ((DatabaseError) err);
                else
                    AppWindow.panic ("%s".printf (err.message));
            }
        }
    }

    // For thread safety, this method will only be called under the protection of a mutex.
    public abstract void commit_impl () throws Error;
}

//
// Flaggable
//
// Flaggable media can be marked for later use in batch operations.
//
// The mark_flagged () and mark_unflagged () methods should fire "metadata:flags" and "metadata:flagged"
// alterations if the flag has changed.
public interface Flaggable : MediaSource {
    public abstract bool is_flagged ();

    public abstract void mark_flagged ();

    public abstract void mark_unflagged ();

    public static void mark_many_flagged_unflagged (Gee.Collection<Flaggable>? flag,
            Gee.Collection<Flaggable>? unflag, TransactionController controller) throws Error {
        controller.begin ();

        if (flag != null) {
            foreach (Flaggable flaggable in flag)
                flaggable.mark_flagged ();
        }

        if (unflag != null) {
            foreach (Flaggable flaggable in unflag)
                flaggable.mark_unflagged ();
        }

        controller.commit ();
    }
}

//
// Monitorable
//
// Monitorable media can be updated at startup or run-time about changes to their backing file(s).
//
// The mark_online () and mark_offline () methods should fire "metadata:flags" and "metadata:online-state"
// alterations if the flag has changed.
//
// The set_master_file () method should fire "backing:master" alteration and "metadata:name" if
// the name of the file is determined by the filename (which is default behavior).  It should also
// call notify_master_file_replaced ().
//
// The set_master_timestamp () method should fire "metadata:master-timestamp" alteration.
public interface Monitorable : MediaSource {
    public abstract bool is_offline ();

    public abstract void mark_online ();

    public abstract void mark_offline ();

    public static void mark_many_online_offline (Gee.Collection<Monitorable>? online,
            Gee.Collection<Monitorable>? offline, TransactionController controller) throws Error {
        controller.begin ();

        if (online != null) {
            foreach (Monitorable monitorable in online)
                monitorable.mark_online ();
        }

        if (offline != null) {
            foreach (Monitorable monitorable in offline)
                monitorable.mark_offline ();
        }

        controller.commit ();
    }

    public abstract void set_master_file (File file);

    public static void set_many_master_file (Gee.Map<Monitorable, File> map,
            TransactionController controller) throws Error {
        controller.begin ();

        Gee.MapIterator<Monitorable, File> map_iter = map.map_iterator ();
        while (map_iter.next ())
            map_iter.get_key ().set_master_file (map_iter.get_value ());

        controller.commit ();
    }

    public abstract void set_master_timestamp (FileInfo info);

    public static void set_many_master_timestamp (Gee.Map<Monitorable, FileInfo> map,
            TransactionController controller) throws Error {
        controller.begin ();

        Gee.MapIterator<Monitorable, FileInfo> map_iter = map.map_iterator ();
        while (map_iter.next ())
            map_iter.get_key ().set_master_timestamp (map_iter.get_value ());

        controller.commit ();
    }
}

//
// Dateable
//
// Dateable media may have their exposure date and time set arbitrarily.
//
// The set_exposure_time () method refactors the existing set_exposure_time ()
// from Photo to here in order to add this capability to videos. It should
// fire a "metadata:exposure-time" alteration when called.
public interface Dateable : MediaSource {
    public abstract void set_exposure_time (time_t target_time);

    public abstract time_t get_exposure_time ();
}
