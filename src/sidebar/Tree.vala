/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
*               2011-2013 Yorba Foundation
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

public class Sidebar.Tree : Gtk.TreeView {
    // Only one ExternalDropHandler can be registered with the Tree; it's responsible for completing
    // the "drag-data-received" signal properly.
    public delegate void ExternalDropHandler (Gdk.DragContext context, Sidebar.Entry? entry,
            Gtk.SelectionData data, uint info, uint time);

    private class EntryWrapper : Object {
        public Sidebar.Entry entry;
        public Gtk.TreeRowReference row;

        public EntryWrapper (Gtk.TreeModel model, Sidebar.Entry entry, Gtk.TreePath path) {
            this.entry = entry;
            this.row = new Gtk.TreeRowReference (model, path);
        }

        public Gtk.TreePath get_path () {
            return row.get_path ();
        }

        public Gtk.TreeIter get_iter () {
            Gtk.TreeIter iter;
            bool valid = row.get_model ().get_iter (out iter, get_path ());
            assert (valid);

            return iter;
        }
    }

    private class RootWrapper : EntryWrapper {
        public int root_position;

        public RootWrapper (Gtk.TreeModel model, Sidebar.Entry entry, Gtk.TreePath path, int root_position)
        requires (root_position >= 0) {
            base (model, entry, path);

            this.root_position = root_position;
        }
    }

    private enum Columns {
        NAME,
        TOOLTIP,
        WRAPPER,
        ICON,
        CLOSED_PIXBUF,
        OPEN_PIXBUF,
        PIXBUF_VISIBLE,
        N_COLUMNS
    }

    private Gtk.TreeStore store = new Gtk.TreeStore (Columns.N_COLUMNS,
            typeof (string),            // NAME
            typeof (string? ),          // TOOLTIP
            typeof (EntryWrapper),      // WRAPPER
            typeof (GLib.Icon?),      // PIXBUF
            typeof (Gdk.Pixbuf? ),      // CLOSED_PIXBUF
            typeof (Gdk.Pixbuf? ),      // OPEN_PIXBUF
            typeof (bool)               // PIXBUF_VISIBLE
                                                    );

    private Gtk.IconTheme icon_theme;
    private Gtk.CellRendererText text_renderer;
    private unowned ExternalDropHandler drop_handler;
    private Gtk.Entry? text_entry = null;
    private Gee.HashMap<string, Gdk.Pixbuf> icon_cache = new Gee.HashMap<string, Gdk.Pixbuf> ();
    private Gee.HashMap<Sidebar.Entry, EntryWrapper> entry_map =
        new Gee.HashMap<Sidebar.Entry, EntryWrapper> ();
    private Gee.HashMap<Sidebar.Branch, int> branches = new Gee.HashMap<Sidebar.Branch, int> ();
    private int editing_disabled = 0;
    private bool mask_entry_selected_signal = false;
    private weak EntryWrapper? selected_wrapper = null;
    private Gtk.Menu? default_context_menu = null;
    private bool is_internal_drag_in_progress = false;
    private Sidebar.Entry? internal_drag_source_entry = null;
    private Gtk.TreeRowReference? old_path_ref = null;

    public signal void entry_selected (Sidebar.SelectableEntry selectable);

    public signal void selected_entry_removed (Sidebar.SelectableEntry removed);

    public signal void branch_added (Sidebar.Branch branch);

    public signal void branch_removed (Sidebar.Branch branch);

    public signal void branch_shown (Sidebar.Branch branch, bool shown);

    public signal void page_created (Sidebar.PageRepresentative entry, Page page);

    public signal void destroying_page (Sidebar.PageRepresentative entry, Page page);

