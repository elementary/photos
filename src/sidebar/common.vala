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

// A simple grouping Entry that is only expandable
public class Sidebar.Grouping : Object, Sidebar.Entry, Sidebar.ExpandableEntry {
    private string name;
    private Icon? open_icon;
    private Icon? closed_icon;

    public Grouping (string name, Icon? open_icon, Icon? closed_icon = null) {
        this.name = name;
        this.open_icon = open_icon;
        this.closed_icon = closed_icon ?? open_icon;
    }

    public string get_sidebar_name () {
        return name;
    }

    public string? get_sidebar_tooltip () {
        return name;
    }

    public Icon? get_sidebar_icon () {
        return null;
    }

    public Icon? get_sidebar_open_icon () {
        return open_icon;
    }

    public Icon? get_sidebar_closed_icon () {
        return closed_icon;
    }

    public string to_string () {
        return name;
    }

    public bool expand_on_select () {
        return true;
    }
}

// An end-node on the sidebar that represents a Page with its page context menu.  Additional
// interfaces can be added if additional functionality is required (such as a drop target).
// This class also handles the bookwork of creating the Page on-demand and maintaining it in memory.
public abstract class Sidebar.SimplePageEntry : Object, Sidebar.Entry, Sidebar.SelectableEntry,
    Sidebar.PageRepresentative, Sidebar.Contextable {
    private Page? page = null;

    protected SimplePageEntry () {
    }

    public abstract string get_sidebar_name ();

    public virtual string? get_sidebar_tooltip () {
        return get_sidebar_name ();
    }

    public abstract Icon? get_sidebar_icon ();

    public virtual string to_string () {
        return get_sidebar_name ();
    }

    protected abstract Page create_page ();

    public bool has_page () {
        return page != null;
    }

    protected Page get_page () {
        if (page == null) {
            page = create_page ();
            page_created (page);
        }

        return page;
    }

    internal void pruned (Sidebar.Tree tree) {
        if (page == null)
            return;

        destroying_page (page);
        page.destroy ();
        page = null;
    }

    public Gtk.Menu? get_sidebar_context_menu (Gdk.EventButton? event) {
        return get_page ().get_page_sidebar_menu ();
    }
}

// A simple Sidebar.Branch where the root node is the branch in entirety.
public class Sidebar.RootOnlyBranch : Sidebar.Branch {
    public RootOnlyBranch (Sidebar.Entry root) {
        base (root, Sidebar.Branch.Options.NONE, null_comparator);
    }

    private static int null_comparator (Sidebar.Entry a, Sidebar.Entry b) {
        return (a != b) ? -1 : 0;
    }
}

public interface Sidebar.Contextable : Object {
    // Return null if the context menu should not be invoked for this event
    public abstract Gtk.Menu? get_sidebar_context_menu (Gdk.EventButton? event);
}

