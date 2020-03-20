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

public class Library.OfflineSidebarEntry : Library.HideablePageEntry {
    public OfflineSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.offline_contents_altered.connect (on_offline_contents_altered);

        visible = (get_total_offline () != 0);
    }

    ~OfflineSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.trashcan_contents_altered.disconnect (on_offline_contents_altered);
    }

    public override string get_sidebar_name () {
        return OfflinePage.NAME;
    }

    public override Icon? get_sidebar_icon () {
        return new ThemedIcon (Resources.ICON_MISSING_FILES);
    }

    protected override Page create_page () {
        return new OfflinePage ();
    }

    private void on_offline_contents_altered () {
        visible = (get_total_offline () != 0);
    }

    private int get_total_offline () {
        int total = 0;
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            total += media_sources.get_offline_bin_contents ().size;

        return total;
    }
}