    public Tree (Gtk.TargetEntry[] target_entries, Gdk.DragAction actions,
                 ExternalDropHandler drop_handler) {
        set_model (store);

        Gtk.TreeViewColumn text_column = new Gtk.TreeViewColumn ();
        text_column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
        Gtk.CellRendererPixbuf icon_renderer = new Gtk.CellRendererPixbuf ();
        text_column.pack_start (icon_renderer, false);
        text_column.add_attribute (icon_renderer, "gicon", Columns.ICON);
        text_column.add_attribute (icon_renderer, "pixbuf_expander_closed", Columns.CLOSED_PIXBUF);
        text_column.add_attribute (icon_renderer, "pixbuf_expander_open", Columns.OPEN_PIXBUF);
        text_column.add_attribute (icon_renderer, "visible", Columns.PIXBUF_VISIBLE);
        text_renderer = new Gtk.CellRendererText ();
        text_renderer.editing_canceled.connect (on_editing_canceled);
        text_renderer.editing_started.connect (on_editing_started);
        text_renderer.ellipsize = Pango.EllipsizeMode.END;
        text_column.pack_start (text_renderer, true);
        text_column.add_attribute (text_renderer, "markup", Columns.NAME);
        append_column (text_column);

        Gtk.CellRendererText invisitext = new Gtk.CellRendererText ();
        Gtk.TreeViewColumn page_holder = new Gtk.TreeViewColumn ();
        page_holder.pack_start (invisitext, true);
        page_holder.visible = false;
        append_column (page_holder);

        set_headers_visible (false);
        set_enable_search (false);
        set_show_expanders (true);
        set_reorderable (false);
        set_enable_tree_lines (false);
        set_grid_lines (Gtk.TreeViewGridLines.NONE);
        set_tooltip_column (Columns.TOOLTIP);

        Gtk.TreeSelection selection = get_selection ();
        selection.set_mode (Gtk.SelectionMode.BROWSE);
        selection.set_select_function (on_selection);

        // It Would Be Nice if the target entries and actions were gleaned by querying each
        // Sidebar.Entry as it was added, but that's a tad too complicated for our needs
        // currently
        enable_model_drag_dest (target_entries, actions);

        Gtk.TargetEntry[] source_entries = new Gtk.TargetEntry[0];
        source_entries += target_entries[LibraryWindow.TargetType.TAG_PATH];
        enable_model_drag_source (Gdk.ModifierType.BUTTON1_MASK, source_entries,
                                  Gdk.DragAction.COPY);

        this.drop_handler = drop_handler;

        popup_menu.connect (on_context_menu_keypress);

        icon_theme = Gtk.IconTheme.get_default ();
        icon_theme.changed.connect (on_theme_change);

        get_style_context ().add_class (Granite.STYLE_CLASS_SOURCE_LIST);

        drag_begin.connect (on_drag_begin);
        drag_end.connect (on_drag_end);
        drag_motion.connect (on_drag_motion);
    }

    ~Tree () {
        text_renderer.editing_canceled.disconnect (on_editing_canceled);
        text_renderer.editing_started.disconnect (on_editing_started);
        icon_theme.changed.disconnect (on_theme_change);
    }

    private void on_drag_begin (Gdk.DragContext ctx) {
        is_internal_drag_in_progress = true;
    }

    private void on_drag_end (Gdk.DragContext ctx) {
        is_internal_drag_in_progress = false;
        internal_drag_source_entry = null;
    }

