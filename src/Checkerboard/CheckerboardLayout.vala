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

public class CheckerboardLayout : Gtk.DrawingArea {
    public const int TOP_PADDING = 16;
    public const int BOTTOM_PADDING = 16;
    public const int ROW_GUTTER_PADDING = 24;

    // the following are minimums, as the pads and gutters expand to fill up the window width
    public const int COLUMN_GUTTER_PADDING = 24;

    // The number of pixels that the scrollbars of Gtk.ScrolledWindows allocate for themselves
    // before their final size is computed. This must be taken into account when computing
    // the width of this widget. This value was 0 in Gtk+ 2.x but is 1 in Gtk+ 3.x. See
    // ticket #3870 (http://redmine.yorba.org/issues/3870) for more information
    private const int SCROLLBAR_PLACEHOLDER_WIDTH = 1;

    private class LayoutRow {
        public int y;
        public int height;
        public CheckerboardItem[] items;

        public LayoutRow (int y, int height, int num_in_row) {
            this.y = y;
            this.height = height;
            this.items = new CheckerboardItem[num_in_row];
        }
    }

    private ViewCollection view;
    private string page_name = "";
    private LayoutRow[] item_rows = null;
    private Gee.HashSet<CheckerboardItem> exposed_items = new Gee.HashSet<CheckerboardItem> ();
    private Gtk.Adjustment hadjustment = null;
    private Gtk.Adjustment vadjustment = null;
    private string message = null;
    private Gdk.Rectangle visible_page = Gdk.Rectangle ();
    private int last_width = 0;
    private int columns = 0;
    private int rows = 0;
    private Gdk.Point drag_origin = Gdk.Point ();
    private Gdk.Point drag_endpoint = Gdk.Point ();
    private Gdk.Rectangle selection_band = Gdk.Rectangle ();
    private int scale = 0;
    private bool flow_scheduled = false;
    private bool exposure_dirty = true;
    private CheckerboardItem? anchor = null;
    private bool in_center_on_anchor = false;
    private bool size_allocate_due_to_reflow = false;
    private bool is_in_view = false;
    private bool reflow_needed = false;

    public CheckerboardLayout (ViewCollection view) {
        this.view = view;

        clear_drag_select ();

        // subscribe to the new collection
        view.contents_altered.connect (on_contents_altered);
        view.items_altered.connect (on_items_altered);
        view.items_state_changed.connect (on_items_state_changed);
        view.items_visibility_changed.connect (on_items_visibility_changed);
        view.ordering_changed.connect (on_ordering_changed);
        view.views_altered.connect (on_views_altered);
        view.geometries_altered.connect (on_geometries_altered);
        view.items_selected.connect (on_items_selection_changed);
        view.items_unselected.connect (on_items_selection_changed);

        // CheckerboardItems offer tooltips
        has_tooltip = true;
    }

    ~CheckerboardLayout () {
#if TRACE_DTORS
        debug ("DTOR: CheckerboardLayout for %s", view.to_string ());
#endif

        view.contents_altered.disconnect (on_contents_altered);
        view.items_altered.disconnect (on_items_altered);
        view.items_state_changed.disconnect (on_items_state_changed);
        view.items_visibility_changed.disconnect (on_items_visibility_changed);
        view.ordering_changed.disconnect (on_ordering_changed);
        view.views_altered.disconnect (on_views_altered);
        view.geometries_altered.disconnect (on_geometries_altered);
        view.items_selected.disconnect (on_items_selection_changed);
        view.items_unselected.disconnect (on_items_selection_changed);

        if (hadjustment != null)
            hadjustment.value_changed.disconnect (on_viewport_shifted);

        if (vadjustment != null)
            vadjustment.value_changed.disconnect (on_viewport_shifted);

        if (parent != null)
            parent.size_allocate.disconnect (on_viewport_resized);
    }

    public void set_adjustments (Gtk.Adjustment hadjustment, Gtk.Adjustment vadjustment) {
        this.hadjustment = hadjustment;
        this.vadjustment = vadjustment;

        // monitor adjustment changes to report when the visible page shifts
        hadjustment.value_changed.connect (on_viewport_shifted);
        vadjustment.value_changed.connect (on_viewport_shifted);

        // monitor parent's size changes for a similar reason
        parent.size_allocate.connect (on_viewport_resized);
    }

