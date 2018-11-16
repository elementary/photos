/*
* Copyright (c) 2011-2013 Yorba Foundation
*               2018 elementary LLC. (https://elementary.io)
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

// Represents a row-type.
public abstract class SearchRow : Gtk.Grid {
    public new SearchRowContainer parent { get; construct; }

    construct {
        column_spacing = 6;
    }

    // Returns the search condition for this row.
    public abstract SearchCondition get_search_condition ();

    // Fills out the fields in this row based on an existing search condition (for edit mode.)
    public abstract void populate (SearchCondition sc);

    // Returns true if the row is valid and complete.
    public abstract bool is_complete ();
}
