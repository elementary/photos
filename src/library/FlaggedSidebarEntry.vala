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

public class Library.FlaggedSidebarEntry : Library.HideablePageEntry, Sidebar.InternalDropTargetEntry {
    public FlaggedSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.flagged_contents_altered.connect (on_flagged_contents_altered);

        visible = (get_total_flagged () != 0);
    }

    ~FlaggedSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.flagged_contents_altered.disconnect (on_flagged_contents_altered);
    }

    public override string get_sidebar_name () {
        return FlaggedPage.NAME;
    }

    public override Icon? get_sidebar_icon () {
        return new ThemedIcon (Resources.ICON_FLAGGED_PAGE);
    }

    protected override Page create_page () {
        return new FlaggedPage ();
    }

    public bool internal_drop_received (Gee.List<MediaSource> media) {
        AppWindow.get_command_manager ().execute (new FlagUnflagCommand (media, true));

        return true;
    }

    public bool internal_drop_received_arbitrary (Gtk.SelectionData data) {
        return false;
    }

    private void on_flagged_contents_altered () {
        visible = (get_total_flagged () != 0);
    }

    private int get_total_flagged () {
        int total = 0;
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            total += media_sources.get_flagged ().size;

        return total;
    }
}