    // This method allows for some optimizations to occur in reflow () by using the known max.
    // width of all items in the layout.
    public void set_scale (int scale) {
        this.scale = scale;
    }

    public int get_scale () {
        return scale;
    }

    public void set_name (string name) {
        page_name = name;
    }

    private void on_viewport_resized () {
        Gtk.Requisition req;
        get_preferred_size (null, out req);

        Gtk.Allocation parent_allocation;
        parent.get_allocation (out parent_allocation);

        if (message == null) {
            // set the layout's new size to be the same as the parent's width but maintain
            // it's own height
#if TRACE_REFLOW
            debug ("on_viewport_resized: due_to_reflow=%s set_size_request %dx%d",
                   size_allocate_due_to_reflow.to_string (), parent_allocation.width, req.height);
#endif
            set_size_request (parent_allocation.width - SCROLLBAR_PLACEHOLDER_WIDTH, req.height);
        } else {
            // set the layout's width and height to always match the parent's
            set_size_request (parent_allocation.width, parent_allocation.height);
        }

        // possible for this widget's size_allocate not to be called, so need to update the page
        // rect here
        viewport_resized ();

        if (!size_allocate_due_to_reflow)
            clear_anchor ();
        else
            size_allocate_due_to_reflow = false;
    }

    private void on_viewport_shifted () {
        update_visible_page ();
        need_exposure ("on_viewport_shift");

        clear_anchor ();
    }

    private void on_items_selection_changed () {
        clear_anchor ();
    }

    private void clear_anchor () {
        if (in_center_on_anchor)
            return;

        anchor = null;
    }

    private void update_anchor () {
        assert (!in_center_on_anchor);

        Gee.List<CheckerboardItem> items_on_page = intersection (visible_page);
        if (items_on_page.size == 0) {
            anchor = null;
            return;
        }

        foreach (CheckerboardItem item in items_on_page) {
            if (item.is_selected ()) {
                anchor = item;
                return;
            }
        }

        if (vadjustment.get_value () == 0) {
            anchor = null;
            return;
        }

        // this could be improved to always find the visual center...in the case where only
        // a few photos are in the last visible row, this can choose a photo near the right
        anchor = items_on_page.get ((int) items_on_page.size / 2);
    }

    private void center_on_anchor (double upper) {
        if (anchor == null)
            return;

        in_center_on_anchor = true;

        double anchor_pos = anchor.allocation.y + (anchor.allocation.height / 2) -
                            (vadjustment.get_page_size () / 2);
        vadjustment.set_value (anchor_pos.clamp (vadjustment.get_lower (),
                               vadjustment.get_upper () - vadjustment.get_page_size ()));

        in_center_on_anchor = false;
    }

    private void on_contents_altered (Gee.Iterable<DataObject>? added,
                                      Gee.Iterable<DataObject>? removed) {
        if (added != null)
            message = null;

        if (removed != null) {
            foreach (DataObject object in removed)
                exposed_items.remove ((CheckerboardItem) object);
        }

        // release spatial data structure ... contents_altered means a reflow is required, and since
        // items may be removed, this ensures we're not holding the ref on a removed view
        item_rows = null;

        need_reflow ("on_contents_altered");
    }

    private void on_items_altered () {
        need_reflow ("on_items_altered");
    }

    private void on_items_state_changed (Gee.Iterable<DataView> changed) {
        items_dirty ("on_items_state_changed", changed);
    }

    private void on_items_visibility_changed (Gee.Iterable<DataView> changed) {
        need_reflow ("on_items_visibility_changed");
    }

    private void on_ordering_changed () {
        need_reflow ("on_ordering_changed");
    }

    private void on_views_altered (Gee.Collection<DataView> altered) {
        items_dirty ("on_views_altered", altered);
    }

    private void on_geometries_altered () {
        need_reflow ("on_geometries_altered");
    }

    private void need_reflow (string caller) {
        if (flow_scheduled)
            return;

        if (!is_in_view) {
            reflow_needed = true;
            return;
        }

#if TRACE_REFLOW
        debug ("need_reflow %s: %s", page_name, caller);
#endif
        flow_scheduled = true;
        Idle.add_full (Priority.HIGH, do_reflow);
    }

