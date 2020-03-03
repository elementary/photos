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

class HierarchicalTagUtilities {

    /**
     * converts a flat tag name 'name' (e.g., "Animals") to a tag path compatible with the
     * hierarchical tag data model (e.g., "/Animals"). if 'name' is already a path compatible with
     * the hierarchical data model, 'name' is returned untouched
     */
    public static string flat_to_hierarchical (string name) {
        if (!name.has_prefix (Tag.PATH_SEPARATOR_STRING))
            return Tag.PATH_SEPARATOR_STRING + name;
        else
            return name;
    }

    /**
     * converts a hierarchical tag path 'path' (e.g., "/Animals") to a flat tag name
     * (e.g., "Animals"); if 'path' is already a flat tag name, 'path' is returned untouched; note
     * that 'path' must be a top-level path (i.e., "/Animals" not "/Animals/Mammals/...") with
     * only one path component; invoking this method with a 'path' argument other than a top-level
     * path will cause an assertion failure.
     */
    public static string hierarchical_to_flat (string path) {
        if (path.has_prefix (Tag.PATH_SEPARATOR_STRING)) {
            assert (enumerate_path_components (path).size == 1);

            return path.substring (1);
        } else {
            return path;
        }
    }

    /**
     * given a path 'path', generate all parent paths of 'path' and return them in sorted order,
     * from most basic to most derived. For example, if 'path' == "/Animals/Mammals/Elephant",
     * the list { "/Animals", "/Animals/Mammals" } is returned
     */
    public static Gee.List<string> enumerate_parent_paths (string in_path) {
        string path = flat_to_hierarchical (in_path);

        Gee.List<string> result = new Gee.ArrayList<string> ();

        string accumulator = "";
        foreach (string component in enumerate_path_components (path)) {
            accumulator += (Tag.PATH_SEPARATOR_STRING + component);
            if (accumulator != path)
                result.add (accumulator);
        }

        return result;
    }

    /**
     * given a path 'path', enumerate all of the components of 'path' and return them in
     * order, excluding the path component separator. For example if
     * 'path' == "/Animals/Mammals/Elephant" the list { "Animals",  "Mammals", "Elephant" } will
     * be returned
     */
    public static Gee.List<string> enumerate_path_components (string in_path) {
        string path = flat_to_hierarchical (in_path);

        Gee.ArrayList<string> components = new Gee.ArrayList<string> ();

        string[] raw_components = path.split (Tag.PATH_SEPARATOR_STRING);

        foreach (string component in raw_components) {
            if (component != "")
                components.add (component);
        }

        assert (components.size > 0);

        return components;
    }

    public static string get_basename (string in_path) {
        string path = flat_to_hierarchical (in_path);

        Gee.List<string> components = enumerate_path_components (path);

        string basename = components.get (components.size - 1);

        return basename;
    }

    public static string? canonicalize (string in_tag, string foreign_separator) {
        string result = in_tag.replace (foreign_separator, Tag.PATH_SEPARATOR_STRING);

        if (!result.has_prefix (Tag.PATH_SEPARATOR_STRING))
            result = Tag.PATH_SEPARATOR_STRING + result;

        // ensure the result has text other than separators in it
        bool is_valid = false;
        for (int i = 0; i < result.length; i++) {
            if (result[i] != Tag.PATH_SEPARATOR_STRING[0]) {
                is_valid = true;
                break;
            }
        }

        return (is_valid) ? result : null;
    }

    public static string make_flat_tag_safe (string in_tag) {
        return in_tag.replace (Tag.PATH_SEPARATOR_STRING, "-");
    }

    public static HierarchicalTagIndex process_hierarchical_import_keywords (Gee.Collection<string> h_keywords) {
        HierarchicalTagIndex index = new HierarchicalTagIndex ();

        foreach (string keyword in h_keywords) {
            Gee.List<string> parent_paths =
                HierarchicalTagUtilities.enumerate_parent_paths (keyword);
            Gee.List<string> path_components =
                HierarchicalTagUtilities.enumerate_path_components (keyword);

            assert (parent_paths.size <= path_components.size);

            for (int i = 0; i < parent_paths.size; i++) {
                if (!index.is_path_known (path_components[i]))
                    index.add_path (path_components[i], parent_paths[i]);
            }

            index.add_path (HierarchicalTagUtilities.get_basename (keyword), keyword);
        }

        return index;
    }

    public static string? get_root_path_form (string? client_path) {
        if (client_path == null)
            return null;

        if (HierarchicalTagUtilities.enumerate_parent_paths (client_path).size != 0)
            return client_path;

        string path = client_path;

        if (!Tag.global.exists (path)) {
            if (path.has_prefix (Tag.PATH_SEPARATOR_STRING))
                path = HierarchicalTagUtilities.hierarchical_to_flat (path);
            else
                path = HierarchicalTagUtilities.flat_to_hierarchical (path);
        }

        return (Tag.global.exists (path)) ? path : null;
    }

    public static void cleanup_root_path (string path) {
        Gee.List<string> paths = HierarchicalTagUtilities.enumerate_parent_paths (path);

        if (paths.size == 0) {
            string? actual_path = HierarchicalTagUtilities.get_root_path_form (path);

            if (actual_path == null)
                return;

            Tag? t = null;
            if (Tag.global.exists (actual_path))
                t = Tag.for_path (actual_path);

            if (t != null && t.get_hierarchical_children ().size == 0)
                t.flatten ();
        }
    }
}
