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

public class Library.LastImportSidebarEntry : Library.HideablePageEntry {
    public LastImportSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.import_roll_altered.connect (on_import_rolls_altered);

        visible = (MediaCollectionRegistry.get_instance ().get_last_import_id () != null);
    }

    ~LastImportSidebarEntry () {
        foreach (MediaSourceCollection media_sources in MediaCollectionRegistry.get_instance ().get_all ())
            media_sources.import_roll_altered.disconnect (on_import_rolls_altered);
    }

    public override string get_sidebar_name () {
        return LastImportPage.NAME;
    }

    public override Icon? get_sidebar_icon () {
        return new ThemedIcon (Resources.ICON_LAST_IMPORT);
    }

    protected override Page create_page () {
        return new LastImportPage ();
    }

    private void on_import_rolls_altered () {
        visible = (MediaCollectionRegistry.get_instance ().get_last_import_id () != null);
    }
}