    private bool do_reflow () {
        reflow ("do_reflow");
        need_exposure ("do_reflow");

        flow_scheduled = false;

        return false;
    }

    private void need_exposure (string caller) {
#if TRACE_REFLOW
        debug ("need_exposure %s: %s", page_name, caller);
#endif
        exposure_dirty = true;
        queue_draw ();
    }

    public void set_message (string? text) {
        if (text == message)
            return;

        message = text;

        if (text != null) {
            // message is being set, change size to match parent's; if no parent, then the size
            // will be set later when added to the parent
            if (parent != null) {
                Gtk.Allocation parent_allocation;
                parent.get_allocation (out parent_allocation);

                set_size_request (parent_allocation.width, parent_allocation.height);
            }
        } else {
            // message is being cleared, layout all the items again
            need_reflow ("set_message");
        }
    }

    public void unset_message () {
        set_message (null);
    }

    private void update_visible_page () {
        if (hadjustment != null && vadjustment != null)
            visible_page = get_adjustment_page (hadjustment, vadjustment);
    }

    public void set_in_view (bool in_view) {
        is_in_view = in_view;

        if (in_view) {
            if (reflow_needed)
                need_reflow ("set_in_view (true)");
            else
                need_exposure ("set_in_view (true)");
        } else
            unexpose_items ("set_in_view (false)");
    }

    public CheckerboardItem? get_item_at_pixel (double xd, double yd) {
        if (message != null || item_rows == null)
            return null;

        int x = (int) xd;
        int y = (int) yd;

        // binary search the rows for the one in range of the pixel
        LayoutRow in_range = null;
        int min = 0;
        int max = item_rows.length;
        for (;;) {
            int mid = min + ((max - min) / 2);
            LayoutRow row = item_rows[mid];

            if (row == null || y < row.y) {
                // undershot
                // row == null happens when there is an exact number of elements to fill the last row
                max = mid - 1;
            } else if (y > (row.y + row.height)) {
                // undershot
                min = mid + 1;
            } else {
                // bingo
                in_range = row;

                break;
            }

            if (min > max)
                break;
        }

        if (in_range == null)
            return null;

        // look for item in row's column in range of the pixel
        foreach (CheckerboardItem item in in_range.items) {
            // this happens on an incompletely filled-in row (usually the last one with empty
            // space remaining)
            if (item == null)
                continue;

            if (x < item.allocation.x) {
                // overshot ... this happens because there's gaps in the columns
                break;
            }

            // need to verify actually over item's full dimensions, since they vary in size inside
            // a row
            if (x <= (item.allocation.x + item.allocation.width) && y >= item.allocation.y
                    && y <= (item.allocation.y + item.allocation.height))
                return item;
        }

        return null;
    }

    public Gee.List<CheckerboardItem> get_visible_items () {
        return intersection (visible_page);
    }

    public Gee.List<CheckerboardItem> intersection (Gdk.Rectangle area) {
        Gee.ArrayList<CheckerboardItem> intersects = new Gee.ArrayList<CheckerboardItem> ();

        Gtk.Allocation allocation;
        get_allocation (out allocation);

        Gdk.Rectangle bitbucket = Gdk.Rectangle ();
        foreach (LayoutRow row in item_rows) {
            if (row == null)
                continue;

            if ((area.y + area.height) < row.y) {
                // overshoot
                break;
            }

            if ((row.y + row.height) < area.y) {
                // haven't reached it yet
                continue;
            }

            // see if the row intersects the area
            Gdk.Rectangle row_rect = Gdk.Rectangle ();
            row_rect.x = 0;
            row_rect.y = row.y;
            row_rect.width = allocation.width;
            row_rect.height = row.height;

            if (area.intersect (row_rect, out bitbucket)) {
                // see what elements, if any, intersect the area
                foreach (CheckerboardItem item in row.items) {
                    if (item == null)
                        continue;

                    if (area.intersect (item.allocation, out bitbucket))
                        intersects.add (item);
                }
            }
        }

        return intersects;
    }

