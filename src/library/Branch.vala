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

public class Library.Branch : Sidebar.Branch {
    private const string POSITION_DATA = "x-photos-entry-position";

    public Library.PhotosEntry photos_entry {
        get;
        private set;
    }
    public Library.VideosEntry videos_entry {
        get;
        private set;
    }
    public Library.RawsEntry raws_entry {
        get;
        private set;
    }
    public Library.FlaggedSidebarEntry flagged_entry {
        get;
        private set;
    }
    public Library.LastImportSidebarEntry last_imported_entry {
        get;
        private set;
    }
    public Library.ImportQueueSidebarEntry import_queue_entry {
        get;
        private set;
    }
    public Library.OfflineSidebarEntry offline_entry {
        get;
        private set;
    }
    public Library.TrashSidebarEntry trash_entry {
        get;
        private set;
    }

    // This lists the order of the library items in the sidebar. To re-order, simply move
    // the item in this list to a new position. These numbers should *not* persist anywhere
    // outside the app.
    private enum EntryPosition {
        PHOTOS,
        RAWS,
        VIDEOS,
        FLAGGED,
        LAST_IMPORTED,
        IMPORT_QUEUE,
        OFFLINE,
        TRASH
    }

    public Branch () {
        base (new Sidebar.Grouping (_ ("Library"), null),
              Sidebar.Branch.Options.STARTUP_OPEN_GROUPING, comparator);

        photos_entry = new Library.PhotosEntry ();
        videos_entry = new Library.VideosEntry ();
        raws_entry = new Library.RawsEntry ();
        trash_entry = new Library.TrashSidebarEntry ();
        last_imported_entry = new Library.LastImportSidebarEntry ();
        flagged_entry = new Library.FlaggedSidebarEntry ();
        offline_entry = new Library.OfflineSidebarEntry ();
        import_queue_entry = new Library.ImportQueueSidebarEntry ();

        insert (photos_entry, EntryPosition.PHOTOS);
        insert (raws_entry, EntryPosition.RAWS);
        insert (trash_entry, EntryPosition.TRASH);

        videos_entry.visibility_changed.connect (on_videos_visibility_changed);
        on_videos_visibility_changed ();

        flagged_entry.visibility_changed.connect (on_flagged_visibility_changed);
        on_flagged_visibility_changed ();

        last_imported_entry.visibility_changed.connect (on_last_imported_visibility_changed);
        on_last_imported_visibility_changed ();

        import_queue_entry.visibility_changed.connect (on_import_queue_visibility_changed);
        on_import_queue_visibility_changed ();

        offline_entry.visibility_changed.connect (on_offline_visibility_changed);
        on_offline_visibility_changed ();
    }

    private void insert (Sidebar.Entry entry, int position) {
        entry.set_data<int> (POSITION_DATA, position);
        graft (get_root (), entry);
    }

    private void on_videos_visibility_changed () {
        update_entry_visibility (videos_entry, EntryPosition.VIDEOS);
    }

    private void on_flagged_visibility_changed () {
        update_entry_visibility (flagged_entry, EntryPosition.FLAGGED);
    }

    private void on_last_imported_visibility_changed () {
        update_entry_visibility (last_imported_entry, EntryPosition.LAST_IMPORTED);
    }

    private void on_import_queue_visibility_changed () {
        update_entry_visibility (import_queue_entry, EntryPosition.IMPORT_QUEUE);
    }

    private void on_offline_visibility_changed () {
        update_entry_visibility (offline_entry, EntryPosition.OFFLINE);
    }

    private void update_entry_visibility (Library.HideablePageEntry entry, int position) {
        if (entry.visible) {
            if (!has_entry (entry))
                insert (entry, position);
        } else if (has_entry (entry)) {
            prune (entry);
        }
    }

    private static int comparator (Sidebar.Entry a, Sidebar.Entry b) {
        return a.get_data<int> (POSITION_DATA) - b.get_data<int> (POSITION_DATA);
    }
}

public abstract class Library.HideablePageEntry : Sidebar.SimplePageEntry {
    // container branch should listen to this signal
    public signal void visibility_changed (bool visible);

    private bool show_entry = false;
    public bool visible {
        get {
            return show_entry;
        } set {
            if (value == show_entry)
                return;

            show_entry = value;
            visibility_changed (value);
        }
    }

    public HideablePageEntry () {
    }
}

public class Library.MainPage : CollectionPage {
    public const string NAME = _ ("Library");

    public MainPage (ProgressMonitor? monitor = null) {
        base (NAME);

        foreach (MediaSourceCollection sources in MediaCollectionRegistry.get_instance ().get_all ())
            get_view ().monitor_source_collection (sources, new CollectionViewManager (this), null, null, monitor);
    }

    public override string get_back_name () {
        return _("All Photos");
    }
}
