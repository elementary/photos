/*
* Copyright (c) 2009-2013 Yorba Foundation
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

public class ContractMenuItem : Gtk.MenuItem {
    public Granite.Services.Contract contract { get; construct; }
    public Gee.List<DataSource> sources { get; construct; }

    public ContractMenuItem (Granite.Services.Contract contract, Gee.List<DataSource> sources) {
        Object (
            contract: contract,
            sources: sources
        );
    }

    construct {
        label = contract.get_display_name ();
        tooltip_text = contract.get_description ();
    }

    public override void activate () {
        try {
            File[] modified_files = null;
            foreach (var source in sources) {
                assert (source is Photo);
                var photo_source = (Photo)source;
                if (photo_source.get_file_format () == PhotoFileFormat.RAW ||
                    !photo_source.has_alterations ()) {

                    modified_files += photo_source.get_file ();
                } else {
                    modified_files += photo_source.get_modified_file ();
                }
            }

            contract.execute_with_files (modified_files);
        } catch (Error err) {
            warning (err.message);
        }
    }
}