    public CheckerboardItem? get_item_relative_to (CheckerboardItem item, Gtk.DirectionType direction) {
        if (view.get_count () == 0)
            return null;

        assert (columns > 0);
        assert (rows > 0);

        int col = item.get_column ();
        int row = item.get_row ();

        if (col < 0 || row < 0) {
            critical ("Attempting to locate item not placed in layout: %s", item.get_title ());

            return null;
        }

        switch (direction) {
            case Gtk.DirectionType.UP:
                if (--row < 0)
                    row = 0;
                break;

            case Gtk.DirectionType.DOWN:
                if (++row >= rows)
                    row = rows - 1;
                break;

            case Gtk.DirectionType.RIGHT:
                if (++col >= columns) {
                    if (++row >= rows) {
                        row = rows - 1;
                        col = columns - 1;
                    } else {
                        col = 0;
                    }
                }
                break;

            case Gtk.DirectionType.LEFT:
                if (--col < 0) {
                    if (--row < 0) {
                        row = 0;
                        col = 0;
                    } else {
                        col = columns - 1;
                    }
                }
                break;

            default:
                error ("Bad compass direction %d", (int) direction);
        }

        CheckerboardItem? new_item = get_item_at_coordinate (col, row);

        if (new_item == null && direction == Gtk.DirectionType.DOWN) {
            // nothing directly below, get last item on next row
            new_item = (CheckerboardItem? ) view.get_last ();
            if (new_item.get_row () <= item.get_row ())
                new_item = null;
        }

        return (new_item != null) ? new_item : item;
    }

    public CheckerboardItem? get_item_at_coordinate (int col, int row) {
        if (row >= item_rows.length)
            return null;

        LayoutRow item_row = item_rows[row];
        if (item_row == null)
            return null;

        if (col >= item_row.items.length)
            return null;

        return item_row.items[col];
    }

    public void set_drag_select_origin (int x, int y) {
        clear_drag_select ();

        Gtk.Allocation allocation;
        get_allocation (out allocation);

        drag_origin.x = x.clamp (0, allocation.width);
        drag_origin.y = y.clamp (0, allocation.height);
    }

    public void set_drag_select_endpoint (int x, int y) {
        Gtk.Allocation allocation;
        get_allocation (out allocation);

        drag_endpoint.x = x.clamp (0, allocation.width);
        drag_endpoint.y = y.clamp (0, allocation.height);

        // drag_origin and drag_endpoint are maintained only to generate selection_band; all reporting
        // and drawing functions refer to it, not drag_origin and drag_endpoint
        Gdk.Rectangle old_selection_band = selection_band;
        selection_band = Box.from_points (drag_origin, drag_endpoint).get_rectangle ();

        // force repaint of the union of the old and new, which covers the band reducing in size
        if (get_window () != null) {
            Gdk.Rectangle union;
            selection_band.union (old_selection_band, out union);

            queue_draw_area (union.x, union.y, union.width, union.height);
        }
    }

    public Gee.List<CheckerboardItem>? items_in_selection_band () {
        if (!Dimensions.for_rectangle (selection_band).has_area ())
            return null;

        return intersection (selection_band);
    }

    public bool is_drag_select_active () {
        return drag_origin.x >= 0 && drag_origin.y >= 0;
    }

    public void clear_drag_select () {
        selection_band = Gdk.Rectangle ();
        drag_origin.x = -1;
        drag_origin.y = -1;
        drag_endpoint.x = -1;
        drag_endpoint.y = -1;

        // force a total repaint to clear the selection band
        queue_draw ();
    }

    private void viewport_resized () {
        // update visible page rect
        update_visible_page ();

        // only reflow () if the width has changed
        if (visible_page.width != last_width) {
            int old_width = last_width;
            last_width = visible_page.width;

            need_reflow ("viewport_resized (%d -> %d)".printf (old_width, visible_page.width));
        } else {
            // don't need to reflow but exposure may have changed
            need_exposure ("viewport_resized (same width=%d)".printf (last_width));
        }
    }

