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

public class DirectView : DataView {
    private File file;
    private string? collate_key = null;

    public DirectView (DirectPhoto source) {
        base ((DataSource) source);

        this.file = ((Photo) source).get_file ();
    }

    public File get_file () {
        return file;
    }

    public string get_collate_key () {
        if (collate_key == null)
            collate_key = file.get_basename ().collate_key_for_filename ();

        return collate_key;
    }
}

private class DirectViewCollection : ViewCollection {
    private class DirectViewManager : ViewManager {
        public override DataView create_view (DataSource source) {
            return new DirectView ((DirectPhoto) source);
        }
    }

    public DirectViewCollection () {
        base ("DirectViewCollection");

        set_comparator (filename_comparator, null);
        monitor_source_collection (DirectPhoto.global, new DirectViewManager (), null);
    }

    private static int64 filename_comparator (void *a, void *b) {
        DirectView *aview = (DirectView *) a;
        DirectView *bview = (DirectView *) b;

        return strcmp (aview->get_collate_key (), bview->get_collate_key ());
    }
}
