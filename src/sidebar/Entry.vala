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

public interface Sidebar.Entry : Object {
    public signal void sidebar_tooltip_changed (string? tooltip);

    public signal void sidebar_icon_changed (Icon? icon);

    public abstract string get_sidebar_name ();

    public abstract string? get_sidebar_tooltip ();

    public abstract Icon? get_sidebar_icon ();

    public abstract string to_string ();

    internal virtual void grafted (Sidebar.Tree tree) {
    }

    internal virtual void pruned (Sidebar.Tree tree) {
    }
}

public interface Sidebar.ExpandableEntry : Sidebar.Entry {
    public signal void sidebar_open_closed_icons_changed (Icon? open, Icon? closed);

    public abstract Icon? get_sidebar_open_icon ();

    public abstract Icon? get_sidebar_closed_icon ();

    public abstract bool expand_on_select ();
}

public interface Sidebar.SelectableEntry : Sidebar.Entry {
}

public interface Sidebar.PageRepresentative : Sidebar.Entry, Sidebar.SelectableEntry {
    // Fired after the page has been created
    public signal void page_created (Page page);

    // Fired before the page is destroyed.
    public signal void destroying_page (Page page);

    public abstract bool has_page ();

    public abstract Page get_page ();
}

public interface Sidebar.RenameableEntry : Sidebar.Entry {
    public signal void sidebar_name_changed (string name);

    public abstract void rename (string new_name);
}

public interface Sidebar.DestroyableEntry : Sidebar.Entry {
    public abstract void destroy_source ();
}

public interface Sidebar.InternalDropTargetEntry : Sidebar.Entry {
    // Returns true if drop was successful
    public abstract bool internal_drop_received (Gee.List<MediaSource> sources);
    public abstract bool internal_drop_received_arbitrary (Gtk.SelectionData data);
}

public interface Sidebar.InternalDragSourceEntry : Sidebar.Entry {
    public abstract void prepare_selection_data (Gtk.SelectionData data);
}