    private void expose_items (string caller) {
        // create a new hash set of exposed items that represents an intersection of the old set
        // and the new
        Gee.HashSet<CheckerboardItem> new_exposed_items = new Gee.HashSet<CheckerboardItem> ();

        view.freeze_notifications ();

        Gee.List<CheckerboardItem> items = get_visible_items ();
        foreach (CheckerboardItem item in items) {
            new_exposed_items.add (item);

            // if not in the old list, then need to expose
            if (!exposed_items.remove (item))
                item.exposed ();
        }

        // everything remaining in the old exposed list is now unexposed
        foreach (CheckerboardItem item in exposed_items)
            item.unexposed ();

        // swap out lists
        exposed_items = new_exposed_items;
        exposure_dirty = false;

#if TRACE_REFLOW
        debug ("expose_items %s: exposed %d items, thawing", page_name, exposed_items.size);
#endif
        view.thaw_notifications ();
#if TRACE_REFLOW
        debug ("expose_items %s: thaw finished", page_name);
#endif
    }

    private void unexpose_items (string caller) {
        view.freeze_notifications ();

        foreach (CheckerboardItem item in exposed_items)
            item.unexposed ();

        exposed_items.clear ();
        exposure_dirty = false;

#if TRACE_REFLOW
        debug ("unexpose_items %s: thawing", page_name);
#endif
        view.thaw_notifications ();
#if TRACE_REFLOW
        debug ("unexpose_items %s: thawed", page_name);
#endif
    }

