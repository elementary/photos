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

public class Library.TrashSidebarEntry : Sidebar.SimplePageEntry, Sidebar.InternalDropTargetEntry {
    private static Icon? full_icon = null;
    private static Icon? empty_icon = null;

    public TrashSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.trashcan_contents_altered.connect (on_trashcan_contents_altered);
    }

    ~TrashSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.trashcan_contents_altered.disconnect (on_trashcan_contents_altered);
    }

    internal static void init () {
        full_icon = new ThemedIcon (Resources.ICON_TRASH_FULL);
        empty_icon = new ThemedIcon (Resources.ICON_TRASH_EMPTY);
    }

    internal static void terminate () {
        full_icon = null;
        empty_icon = null;
    }

    public override string get_sidebar_name () {
        return TrashPage.NAME;
    }

    public override Icon? get_sidebar_icon () {
        return get_current_icon ();
    }

    private static Icon get_current_icon () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ()) {
            if (media_sources.get_trashcan_count () > 0)
                return full_icon;
        }

        return empty_icon;
    }

    public bool internal_drop_received (Gee.List<MediaSource> media) {
        AppWindow.get_command_manager ().execute (new TrashUntrashPhotosCommand (media, true));

        return true;
    }

    public bool internal_drop_received_arbitrary (Gtk.SelectionData data) {
        return false;
    }

    protected override Page create_page () {
        return new TrashPage ();
    }

    private void on_trashcan_contents_altered () {
        sidebar_icon_changed (get_current_icon ());
    }
}
