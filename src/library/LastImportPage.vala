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

public class LastImportPage : CollectionPage {
    public const string NAME = _ ("Last Import");

    private class LastImportViewManager : CollectionViewManager {
        private ImportID import_id;

        public LastImportViewManager (LastImportPage owner, ImportID import_id) {
            base (owner);

            this.import_id = import_id;
        }

        public override bool include_in_view (DataSource source) {
            return ((MediaSource) source).get_import_id ().id == import_id.id;
        }
    }

    private ImportID last_import_id = ImportID ();
    private Alteration last_import_alteration = new Alteration ("metadata", "import-id");

    public LastImportPage () {
        base (NAME);

        // be notified when the import rolls change
        foreach (MediaSourceCollection col in MediaCollectionRegistry.get_instance ().get_all ()) {
            col.import_roll_altered.connect (on_import_rolls_altered);
        }

        // set up view manager for the last import roll
        on_import_rolls_altered ();
    }

    ~LastImportPage () {
        foreach (MediaSourceCollection col in MediaCollectionRegistry.get_instance ().get_all ()) {
            col.import_roll_altered.disconnect (on_import_rolls_altered);
        }
    }

    private void on_import_rolls_altered () {
        // see if there's a new last ImportID, or no last import at all
        ImportID? current_last_import_id =
            MediaCollectionRegistry.get_instance ().get_last_import_id ();

        if (current_last_import_id == null) {
            get_view ().halt_all_monitoring ();
            get_view ().clear ();

            return;
        }

        if (current_last_import_id.id == last_import_id.id)
            return;

        last_import_id = current_last_import_id;

        get_view ().halt_all_monitoring ();
        get_view ().clear ();

        foreach (MediaSourceCollection col in MediaCollectionRegistry.get_instance ().get_all ()) {
            get_view ().monitor_source_collection (col, new LastImportViewManager (this,
                                                  last_import_id), last_import_alteration);
        }
    }
}