    private void reflow (string caller) {
        reflow_needed = false;

        // if set in message mode, nothing to do here
        if (message != null)
            return;

        Gtk.Allocation allocation;
        get_allocation (out allocation);

        int visible_width = (visible_page.width > 0) ? visible_page.width : allocation.width;

#if TRACE_REFLOW
        debug ("reflow: Using visible page width of %d (allocated: %d)", visible_width,
               allocation.width);
#endif

        // don't bother until layout is of some appreciable size (even this is too low)
        if (visible_width <= 1)
            return;

        int total_items = view.get_count ();

        // need to set_size in case all items were removed and the viewport size has changed
        if (total_items == 0) {
            set_size_request (visible_width, 0);
            item_rows = new LayoutRow[0];

            return;
        }

#if TRACE_REFLOW
        debug ("reflow %s: %s (%d items)", page_name, caller, total_items);
#endif

        // look for anchor if there is none currently
        if (anchor == null || !anchor.is_visible ())
            update_anchor ();

        // clear the rows data structure, as the reflow will completely rearrange it
        item_rows = null;

        // Step 1: Determine the widest row in the layout, and from it the number of columns.
        // If owner supplies an image scaling for all items in the layout, then this can be
        // calculated quickly.
        int max_cols = 0;
        if (scale > 0) {
            // calculate interior width
            int remaining_width = visible_width - (COLUMN_GUTTER_PADDING * 2);
            int max_item_width = CheckerboardItem.get_max_width (scale);
            max_cols = remaining_width / max_item_width;
            if (max_cols <= 0)
                max_cols = 1;

            // if too large with gutters, decrease until columns fit
            while (max_cols > 1
                    && ((max_cols * max_item_width) + ((max_cols - 1) * COLUMN_GUTTER_PADDING) > remaining_width)) {
#if TRACE_REFLOW
                debug ("reflow %s: scaled cols estimate: reducing max_cols from %d to %d", page_name,
                       max_cols, max_cols - 1);
#endif
                max_cols--;
            }

            // special case: if fewer items than columns, they are the columns
            if (total_items < max_cols)
                max_cols = total_items;

#if TRACE_REFLOW
            debug ("reflow %s: scaled cols estimate: max_cols=%d remaining_width=%d max_item_width=%d",
                   page_name, max_cols, remaining_width, max_item_width);
#endif
        } else {
            int x = COLUMN_GUTTER_PADDING;
            int col = 0;
            int row_width = 0;
            int widest_row = 0;

            for (int ctr = 0; ctr < total_items; ctr++) {
                CheckerboardItem item = (CheckerboardItem) view.get_at (ctr);
                Dimensions req = item.requisition;

                // the items must be requisitioned for this code to work
                assert (req.has_area ());

                // carriage return (i.e. this item will overflow the view)
                if ((x + req.width + COLUMN_GUTTER_PADDING) > visible_width) {
                    if (row_width > widest_row) {
                        widest_row = row_width;
                        max_cols = col;
                    }

                    col = 0;
                    x = COLUMN_GUTTER_PADDING;
                    row_width = 0;
                }

                x += req.width + COLUMN_GUTTER_PADDING;
                row_width += req.width;

                col++;
            }

            // account for dangling last row
            if (row_width > widest_row)
                max_cols = col;

#if TRACE_REFLOW
            debug ("reflow %s: manual cols estimate: max_cols=%d widest_row=%d", page_name, max_cols,
                   widest_row);
#endif
        }

        assert (max_cols > 0);
        int max_rows = (total_items / max_cols) + 1;

        // Step 2: Now that the number of columns is known, find the maximum height for each row
        // and the maximum width for each column
        int row = 0;
        int tallest = 0;
        int widest = 0;
        int row_alignment_point = 0;
        int total_width = 0;
        int col = 0;
        int[] column_widths = new int[max_cols];
        int[] row_heights = new int[max_rows];
        int[] alignment_points = new int[max_rows];
        int gutter = 0;

        for (;;) {
            for (int ctr = 0; ctr < total_items; ctr++ ) {
                CheckerboardItem item = (CheckerboardItem) view.get_at (ctr);
                Dimensions req = item.requisition;
                int alignment_point = item.get_alignment_point ();

                // alignment point better be sane
                assert (alignment_point < req.height);

                if (req.height > tallest)
                    tallest = req.height;

                if (req.width > widest)
                    widest = req.width;

                if (alignment_point > row_alignment_point)
                    row_alignment_point = alignment_point;

                // store largest thumb size of each column as well as track the total width of the
                // layout (which is the sum of the width of each column)
                if (column_widths[col] < req.width) {
                    total_width -= column_widths[col];
                    column_widths[col] = req.width;
                    total_width += req.width;
                }

                if (++col >= max_cols) {
                    alignment_points[row] = row_alignment_point;
                    row_heights[row++] = tallest;

                    col = 0;
                    row_alignment_point = 0;
                    tallest = 0;
                }
            }

            // account for final dangling row
            if (col != 0) {
                alignment_points[row] = row_alignment_point;
                row_heights[row] = tallest;
            }

            // Step 3: Calculate the gutter between the items as being equidistant of the
            // remaining space (adding one gutter to account for the right-hand one)
            gutter = (visible_width - total_width) / (max_cols + 1);

            // if only one column, gutter size could be less than minimums
            if (max_cols == 1)
                break;

            // have to reassemble if the gutter is too small ... this happens because Step One
            // takes a guess at the best column count, but when the max. widths of the columns are
            // added up, they could overflow
            if (gutter < COLUMN_GUTTER_PADDING) {
                max_cols--;
                max_rows = (total_items / max_cols) + 1;

#if TRACE_REFLOW
                debug ("reflow %s: readjusting columns: alloc.width=%d total_width=%d widest=%d gutter=%d max_cols now=%d",
                       page_name, visible_width, total_width, widest, gutter, max_cols);
#endif

                col = 0;
                row = 0;
                tallest = 0;
                widest = 0;
                total_width = 0;
                row_alignment_point = 0;
                column_widths = new int[max_cols];
                row_heights = new int[max_rows];
                alignment_points = new int[max_rows];
            } else {
                break;
            }
        }

#if TRACE_REFLOW
        debug ("reflow %s: width:%d total_width:%d max_cols:%d gutter:%d", page_name, visible_width,
               total_width, max_cols, gutter);
#endif

        // Step 4: Recalculate the height of each row according to the row's alignment point (which
        // may cause shorter items to extend below the bottom of the tallest one, extending the
        // height of the row)
        col = 0;
        row = 0;

        for (int ctr = 0; ctr < total_items; ctr++) {
            CheckerboardItem item = (CheckerboardItem) view.get_at (ctr);
            Dimensions req = item.requisition;

            // this determines how much padding the item requires to be bottom-alignment along the
            // alignment point; add to the height and you have the item's "true" height on the
            // laid-down row
            int true_height = req.height + (alignment_points[row] - item.get_alignment_point ());
            assert (true_height >= req.height);

            // add that to its height to determine it's actual height on the laid-down row
            if (true_height > row_heights[row]) {
#if TRACE_REFLOW
                debug ("reflow %s: Adjusting height of row %d from %d to %d", page_name, row,
                       row_heights[row], true_height);
#endif
                row_heights[row] = true_height;
            }

            // carriage return
            if (++col >= max_cols) {
                col = 0;
                row++;
            }
        }

        // for the spatial structure
        item_rows = new LayoutRow[max_rows];

        // Step 5: Lay out the items in the space using all the information gathered
        int x = gutter;
        int y = TOP_PADDING;
        col = 0;
        row = 0;
        LayoutRow current_row = null;

        for (int ctr = 0; ctr < total_items; ctr++) {
            CheckerboardItem item = (CheckerboardItem) view.get_at (ctr);
            Dimensions req = item.requisition;

            // this centers the item in the column
            int xpadding = (column_widths[col] - req.width) / 2;
            assert (xpadding >= 0);

            // this bottom-aligns the item along the discovered alignment point
            int ypadding = alignment_points[row] - item.get_alignment_point ();
            assert (ypadding >= 0);

            // save pixel and grid coordinates
            item.allocation.x = x + xpadding;
            item.allocation.y = y + ypadding;
            item.allocation.width = req.width;
            item.allocation.height = req.height;
            item.set_grid_coordinates (col, row);

            // add to current row in spatial data structure
            if (current_row == null)
                current_row = new LayoutRow (y, row_heights[row], max_cols);

            current_row.items[col] = item;

            x += column_widths[col] + gutter;

            // carriage return
            if (++col >= max_cols) {
                assert (current_row != null);
                item_rows[row] = current_row;
                current_row = null;

                x = gutter;
                y += row_heights[row] + ROW_GUTTER_PADDING;
                col = 0;
                row++;
            }
        }

        // add last row to spatial data structure
        if (current_row != null)
            item_rows[row] = current_row;

        // save dimensions of checkerboard
        columns = max_cols;
        rows = row + 1;
        assert (rows == max_rows);

        // Step 6: Define the total size of the page as the size of the visible width (to avoid
        // the horizontal scrollbar from appearing) and the height of all the items plus padding
        int total_height = y + row_heights[row] + BOTTOM_PADDING;
        if (visible_width != allocation.width || total_height != allocation.height) {
#if TRACE_REFLOW
            debug ("reflow %s: Changing layout dimensions from %dx%d to %dx%d", page_name,
                   allocation.width, allocation.height, visible_width, total_height);
#endif
            set_size_request (visible_width, total_height);
            size_allocate_due_to_reflow = true;

            // when height changes, center on the anchor to minimize amount of visual change
            center_on_anchor (total_height);
        }
    }

