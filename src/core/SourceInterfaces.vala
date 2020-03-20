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

// See the note in MediaInterfaces.vala for some thoughts on the theory of expanding Photos'
// features via interfaces rather than class heirarchies.

// Indexable DataSources provide raw strings that may be searched against (and, in the future,
// indexed) for free-text search queries.  DataSources implementing Indexable must prepare and
// store (i.e. cache) these strings using prepare_indexable_string(s), as preparing the strings
// for each call is expensive.
//
// When the indexable string has changed, the object should fire an alteration of
// "indexable:keywords".  The prepare methods will not do this.

public interface Indexable : DataSource {
    public abstract unowned string? get_indexable_keywords ();

    public static string? prepare_indexable_string (string? str) {
        if (is_string_empty (str))
            return null;
        return String.remove_diacritics (str.down ());
    }

    public static string? prepare_indexable_strings (string[]? strs) {
        if (strs == null || strs.length == 0)
            return null;

        StringBuilder builder = new StringBuilder ();
        int ctr = 0;
        do {
            if (!is_string_empty (strs[ctr])) {
                builder.append (strs[ctr].down ());
                if (ctr < strs.length - 1)
                    builder.append_c (' ');
            }
        } while (++ctr < strs.length);

        return !is_string_empty (builder.str) ? builder.str : null;
    }
}
