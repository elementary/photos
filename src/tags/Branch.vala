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

public class Tags.Branch : Sidebar.Branch {
    private Gee.HashMap<Tag, Tags.SidebarEntry> entry_map = new Gee.HashMap<Tag, Tags.SidebarEntry> ();

    public Branch () {
        base (new Tags.Grouping (),
              Sidebar.Branch.Options.HIDE_IF_EMPTY
              | Sidebar.Branch.Options.AUTO_OPEN_ON_NEW_CHILD
              | Sidebar.Branch.Options.STARTUP_OPEN_GROUPING,
              comparator);

        // seed the branch with existing tags
        on_tags_added_removed (Tag.global.get_all (), null);

        // monitor collection for future events
        Tag.global.contents_altered.connect (on_tags_added_removed);
        Tag.global.items_altered.connect (on_tags_altered);
    }

    ~Branch () {
        Tag.global.contents_altered.disconnect (on_tags_added_removed);
        Tag.global.items_altered.disconnect (on_tags_altered);
    }

    public Tags.SidebarEntry? get_entry_for_tag (Tag tag) {
        return entry_map.get (tag);
    }

    private static int comparator (Sidebar.Entry a, Sidebar.Entry b) {
        if (a == b)
            return 0;

        return Tag.compare_names (((Tags.SidebarEntry) a).for_tag (),
                                  ((Tags.SidebarEntry) b).for_tag ());
    }

    private void on_tags_added_removed (Gee.Iterable<DataObject>? added_raw, Gee.Iterable<DataObject>? removed) {
        // Store the tag whose page we'll eventually want to go to,
        // since this is lost when a tag is reparented (pruning a currently-
        // highlighted entry from the tree causes the highlight to go to the library,
        // and reparenting requires pruning the old location (along with adding the new one)).
        Tag? restore_point = null;

        if (added_raw != null) {
            // prepare a collection of tags guaranteed to be sorted; this is critical for
            // hierarchical tags since it ensures that parent tags must be encountered
            // before their children
            Gee.SortedSet<Tag> added = new Gee.TreeSet<Tag> (Tag.compare_names);
            foreach (DataObject object in added_raw) {
                Tag tag = (Tag) object;
                added.add (tag);
            }

            foreach (Tag tag in added) {
                // ensure that all parent tags of this tag (if any) already have sidebar
                // entries
                Tag? parent_tag = tag.get_hierarchical_parent ();
                while (parent_tag != null) {
                    if (!entry_map.has_key (parent_tag)) {
                        Tags.SidebarEntry parent_entry = new Tags.SidebarEntry (parent_tag);
                        entry_map.set (parent_tag, parent_entry);
                    }

                    parent_tag = parent_tag.get_hierarchical_parent ();

                }

                Tags.SidebarEntry entry = new Tags.SidebarEntry (tag);
                entry_map.set (tag, entry);

                parent_tag = tag.get_hierarchical_parent ();
                if (parent_tag != null) {
                    Tags.SidebarEntry parent_entry = entry_map.get (parent_tag);
                    graft (parent_entry, entry);
                } else {
                    graft (get_root (), entry);
                }

                // Save the most-recently-processed on tag.  During a reparenting,
                // this will be the only tag processed.
                restore_point = tag;
            }
        }

        if (removed != null) {
            foreach (DataObject object in removed) {
                Tag tag = (Tag) object;

                Tags.SidebarEntry? entry = entry_map.get (tag);
                assert (entry != null);

                bool is_removed = entry_map.unset (tag);
                assert (is_removed);

                prune (entry);
            }
        }
    }

    private void on_tags_altered (Gee.Map<DataObject, Alteration> altered) {
        foreach (DataObject object in altered.keys) {
            if (!altered.get (object).has_detail ("metadata", "name"))
                continue;

            Tag tag = (Tag) object;
            Tags.SidebarEntry? entry = entry_map.get (tag);
            assert (entry != null);

            entry.sidebar_name_changed (tag.get_user_visible_name ());
            entry.sidebar_tooltip_changed (tag.get_user_visible_name ());
            reorder (entry);
        }
    }
}