    private void items_dirty (string reason, Gee.Iterable<DataView> items) {
        Gdk.Rectangle dirty = Gdk.Rectangle ();
        foreach (DataView data_view in items) {
            CheckerboardItem item = (CheckerboardItem) data_view;

            if (!item.is_visible ())
                continue;

            assert (view.contains (item));

            // if not allocated, need to reflow the entire layout; don't bother queueing a draw
            // for any of these, reflow will handle that
            if (item.allocation.width <= 0 || item.allocation.height <= 0) {
                need_reflow ("items_dirty: %s".printf (reason));

                return;
            }

            // only mark area as dirty if visible in viewport
            Gdk.Rectangle intersection = Gdk.Rectangle ();
            if (!visible_page.intersect (item.allocation, out intersection))
                continue;

            // grow the dirty area
            if (dirty.width == 0 || dirty.height == 0)
                dirty = intersection;
            else
                dirty.union (intersection, out dirty);
        }

        if (dirty.width > 0 && dirty.height > 0) {
#if TRACE_REFLOW
            debug ("items_dirty %s (%s): Queuing draw of dirty area %s on visible_page %s",
                   page_name, reason, rectangle_to_string (dirty), rectangle_to_string (visible_page));
#endif
            queue_draw_area (dirty.x, dirty.y, dirty.width, dirty.height);
        }
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        base.size_allocate (allocation);

        viewport_resized ();
    }