    private bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time_) {
        if (is_internal_drag_in_progress && internal_drag_source_entry == null) {
            Gtk.TreePath? path;
            Gtk.TreeViewDropPosition position;
            get_dest_row_at_pos (x, y, out path, out position);

            if (path != null) {
                EntryWrapper wrapper = get_wrapper_at_path (path);
                if (wrapper != null)
                    internal_drag_source_entry = wrapper.entry;
            }
        }

        return false;
    }

    private bool has_wrapper (Sidebar.Entry entry) {
        return entry_map.has_key (entry);
    }

    private EntryWrapper? get_wrapper (Sidebar.Entry entry) {
        EntryWrapper? wrapper = entry_map.get (entry);
        if (wrapper == null)
            warning ("Entry %s not found in sidebar", entry.to_string ());

        return wrapper;
    }

    private EntryWrapper? get_wrapper_at_iter (Gtk.TreeIter iter) {
        Value val;
        store.get_value (iter, Columns.WRAPPER, out val);

        EntryWrapper? wrapper = (EntryWrapper? ) val;
        if (wrapper == null)
            message ("No entry found in sidebar at %s", store.get_path (iter).to_string ());

        return wrapper;
    }

    private EntryWrapper? get_wrapper_at_path (Gtk.TreePath path) {
        Gtk.TreeIter iter;
        if (!store.get_iter (out iter, path)) {
            message ("No entry found in sidebar at %s", path.to_string ());

            return null;
        }

        return get_wrapper_at_iter (iter);
    }

    // Note that this method will result in the "entry-selected" signal to fire if mask_signal
    // is set to false.
    public bool place_cursor (Sidebar.Entry entry, bool mask_signal) {
        if (!expand_to_entry (entry))
            return false;

        EntryWrapper? wrapper = get_wrapper (entry);
        if (wrapper == null)
            return false;

        get_selection ().select_path (wrapper.get_path ());

        mask_entry_selected_signal = mask_signal;
        set_cursor (wrapper.get_path (), null, false);
        mask_entry_selected_signal = false;

        return scroll_to_entry (entry);
    }

    public bool is_selected (Sidebar.Entry entry) {
        EntryWrapper? wrapper = get_wrapper (entry);

        return (wrapper != null) ? get_selection ().path_is_selected (wrapper.get_path ()) : false;
    }

    public bool is_any_selected () {
        return get_selection ().count_selected_rows () != 0;
    }

    private Gtk.TreePath? get_selected_path () {
        Gtk.TreeModel model;
        GLib.List<Gtk.TreePath> rows = get_selection ().get_selected_rows (out model);
        assert (rows.length () == 0 || rows.length () == 1);

        return rows.length () != 0 ? rows.nth_data (0) : null;
    }

    public override void cursor_changed () {
        Gtk.TreePath? path = get_selected_path ();
        if (path == null) {
            if (base.cursor_changed != null)
                base.cursor_changed ();

            return;
        }

        EntryWrapper? wrapper = get_wrapper_at_path (path);

        selected_wrapper = wrapper;

        if (editing_disabled == 0 && wrapper != null)
            text_renderer.editable = wrapper.entry is Sidebar.RenameableEntry;

        if (wrapper != null && !mask_entry_selected_signal) {
            Sidebar.SelectableEntry? selectable = wrapper.entry as Sidebar.SelectableEntry;
            if (selectable != null)
                entry_selected (selectable);
        }

        if (base.cursor_changed != null)
            base.cursor_changed ();
    }

    public void disable_editing () {
        if (editing_disabled++ == 0)
            text_renderer.editable = false;
    }

    public void enable_editing () {
        Gtk.TreePath? path = get_selected_path ();
        if (path != null && editing_disabled > 0 && --editing_disabled == 0) {
            EntryWrapper? wrapper = get_wrapper_at_path (path);
            text_renderer.editable = (wrapper != null && (wrapper.entry is Sidebar.RenameableEntry));
        }
    }

    public void toggle_branch_expansion (Gtk.TreePath path, bool expand_all) {
        if (is_row_expanded (path))
            collapse_row (path);
        else
            expand_row (path, expand_all);
    }

    public bool expand_to_entry (Sidebar.Entry entry) {
        EntryWrapper? wrapper = get_wrapper (entry);
        if (wrapper == null)
            return false;

        expand_to_path (wrapper.get_path ());

        return true;
    }

    public void expand_to_first_child (Sidebar.Entry entry) {
        EntryWrapper? wrapper = get_wrapper (entry);
        if (wrapper == null)
            return;

        Gtk.TreePath path = wrapper.get_path ();

        Gtk.TreeIter iter;
        while (store.get_iter (out iter, path)) {
            if (!store.iter_has_child (iter))
                break;

            path.down ();
        }

        expand_to_path (path);
    }

    public void graft (Sidebar.Branch branch, int position) requires (position >= 0) {
        assert (!branches.has_key (branch));

        branches.set (branch, position);

        if (branch.get_show_branch ()) {
            associate_branch (branch);

            if (branch.is_startup_expand_to_first_child ())
                expand_to_first_child (branch.get_root ());

            if (branch.is_startup_open_grouping ())
                expand_to_entry (branch.get_root ());
        }

        branch.entry_added.connect (on_branch_entry_added);
        branch.entry_removed.connect (on_branch_entry_removed);
        branch.entry_moved.connect (on_branch_entry_moved);
        branch.entry_reparented.connect (on_branch_entry_reparented);
        branch.children_reordered.connect (on_branch_children_reordered);
        branch.show_branch.connect (on_show_branch);

        branch_added (branch);
    }

    // This is used to associate a known branch with the TreeView.
    private void associate_branch (Sidebar.Branch branch) {
        assert (branches.has_key (branch));

        int position = branches.get (branch);

        Gtk.TreeIter? insertion_iter = null;

        // search current roots for insertion point
        Gtk.TreeIter iter;
        bool found = store.get_iter_first (out iter);
        while (found) {
            RootWrapper? root_wrapper = get_wrapper_at_iter (iter) as RootWrapper;
            assert (root_wrapper != null);

            if (position < root_wrapper.root_position) {
                store.insert_before (out insertion_iter, null, iter);

                break;
            }

            found = store.iter_next (ref iter);
        }

        // if not found, append
        if (insertion_iter == null)
            store.append (out insertion_iter, null);

        associate_wrapper (insertion_iter,
                           new RootWrapper (store, branch.get_root (), store.get_path (insertion_iter), position));

        // mirror the branch's initial contents from below the root down, let the signals handle
        // future work
        associate_children (branch, branch.get_root (), insertion_iter);
    }

    private void associate_children (Sidebar.Branch branch, Sidebar.Entry parent,
                                     Gtk.TreeIter parent_iter) {
        Gee.List<Sidebar.Entry>? children = branch.get_children (parent);
        if (children == null)
            return;

        foreach (Sidebar.Entry child in children) {
            Gtk.TreeIter append_iter;
            store.append (out append_iter, parent_iter);

            associate_entry (append_iter, child);
            associate_children (branch, child, append_iter);
        }
    }

    private void associate_entry (Gtk.TreeIter assoc_iter, Sidebar.Entry entry) {
        associate_wrapper (assoc_iter, new EntryWrapper (store, entry, store.get_path (assoc_iter)));
    }

    private void associate_wrapper (Gtk.TreeIter assoc_iter, EntryWrapper wrapper) {
        Sidebar.Entry entry = wrapper.entry;

        assert (!entry_map.has_key (entry));
        entry_map.set (entry, wrapper);

        store.set (assoc_iter, Columns.TOOLTIP, guarded_markup_escape_text (entry.get_sidebar_tooltip ()));
        store.set (assoc_iter, Columns.WRAPPER, wrapper);
        load_entry_icons (assoc_iter);

        entry.sidebar_tooltip_changed.connect (on_sidebar_tooltip_changed);
        entry.sidebar_icon_changed.connect (on_sidebar_icon_changed);

        Sidebar.PageRepresentative? pageable = entry as Sidebar.PageRepresentative;
        if (pageable != null) {
            pageable.page_created.connect (on_sidebar_page_created);
            pageable.destroying_page.connect (on_sidebar_destroying_page);
        }

        Sidebar.RenameableEntry? renameable = entry as Sidebar.RenameableEntry;
        if (renameable != null)
            renameable.sidebar_name_changed.connect (on_sidebar_name_changed);

        Sidebar.ExpandableEntry? expandable = entry as Sidebar.ExpandableEntry;
        if (expandable != null)
            expandable.sidebar_open_closed_icons_changed.connect (on_sidebar_open_closed_icons_changed);

        string sidebar_name = guarded_markup_escape_text (entry.get_sidebar_name ());
        if (is_category_header (wrapper))
            store.set (assoc_iter, Columns.NAME, "<b>%s</b>".printf (sidebar_name));
        else
            store.set (assoc_iter, Columns.NAME, sidebar_name);

        entry.grafted (this);
    }

    private static bool is_category_header (EntryWrapper wrapper) {
        return (wrapper.entry is Sidebar.ExpandableEntry) && (wrapper.get_path ().get_depth () == 1);
    }

    private EntryWrapper reparent_wrapper (Gtk.TreeIter new_iter, EntryWrapper current_wrapper) {
        Sidebar.Entry entry = current_wrapper.entry;

        bool removed = entry_map.unset (entry);
        assert (removed);

        EntryWrapper new_wrapper = new EntryWrapper (store, entry, store.get_path (new_iter));
        entry_map.set (entry, new_wrapper);

        store.set (new_iter, Columns.NAME, guarded_markup_escape_text (entry.get_sidebar_name ()));
        store.set (new_iter, Columns.TOOLTIP, guarded_markup_escape_text (entry.get_sidebar_tooltip ()));
        store.set (new_iter, Columns.WRAPPER, new_wrapper);
        load_entry_icons (new_iter);

        return new_wrapper;
    }

    public void prune (Sidebar.Branch branch) {
        assert (branches.has_key (branch));

        if (has_wrapper (branch.get_root ()))
            disassociate_branch (branch);

        branch.entry_added.disconnect (on_branch_entry_added);
        branch.entry_removed.disconnect (on_branch_entry_removed);
        branch.entry_moved.disconnect (on_branch_entry_moved);
        branch.entry_reparented.disconnect (on_branch_entry_reparented);
        branch.children_reordered.disconnect (on_branch_children_reordered);
        branch.show_branch.disconnect (on_show_branch);

        bool removed = branches.unset (branch);
        assert (removed);

        branch_removed (branch);
    }

    private void disassociate_branch (Sidebar.Branch branch) {
        RootWrapper? root_wrapper = get_wrapper (branch.get_root ()) as RootWrapper;
        assert (root_wrapper != null);

        disassociate_wrapper_and_signal (root_wrapper, false);
    }

    // A wrapper for disassociate_wrapper () (?!?) that fires the "selected-entry-removed" signal if
    // condition exists
    private void disassociate_wrapper_and_signal (EntryWrapper wrapper, bool only_children) {
        bool selected = is_selected (wrapper.entry);

        disassociate_wrapper (wrapper, only_children);

        if (selected) {
            Sidebar.SelectableEntry? selectable = wrapper.entry as Sidebar.SelectableEntry;
            assert (selectable != null);

            selected_entry_removed (selectable);
        }
    }

    private void disassociate_wrapper (EntryWrapper wrapper, bool only_children) {
        Gee.ArrayList<EntryWrapper> children = new Gee.ArrayList<EntryWrapper> ();

        Gtk.TreeIter child_iter;
        bool found = store.iter_children (out child_iter, wrapper.get_iter ());
        while (found) {
            EntryWrapper? child_wrapper = get_wrapper_at_iter (child_iter);
            assert (child_wrapper != null);

            children.add (child_wrapper);

            found = store.iter_next (ref child_iter);
        }

        foreach (EntryWrapper child_wrapper in children)
            disassociate_wrapper (child_wrapper, false);

        if (only_children)
            return;

        Gtk.TreeIter iter = wrapper.get_iter ();
        store.remove (ref iter);

        if (selected_wrapper == wrapper)
            selected_wrapper = null;

        Sidebar.Entry entry = wrapper.entry;

        entry.pruned (this);

        entry.sidebar_tooltip_changed.disconnect (on_sidebar_tooltip_changed);
        entry.sidebar_icon_changed.disconnect (on_sidebar_icon_changed);

        Sidebar.PageRepresentative? pageable = entry as Sidebar.PageRepresentative;
        if (pageable != null) {
            pageable.page_created.disconnect (on_sidebar_page_created);
            pageable.destroying_page.disconnect (on_sidebar_destroying_page);
        }

        Sidebar.RenameableEntry? renameable = entry as Sidebar.RenameableEntry;
        if (renameable != null)
            renameable.sidebar_name_changed.disconnect (on_sidebar_name_changed);

        Sidebar.ExpandableEntry? expandable = entry as Sidebar.ExpandableEntry;
        if (expandable != null)
            expandable.sidebar_open_closed_icons_changed.disconnect (on_sidebar_open_closed_icons_changed);

        bool removed = entry_map.unset (entry);
        assert (removed);
    }

    private void on_branch_entry_added (Sidebar.Branch branch, Sidebar.Entry entry) {
        Sidebar.Entry? parent = branch.get_parent (entry);
        assert (parent != null);

        EntryWrapper? parent_wrapper = get_wrapper (parent);
        assert (parent_wrapper != null);

        Gtk.TreeIter insertion_iter;
        Sidebar.Entry? next = branch.get_next_sibling (entry);
        if (next != null) {
            EntryWrapper next_wrapper = get_wrapper (next);

            // insert before the next sibling in this branch level
            store.insert_before (out insertion_iter, parent_wrapper.get_iter (), next_wrapper.get_iter ());
        } else {
            // append to the bottom of this branch level
            store.append (out insertion_iter, parent_wrapper.get_iter ());
        }

        associate_entry (insertion_iter, entry);
        associate_children (branch, entry, insertion_iter);

        if (branch.is_auto_open_on_new_child ())
            expand_to_entry (entry);
    }

    private void on_branch_entry_removed (Sidebar.Branch branch, Sidebar.Entry entry) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);
        assert (! (wrapper is RootWrapper));

        disassociate_wrapper_and_signal (wrapper, false);
    }

    private void on_branch_entry_moved (Sidebar.Branch branch, Sidebar.Entry entry) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);
        assert (! (wrapper is RootWrapper));

        // null means entry is now at the top of the sibling list
        Gtk.TreeIter? prev_iter = null;
        Sidebar.Entry? prev = branch.get_previous_sibling (entry);
        if (prev != null) {
            EntryWrapper? prev_wrapper = get_wrapper (prev);
            assert (prev_wrapper != null);

            prev_iter = prev_wrapper.get_iter ();
        }

        Gtk.TreeIter entry_iter = wrapper.get_iter ();
        store.move_after (ref entry_iter, prev_iter);
    }

    private void on_branch_entry_reparented (Sidebar.Branch branch, Sidebar.Entry entry,
            Sidebar.Entry old_parent) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);
        assert (! (wrapper is RootWrapper));

        bool selected = (get_current_path ().compare (wrapper.get_path ()) == 0);

        // remove from current position in tree
        Gtk.TreeIter iter = wrapper.get_iter ();
        store.remove (ref iter);

        Sidebar.Entry? parent = branch.get_parent (entry);
        assert (parent != null);

        EntryWrapper? parent_wrapper = get_wrapper (parent);
        assert (parent_wrapper != null);

        // null means entry is now at the top of the sibling list
        Gtk.TreeIter? prev_iter = null;
        Sidebar.Entry? prev = branch.get_previous_sibling (entry);
        if (prev != null) {
            EntryWrapper? prev_wrapper = get_wrapper (prev);
            assert (prev_wrapper != null);

            prev_iter = prev_wrapper.get_iter ();
        }

        Gtk.TreeIter new_iter;
        store.insert_after (out new_iter, parent_wrapper.get_iter (), prev_iter);

        EntryWrapper new_wrapper = reparent_wrapper (new_iter, wrapper);

        if (selected) {
            expand_to_entry (new_wrapper.entry);
            place_cursor (new_wrapper.entry, false);
        }
    }

    private void on_branch_children_reordered (Sidebar.Branch branch, Sidebar.Entry entry) {
        Gee.List<Sidebar.Entry>? children = branch.get_children (entry);
        if (children == null)
            return;

        // This works by moving the entries to the bottom of the tree's list in the order they
        // are presented in the Sidebar.Branch list.
        foreach (Sidebar.Entry child in children) {
            EntryWrapper? child_wrapper = get_wrapper (child);
            assert (child_wrapper != null);

            Gtk.TreeIter child_iter = child_wrapper.get_iter ();
            store.move_before (ref child_iter, null);
        }
    }

    private void on_show_branch (Sidebar.Branch branch, bool shown) {
        if (shown)
            associate_branch (branch);
        else
            disassociate_branch (branch);

        branch_shown (branch, shown);
    }

    private void on_sidebar_tooltip_changed (Sidebar.Entry entry, string? tooltip) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);

        store.set (wrapper.get_iter (), Columns.TOOLTIP, guarded_markup_escape_text (tooltip));
    }

    private void on_sidebar_icon_changed (Sidebar.Entry entry, Icon? icon) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);

        store.set (wrapper.get_iter (), Columns.ICON, icon);
        store.set (wrapper.get_iter (), Columns.PIXBUF_VISIBLE, !is_category_header (wrapper));
    }

    private void on_sidebar_page_created (Sidebar.PageRepresentative entry, Page page) {
        page_created (entry, page);
    }

    private void on_sidebar_destroying_page (Sidebar.PageRepresentative entry, Page page) {
        destroying_page (entry, page);
    }

    private void on_sidebar_open_closed_icons_changed (Sidebar.ExpandableEntry entry, Icon? open,
            Icon? closed) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);

        store.set (wrapper.get_iter (), Columns.OPEN_PIXBUF, fetch_icon_pixbuf (open));
        store.set (wrapper.get_iter (), Columns.CLOSED_PIXBUF, fetch_icon_pixbuf (closed));
        store.set (wrapper.get_iter (), Columns.PIXBUF_VISIBLE, !is_category_header (wrapper));
    }

    private void on_sidebar_name_changed (Sidebar.RenameableEntry entry, string name) {
        EntryWrapper? wrapper = get_wrapper (entry);
        assert (wrapper != null);

        store.set (wrapper.get_iter (), Columns.NAME, guarded_markup_escape_text (name));
    }

    private Gdk.Pixbuf? fetch_icon_pixbuf (GLib.Icon? gicon) {
        if (gicon == null)
            return null;

        try {
            Gdk.Pixbuf? icon = icon_cache.get (gicon.to_string ());
            if (icon != null)
                return icon;

            // Using Gtk.IconLookupFlags.GENERIC_FALLBACK gives a runtime error warning in the terminal
            Gtk.IconInfo? info = icon_theme.lookup_by_gicon_for_scale (
                gicon, 16, get_scale_factor (), Gtk.IconLookupFlags.FORCE_SIZE
            );

            if (info == null)
                return null;

            icon = info.load_icon ();
            if (icon == null)
                return null;

            icon_cache.set (gicon.to_string (), icon);

            return icon;
        } catch (Error err) {
            warning ("Unable to load icon %s: %s", gicon.to_string (), err.message);

            return null;
        }
    }

    private void load_entry_icons (Gtk.TreeIter iter) {
        EntryWrapper? wrapper = get_wrapper_at_iter (iter);
        if (wrapper == null)
            return;

        Icon? icon = wrapper.entry.get_sidebar_icon ();
        Icon? open = null;
        Icon? closed = null;

        Sidebar.ExpandableEntry? expandable = wrapper.entry as Sidebar.ExpandableEntry;
        if (expandable != null) {
            open = expandable.get_sidebar_open_icon ();
            closed = expandable.get_sidebar_closed_icon ();
        }

        if (open == null)
            open = icon;

        if (closed == null)
            closed = icon;

        store.set (iter, Columns.ICON, icon);
        store.set (iter, Columns.OPEN_PIXBUF, fetch_icon_pixbuf (open));
        store.set (iter, Columns.CLOSED_PIXBUF, fetch_icon_pixbuf (closed));
        store.set (wrapper.get_iter (), Columns.PIXBUF_VISIBLE, !is_category_header (wrapper));
    }

    private void load_branch_icons (Gtk.TreeIter iter) {
        load_entry_icons (iter);

        Gtk.TreeIter child_iter;
        if (store.iter_children (out child_iter, iter)) {
            do {
                load_branch_icons (child_iter);
            } while (store.iter_next (ref child_iter));
        }
    }

    private void on_theme_change () {
        Gtk.TreeIter iter;
        if (store.get_iter_first (out iter)) {
            do {
                load_branch_icons (iter);
            } while (store.iter_next (ref iter));
        }
    }

    private bool on_selection (Gtk.TreeSelection selection, Gtk.TreeModel model, Gtk.TreePath path,
                               bool path_currently_selected) {
        // only allow selection if a page is selectable
        EntryWrapper? wrapper = get_wrapper_at_path (path);

        return (wrapper != null) ? (wrapper.entry is Sidebar.SelectableEntry) : false;
    }

    private Gtk.TreePath? get_path_from_event (Gdk.EventButton event) {
        int x, y;
        Gdk.ModifierType mask;
        var seat = event.get_seat ();
        event.window.get_device_position (seat.get_pointer (), out x, out y, out mask);

        int cell_x, cell_y;
        Gtk.TreePath path;
        return get_path_at_pos (x, y, out path, null, out cell_x, out cell_y) ? path : null;
    }

    private Gtk.TreePath? get_current_path () {
        Gtk.TreeModel model;
        GLib.List<Gtk.TreePath> rows = get_selection ().get_selected_rows (out model);
        assert (rows.length () == 0 || rows.length () == 1);

        return rows.length () != 0 ? rows.nth_data (0) : null;
    }

    private bool on_context_menu_keypress () {
        GLib.List<Gtk.TreePath> rows = get_selection ().get_selected_rows (null);
        if (rows == null)
            return false;

        Gtk.TreePath? path = rows.data;
        if (path == null)
            return false;

        scroll_to_cell (path, null, false, 0, 0);

        return popup_context_menu (path);
    }

    private bool popup_context_menu (Gtk.TreePath path, Gdk.EventButton? event = null) {
        EntryWrapper? wrapper = get_wrapper_at_path (path);
        if (wrapper == null)
            return false;

        Sidebar.Contextable? contextable = wrapper.entry as Sidebar.Contextable;
        if (contextable == null)
            return false;

        // First select the sidebar item so that its context menu will be available.
        Sidebar.SelectableEntry? selectable = wrapper.entry as Sidebar.SelectableEntry;
        if (selectable != null)
            entry_selected (selectable);

        Gtk.Menu? context_menu = contextable.get_sidebar_context_menu (event);
        if (context_menu == null)
            return false;

        context_menu.popup_at_pointer (event);

        return true;
    }

    private bool popup_default_context_menu (Gdk.EventButton event) {
        if (default_context_menu == null) {
            default_context_menu = new Gtk.Menu ();

            var new_search_menu_item = new Gtk.MenuItem.with_mnemonic (_("New Smart Album…"));
            new_search_menu_item.activate.connect (() => on_new_search);

            var new_tag_menu_item = new Gtk.MenuItem.with_mnemonic (_("New _Tag…"));
            new_tag_menu_item.activate.connect (() => on_new_tag);

            default_context_menu.add (new_search_menu_item);
            default_context_menu.add (new_tag_menu_item);
            default_context_menu.show_all ();
        }

        default_context_menu.popup_at_pointer (event);
        return true;
    }

    public override bool button_press_event (Gdk.EventButton event) {
        Gtk.TreePath? path = get_path_from_event (event);

        // user clicked on empty area, but isn't trying to spawn a context menu?
        if ((path == null) && (event.button != 3)) {
            return true;
        }

        if (event.button == 3 && event.type == Gdk.EventType.BUTTON_PRESS) {
            // single right click
            if (path != null)
                popup_context_menu (path, event);
            else
                popup_default_context_menu (event);
        } else if (event.button == 1 && event.type == Gdk.EventType.2BUTTON_PRESS) {
            // double left click
            if (path != null) {
                toggle_branch_expansion (path, false);

                if (can_rename_path (path))
                    return false;
            }
        } else if (event.button == 1 && event.type == Gdk.EventType.BUTTON_PRESS) {
            // Is this a click on an already-highlighted tree item?
            if ((old_path_ref != null) && (old_path_ref.get_path () != null)
                    && (old_path_ref.get_path ().compare (path) == 0)) {
                // yes, don't allow single-click editing, but
                // pass the event on for dragging.
                text_renderer.editable = false;
                return base.button_press_event (event);
            }

            // Got click on different tree item, make sure it is editable
            // if it needs to be.
            if (path != null && get_wrapper_at_path (path).entry is Sidebar.RenameableEntry) {
                text_renderer.editable = true;
            }

            // Remember what tree item is highlighted for next time.
            old_path_ref = (path != null) ? new Gtk.TreeRowReference (store, path) : null;
        }

        return base.button_press_event (event);
    }

    public bool is_keypress_interpreted (Gdk.EventKey event) {
        switch (Gdk.keyval_name (event.keyval)) {
        case "F2":
        case "Delete":
        case "Return":
        case "KP_Enter":
            return true;

        default:
            return false;
        }
    }

    public override bool key_press_event (Gdk.EventKey event) {
        switch (Gdk.keyval_name (event.keyval)) {
        case "Return":
        case "KP_Enter":
            Gtk.TreePath? path = get_current_path ();
            if (path != null)
                toggle_branch_expansion (path, false);

            return true;

        case "F2":
            return rename_in_place ();

        case "Delete":
            Gtk.TreePath? path = get_current_path ();

            return (path != null) ? destroy_path (path) : false;
        }

        return base.key_press_event (event);
    }

    public bool rename_entry_in_place (Sidebar.Entry entry) {
        if (!expand_to_entry (entry))
            return false;

        if (!place_cursor (entry, false))
            return false;

        return rename_in_place ();
    }

    private bool rename_in_place () {
        Gtk.TreePath? cursor_path;
        Gtk.TreeViewColumn? cursor_column;
        get_cursor (out cursor_path, out cursor_column);

        if (can_rename_path (cursor_path)) {
            set_cursor (cursor_path, cursor_column, true);

            return true;
        }

        return false;
    }

    public bool scroll_to_entry (Sidebar.Entry entry) {
        EntryWrapper? wrapper = get_wrapper (entry);
        if (wrapper == null)
            return false;

        scroll_to_cell (wrapper.get_path (), null, false, 0, 0);

        return true;
    }

    public override void drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data,
                                        uint info, uint time) {
        InternalDragSourceEntry? drag_source = null;

        if (internal_drag_source_entry != null) {
            Sidebar.SelectableEntry selectable =
                internal_drag_source_entry as Sidebar.SelectableEntry;
            if (selectable == null) {
                drag_source = internal_drag_source_entry as InternalDragSourceEntry;
            }
        }

        if (drag_source == null) {
            Gtk.TreePath? selected_path = get_selected_path ();
            if (selected_path == null)
                return;

            EntryWrapper? wrapper = get_wrapper_at_path (selected_path);
            if (wrapper == null)
                return;

            drag_source = wrapper.entry as InternalDragSourceEntry;
            if (drag_source == null)
                return;
        }

        drag_source.prepare_selection_data (selection_data);
    }

    public override void drag_data_received (Gdk.DragContext context, int x, int y,
            Gtk.SelectionData selection_data, uint info, uint time) {

        Gtk.TreePath path;
        Gtk.TreeViewDropPosition pos;
        if (!get_dest_row_at_pos (x, y, out path, out pos)) {
            // If an external drop, hand it off to the handler
            if (Gtk.drag_get_source_widget (context) == null)
                drop_handler (context, null, selection_data, info, time);
            else
                Gtk.drag_finish (context, false, false, time);

            return;
        }

        // Note that a drop outside a sidebar entry is legal if an external drop.
        EntryWrapper? wrapper = get_wrapper_at_path (path);

        // If an external drop, hand it off to the handler
        if (Gtk.drag_get_source_widget (context) == null) {
            drop_handler (context, (wrapper != null) ? wrapper.entry : null, selection_data,
                          info, time);

            return;
        }

        // An internal drop only applies to DropTargetEntry's
        if (wrapper == null) {
            Gtk.drag_finish (context, false, false, time);

            return;
        }

        Sidebar.InternalDropTargetEntry? targetable = wrapper.entry as Sidebar.InternalDropTargetEntry;
        if (targetable == null) {
            Gtk.drag_finish (context, false, false, time);

            return;
        }

        bool success = false;

        if (selection_data.get_data_type ().name () == LibraryWindow.TAG_PATH_MIME_TYPE) {
            success = targetable.internal_drop_received_arbitrary (selection_data);
        } else {
            Gee.List<MediaSource>? media = unserialize_media_sources (selection_data.get_data (),
                                           selection_data.get_length ());
            if (media != null && media.size > 0)
                success = targetable.internal_drop_received (media);
        }

        Gtk.drag_finish (context, success, false, time);
    }

    public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time) {
        // call the base signal to get rows with children to spring open
        base.drag_motion (context, x, y, time);

        Gtk.TreePath path;
        Gtk.TreeViewDropPosition pos;
        bool has_dest = get_dest_row_at_pos (x, y, out path, out pos);

        // we don't want to insert between rows, only select the rows themselves
        if (!has_dest || pos == Gtk.TreeViewDropPosition.BEFORE)
            set_drag_dest_row (path, Gtk.TreeViewDropPosition.INTO_OR_BEFORE);
        else if (pos == Gtk.TreeViewDropPosition.AFTER)
            set_drag_dest_row (path, Gtk.TreeViewDropPosition.INTO_OR_AFTER);

        Gdk.drag_status (context, context.get_suggested_action (), time);

        return has_dest;
    }

    // Returns true if path is renameable, and selects the path as well.
    private bool can_rename_path (Gtk.TreePath path) {
        if (editing_disabled > 0)
            return false;

        EntryWrapper? wrapper = get_wrapper_at_path (path);
        if (wrapper == null)
            return false;

        Sidebar.RenameableEntry? renameable = wrapper.entry as Sidebar.RenameableEntry;
        if (renameable == null)
            return false;

        get_selection ().select_path (path);

        return true;
    }

    private bool destroy_path (Gtk.TreePath path) {
        EntryWrapper? wrapper = get_wrapper_at_path (path);
        if (wrapper == null)
            return false;

        Sidebar.DestroyableEntry? destroyable = wrapper.entry as Sidebar.DestroyableEntry;
        if (destroyable == null)
            return false;

        destroyable.destroy_source ();

        return true;
    }

    private void on_editing_started (Gtk.CellEditable editable, string path) {
        if (editable is Gtk.Entry) {
            text_entry = (Gtk.Entry) editable;
            text_entry.editing_done.connect (on_editing_done);
            text_entry.focus_out_event.connect (on_editing_focus_out);
            text_entry.editable = true;
        }
    }

    private void on_editing_canceled () {
        text_entry.editable = false;

        text_entry.editing_done.disconnect (on_editing_done);
        text_entry.focus_out_event.disconnect (on_editing_focus_out);
    }

    private void on_editing_done () {
        text_entry.editable = false;

        EntryWrapper? wrapper = get_wrapper_at_path (get_current_path ());
        if (wrapper != null) {
            Sidebar.RenameableEntry? renameable = wrapper.entry as Sidebar.RenameableEntry;
            if (renameable != null)
                renameable.rename (text_entry.get_text ());
        }

        text_entry.editing_done.disconnect (on_editing_done);
        text_entry.focus_out_event.disconnect (on_editing_focus_out);
    }

    private bool on_editing_focus_out (Gdk.EventFocus event) {
        // We'll return false here, in case other parts of the app
        // want to know if the button press event that caused
        // us to lose focus have been fully handled.
        return false;
    }

    private void on_new_search () {
        (new SavedSearchDialog ()).show ();
    }

    private void on_new_tag () {
        NewRootTagCommand creation_command = new NewRootTagCommand ();
        AppWindow.get_command_manager ().execute (creation_command);
        LibraryWindow.get_app ().rename_tag_in_sidebar (creation_command.get_created_tag ());
    }
}