public class Tags.Grouping : Sidebar.Grouping, Sidebar.InternalDropTargetEntry,
    Sidebar.InternalDragSourceEntry, Sidebar.Contextable {
    private Gtk.Menu? context_menu = null;

    public Grouping () {
        base (_ ("Tags"), new ThemedIcon (Resources.ICON_TAGS));
    }

    public bool internal_drop_received (Gee.List<MediaSource> media) {
        return true;
    }

    public bool internal_drop_received_arbitrary (Gtk.SelectionData data) {
        if (data.get_data_type ().name () == LibraryWindow.TAG_PATH_MIME_TYPE) {
            string old_tag_path = (string) data.get_data ();
            assert (Tag.global.exists (old_tag_path));

            // if this is already a top-level tag, do a short-circuit return
            if (HierarchicalTagUtilities.enumerate_path_components (old_tag_path).size < 2)
                return true;

            AppWindow.get_command_manager ().execute (
                new ReparentTagCommand (Tag.for_path (old_tag_path), "/"));

            return true;
        }

        return false;
    }

    public void prepare_selection_data (Gtk.SelectionData data) {
        ;
    }

    public Gtk.Menu? get_sidebar_context_menu (Gdk.EventButton? event) {
        if (context_menu == null) {
            context_menu = new Gtk.Menu ();

            var new_tag_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.NEW_CHILD_TAG_SIDEBAR_MENU);
            new_tag_menu_item.activate.connect (() => on_new_tag);
            context_menu.add (new_tag_menu_item);
            context_menu.show_all ();
        }

        return context_menu;
    }

    private void on_new_tag () {
        NewRootTagCommand creation_command = new NewRootTagCommand ();
        AppWindow.get_command_manager ().execute (creation_command);
        LibraryWindow.get_app ().rename_tag_in_sidebar (creation_command.get_created_tag ());
    }
}

public class Tags.SidebarEntry : Sidebar.SimplePageEntry, Sidebar.RenameableEntry,
    Sidebar.DestroyableEntry, Sidebar.InternalDropTargetEntry, Sidebar.ExpandableEntry,
    Sidebar.InternalDragSourceEntry {
    private static Icon single_tag_icon;

    private Tag tag;

    class construct {
        single_tag_icon = new ThemedIcon (Resources.ICON_ONE_TAG);
    }

    public SidebarEntry (Tag tag) {
        this.tag = tag;
    }

    public Tag for_tag () {
        return tag;
    }

    public override string get_sidebar_name () {
        return tag.get_user_visible_name ();
    }

    public override Icon? get_sidebar_icon () {
        return single_tag_icon;
    }

    protected override Page create_page () {
        return new TagPage (tag);
    }

    public void rename (string new_name) {
        string? prepped = Tag.prep_tag_name (new_name);
        if (prepped == null)
            return;

        prepped = prepped.replace ("/", "");

        if (prepped == tag.get_user_visible_name ())
            return;

        if (prepped == "")
            return;

        AppWindow.get_command_manager ().execute (new RenameTagCommand (tag, prepped));
    }

    public void destroy_source () {
        if (Dialogs.confirm_delete_tag (tag))
            AppWindow.get_command_manager ().execute (new DeleteTagCommand (tag));
    }

    public bool internal_drop_received (Gee.List<MediaSource> media) {
        AppWindow.get_command_manager ().execute (new TagUntagPhotosCommand (tag, media, media.size,
                true));

        return true;
    }

    public bool internal_drop_received_arbitrary (Gtk.SelectionData data) {
        if (data.get_data_type ().name () == LibraryWindow.TAG_PATH_MIME_TYPE) {
            string old_tag_path = (string) data.get_data ();

            // if we're dragging onto ourself, it's a no-op
            if (old_tag_path == tag.get_path ())
                return true;

            // if we're dragging onto one of our children, it's a no-op
            foreach (string parent_path in HierarchicalTagUtilities.enumerate_parent_paths (tag.get_path ())) {
                if (parent_path == old_tag_path)
                    return true;
            }

            assert (Tag.global.exists (old_tag_path));

            // if we're dragging onto our parent, it's a no-op
            Tag old_tag = Tag.for_path (old_tag_path);
            Tag old_tag_parent = old_tag.get_hierarchical_parent ();
            if (old_tag_parent != null && old_tag_parent.get_path () == tag.get_path ())
                return true;

            AppWindow.get_command_manager ().execute (
                new ReparentTagCommand (old_tag, tag.get_path ()));

            return true;
        }

        return false;
    }

    public Icon? get_sidebar_open_icon () {
        return single_tag_icon;
    }

    public Icon? get_sidebar_closed_icon () {
        return single_tag_icon;
    }

    public bool expand_on_select () {
        return false;
    }

    public void prepare_selection_data (Gtk.SelectionData data) {
        data.set (Gdk.Atom.intern_static_string (LibraryWindow.TAG_PATH_MIME_TYPE), 0,
                  tag.get_path ().data);
    }
}

