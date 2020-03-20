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

public class HierarchicalTagIndex {
    private Gee.Map<string, Gee.Collection<string>> tag_table;
    private Gee.SortedSet<string> known_paths;

    public HierarchicalTagIndex () {
        this.tag_table = new Gee.HashMap<string, Gee.ArrayList<string>> ();
        this.known_paths = new Gee.TreeSet<string> ();
    }

    public static HierarchicalTagIndex from_paths (Gee.Collection<string> client_paths) {
        Gee.Collection<string> paths = client_paths.read_only_view;

        HierarchicalTagIndex result = new HierarchicalTagIndex ();

        foreach (string path in paths) {
            if (path.has_prefix (Tag.PATH_SEPARATOR_STRING)) {
                Gee.Collection<string> components =
                    HierarchicalTagUtilities.enumerate_path_components (path);

                foreach (string component in components)
                    result.add_path (component, path);
            } else {
                result.add_path (path, path);
            }
        }

        return result;
    }

    public static HierarchicalTagIndex get_global_index () {
        return HierarchicalTagIndex.from_paths (Tag.global.get_all_names ());
    }

    public void add_path (string tag, string path) {
        if (!tag_table.has_key (tag)) {
            tag_table.set (tag, new Gee.ArrayList<string> ());
        }

        tag_table.get (tag).add (path);
        known_paths.add (path);
    }

    public Gee.Collection<string> get_all_paths () {
        return known_paths.read_only_view;
    }

    public bool is_tag_in_index (string tag) {
        return tag_table.has_key (tag);
    }

    public Gee.Collection<string> get_all_tags () {
        return tag_table.keys;
    }

    public bool is_path_known (string path) {
        return known_paths.contains (path);
    }

    public string get_path_for_name (string name) {
        if (!is_tag_in_index (name))
            return name;

        Gee.Collection<string> paths = tag_table.get (name);
        foreach (string path in paths) {
            Gee.List<string> components = HierarchicalTagUtilities.enumerate_path_components (path);
            if (components.get (components.size - 1) == name) {
                return path;
            }
        }

        assert_not_reached ();
    }

    public string[] get_paths_for_names_array (string[] names) {
        string[] result = new string[0];

        foreach (string name in names)
            result += get_path_for_name (name);

        return result;
    }
}
