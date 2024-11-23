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

// A BatchImportRoll represents important state for a group of imported media.  If this is shared
// among multiple BatchImport objects, the imported media will appear to have been imported all at
// once.
public class BatchImportRoll {
    public ImportID import_id;
    public ViewCollection generated_events = new ViewCollection ("BatchImportRoll generated events");

    public BatchImportRoll () {
        this.import_id = ImportID.generate ();
    }
}