    public override bool draw (Cairo.Context ctx) {
        // Note: It's possible for draw to be called when in_view is false; this happens
        // when pages are switched prior to switched_to () being called, and some of the other
        // controls allow for events to be processed while they are orienting themselves.  Since
        // we want switched_to () to be the final call in the process (indicating that the page is
        // now in place and should do its thing to update itself), have to be be prepared for
        // GTK/GDK calls between the widgets being actually present on the screen and "switched to"

        // watch for message mode
        if (message == null) {
#if TRACE_REFLOW
            debug ("draw %s: %s", page_name, rectangle_to_string (visible_page));
#endif

            if (exposure_dirty)
                expose_items ("draw");

            // have all items in the exposed area paint themselves
            weak Gtk.StyleContext style_context = get_style_context ();
            style_context.render_background (ctx, visible_page.x, visible_page.y, visible_page.width, visible_page.height);

            style_context.save ();
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class (Granite.STYLE_CLASS_CHECKERBOARD);
            foreach (CheckerboardItem item in intersection (visible_page)) {
                item.paint (ctx, style_context);
            }

            style_context.restore ();
        } else {
            // draw the message in the center of the window
            Pango.Layout pango_layout = create_pango_layout (message);
            int text_width, text_height;
            pango_layout.get_pixel_size (out text_width, out text_height);

            Gtk.Allocation allocation;
            get_allocation (out allocation);

            int x = allocation.width - text_width;
            x = (x > 0) ? x / 2 : 0;

            int y = allocation.height - text_height;
            y = (y > 0) ? y / 2 : 0;

            ctx.move_to (x, y);
            Pango.cairo_show_layout (ctx, pango_layout);
        }

        bool result = (base.draw != null) ? base.draw (ctx) : true;

        // draw the selection band last, so it appears floating over everything else
        draw_selection_band (ctx);

        return result;
    }

    private void draw_selection_band (Cairo.Context ctx) {
        // no selection band, nothing to draw
        if (selection_band.width <= 1 || selection_band.height <= 1)
            return;

        // This requires adjustments
        if (hadjustment == null || vadjustment == null)
            return;

        ctx.save ();
        // find the visible intersection of the viewport and the selection band
        Gdk.Rectangle visible_page = get_adjustment_page (hadjustment, vadjustment);
        Gdk.Rectangle visible_band = Gdk.Rectangle ();

        visible_page.intersect (selection_band, out visible_band);

        var label_widget_path = new Gtk.WidgetPath ();
        label_widget_path.append_type (typeof (Gtk.IconView));
        label_widget_path.iter_set_object_name (-1, "rubberband");

        var rubberband_context = new Gtk.StyleContext ();
        rubberband_context.set_path (label_widget_path);

        var bg_color = (Gdk.RGBA) rubberband_context.get_property (
            Gtk.STYLE_PROPERTY_BACKGROUND_COLOR,
            Gtk.StateFlags.NORMAL
        );

        var border_color = (Gdk.RGBA) rubberband_context.get_property (
            Gtk.STYLE_PROPERTY_BORDER_COLOR,
            Gtk.StateFlags.NORMAL
        );

        var border_radius = (int) rubberband_context.get_property (
            Gtk.STYLE_PROPERTY_BORDER_RADIUS,
            Gtk.StateFlags.NORMAL
        );

        // Don't draw lines across half pixels
        ctx.translate (0.5, 0.5);

        Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, visible_band.x, visible_band.y, visible_band.width, visible_band.height, border_radius);
        ctx.set_source_rgba (bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);
        ctx.fill ();

        Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, visible_band.x, visible_band.y, visible_band.width, visible_band.height, border_radius);
        ctx.set_source_rgba (border_color.red, border_color.green, border_color.blue, border_color.alpha);
        ctx.set_line_width (1.0);
        ctx.stroke ();

        ctx.restore ();
    }

    public override bool query_tooltip (int x, int y, bool keyboard_mode, Gtk.Tooltip tooltip) {
        CheckerboardItem? item = get_item_at_pixel (x, y);

        return (item != null) ? item.query_tooltip (x, y, tooltip) : false;
    }

    public override bool focus_in_event (Gdk.EventFocus event) {
        items_dirty ("focus_in_event", view.get_selected ());

        return base.focus_in_event (event);
    }

    public override bool focus_out_event (Gdk.EventFocus event) {
        items_dirty ("focus_out_event", view.get_selected ());

        return base.focus_out_event (event);
    }
}
