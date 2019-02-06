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

public abstract class CheckerboardItem : ThumbnailView {
    // Collection properties CheckerboardItem understands
    // SHOW_TITLES (bool)
    public const string PROP_SHOW_TITLES = "show-titles";
    // SHOW_COMMENTS (bool)
    public const string PROP_SHOW_COMMENTS = "show-comments";
    // SHOW_SUBTITLES (bool)
    public const string PROP_SHOW_SUBTITLES = "show-subtitles";

    public const int FRAME_WIDTH = 8;
    public const int LABEL_PADDING = 4;
    public const int BORDER_WIDTH = 0;

    public const int BRIGHTEN_SHIFT = 0x18;
    public const int SELECTION_ICON_SIZE = 24;

    public Dimensions requisition = Dimensions ();
    public Gdk.Rectangle allocation = Gdk.Rectangle ();

    private bool exposure = false;
    private CheckerboardItemText? title = null;
    private CheckerboardItemText? comment = null;
    private CheckerboardItemText? subtitle = null;
    private Gdk.Pixbuf pixbuf = null;
    private Gdk.Pixbuf display_pixbuf = null;
    private Gdk.Pixbuf brightened = null;
    private Dimensions pixbuf_dim = Dimensions ();
    private int col = -1;
    private int row = -1;

    private bool _comment_visible = true;
    private bool comment_visible {
        get {
            return _comment_visible;
        }
        set {
            if (_comment_visible != value) {
                _comment_visible = value;
                recalc_size ("set_comment_visible");
                notify_view_altered ();
            }
        }
    }

    private bool _subtitle_visible = false;
    private bool subtitle_visible {
        get {
            return _subtitle_visible;
        }
        set {
            if (_subtitle_visible != value) {
                _subtitle_visible = value;
                recalc_size ("set_subtitle_visible");
                notify_view_altered ();
            }
        }
    }

    private bool _title_visible = true;
    private bool title_visible {
        get {
            return _title_visible;
        }
        set {
            if (_title_visible != value) {
                _title_visible = value;
                recalc_size ("set_title_visible");
                notify_view_altered ();
            }
        }
    }

    public CheckerboardItem (ThumbnailSource source, Dimensions initial_pixbuf_dim, string title, string? comment,
                             bool marked_up = false, Pango.Alignment alignment = Pango.Alignment.LEFT) {
        base (source);

        pixbuf_dim = initial_pixbuf_dim;
        this.title = new CheckerboardItemText (title, alignment, marked_up);
        // on the checkboard page we display the comment in
        // one line, i.e., replacing all newlines with spaces.
        // that means that the display will contain "..." if the comment
        // is too long.
        // warning: changes here have to be done in set_comment, too!
        if (comment != null) {
            this.comment = new CheckerboardItemText (comment.replace ("\n", " "), alignment, marked_up);
        }

        // Don't calculate size here, wait for the item to be assigned to a ViewCollection
        // (notify_membership_changed) and calculate when the collection's property settings
        // are known
    }

    public override string get_name () {
        return (title != null) ? title.get_text () : base.get_name ();
    }

    public string get_title () {
        return (title != null) ? title.get_text () : "";
    }

    public string get_comment () {
        return (comment != null) ? comment.get_text () : "";
    }

    public void set_title (string text, bool marked_up = false, Pango.Alignment alignment = Pango.Alignment.LEFT) {
        if (title != null && title.is_set_to (text, marked_up, alignment)) {
            return;
        }

        title = new CheckerboardItemText (text, alignment, marked_up);

        if (title_visible) {
            recalc_size ("set_title");
            notify_view_altered ();
        }
    }

    public void clear_title () {
        if (title == null) {
            return;
        }

        title = null;

        if (title_visible) {
            recalc_size ("clear_title");
            notify_view_altered ();
        }
    }

    public void set_comment (string text, bool marked_up = false,
                             Pango.Alignment alignment = Pango.Alignment.LEFT) {
        if (comment != null && comment.is_set_to (text, marked_up, alignment))
            return;

        comment = new CheckerboardItemText (text.replace ("\n", " "), alignment, marked_up);

        if (comment_visible) {
            recalc_size ("set_comment");
            notify_view_altered ();
        }
    }

    public void clear_comment () {
        if (comment == null)
            return;

        comment = null;

        if (comment_visible) {
            recalc_size ("clear_comment");
            notify_view_altered ();
        }
    }

    public string get_subtitle () {
        return (subtitle != null) ? subtitle.get_text () : "";
    }

    public void set_subtitle (string text, bool marked_up = false, Pango.Alignment alignment = Pango.Alignment.LEFT) {
        if (subtitle != null && subtitle.is_set_to (text, marked_up, alignment)) {
            return;
        }

        subtitle = new CheckerboardItemText (text, alignment, marked_up);

        if (subtitle_visible) {
            recalc_size ("set_subtitle");
            notify_view_altered ();
        }
    }

    public void clear_subtitle () {
        if (subtitle == null) {
            return;
        }

        subtitle = null;

        if (subtitle_visible) {
            recalc_size ("clear_subtitle");
            notify_view_altered ();
        }
    }

    protected override void notify_membership_changed (DataCollection? collection) {
        bool title_visible = (bool) get_collection_property (PROP_SHOW_TITLES, true);
        bool comment_visible = (bool) get_collection_property (PROP_SHOW_COMMENTS, true);
        bool subtitle_visible = (bool) get_collection_property (PROP_SHOW_SUBTITLES, false);

        bool altered = false;
        if (this.title_visible != title_visible) {
            this.title_visible = title_visible;
            altered = true;
        }

        if (this.comment_visible != comment_visible) {
            this.comment_visible = comment_visible;
            altered = true;
        }

        if (this.subtitle_visible != subtitle_visible) {
            this.subtitle_visible = subtitle_visible;
            altered = true;
        }

        if (altered || !requisition.has_area ()) {
            recalc_size ("notify_membership_changed");
            notify_view_altered ();
        }

        base.notify_membership_changed (collection);
    }

    protected override void notify_collection_property_set (string name, Value? old, Value val) {
        switch (name) {
        case PROP_SHOW_TITLES:
            title_visible = (bool) val;
            break;

        case PROP_SHOW_COMMENTS:
            comment_visible = (bool) val;
            break;

        case PROP_SHOW_SUBTITLES:
            subtitle_visible = (bool) val;
            break;
        }

        base.notify_collection_property_set (name, old, val);
    }

    // The alignment point is the coordinate on the y-axis (relative to the top of the
    // CheckerboardItem) which this item should be aligned to.  This allows for
    // bottom-alignment along the bottom edge of the thumbnail.
    public int get_alignment_point () {
        return FRAME_WIDTH + BORDER_WIDTH + (pixbuf_dim.height / ThumbnailCache.scale_factor);
    }

    public virtual void exposed () {
        exposure = true;
    }

    public virtual void unexposed () {
        exposure = false;

        if (title != null) {
            title.clear_pango_layout ();
        }

        if (comment != null) {
            comment.clear_pango_layout ();
        }

        if (subtitle != null) {
            subtitle.clear_pango_layout ();
        }
    }

    public virtual bool is_exposed () {
        return exposure;
    }

    public bool has_image () {
        return pixbuf != null;
    }

    public Gdk.Pixbuf? get_image () {
        return pixbuf;
    }

    public void set_image (Gdk.Pixbuf pixbuf) {
        this.pixbuf = pixbuf;
        display_pixbuf = pixbuf;
        pixbuf_dim = Dimensions.for_pixbuf (pixbuf);

        recalc_size ("set_image");
        notify_view_altered ();
    }

    public void clear_image (Dimensions dim) {
        bool had_image = pixbuf != null;

        pixbuf = null;
        display_pixbuf = null;
        pixbuf_dim = dim;

        recalc_size ("clear_image");

        if (had_image) {
            notify_view_altered ();
        }
    }

    public static int get_max_width (int scale) {
        // width is frame width (two sides) + frame padding (two sides) + width of pixbuf (text
        // never wider)
        return (FRAME_WIDTH * 2) + scale;
    }

    private void recalc_size (string reason) {
        Dimensions old_requisition = requisition;

        // only add in the text heights if they're displayed
        int title_height = (title != null && title_visible) ? title.get_height () + LABEL_PADDING : 0;
        int comment_height = (comment != null && comment_visible) ? comment.get_height () + LABEL_PADDING : 0;
        int subtitle_height = (subtitle != null && subtitle_visible) ? subtitle.get_height () + LABEL_PADDING : 0;

        // width is frame width (two sides) + frame padding (two sides) + width of pixbuf
        // (text never wider)
        requisition.width = (FRAME_WIDTH * 2) + (BORDER_WIDTH * 2) + (pixbuf_dim.width / ThumbnailCache.scale_factor);

        // height is frame width (two sides) + frame padding (two sides) + height of pixbuf
        // + height of text + label padding (between pixbuf and text)
        requisition.height = (FRAME_WIDTH * 2) +
                             (BORDER_WIDTH * 2) +
                             (pixbuf_dim.height / ThumbnailCache.scale_factor) +
                             title_height + comment_height + subtitle_height;

#if TRACE_REFLOW_ITEMS
        debug ("recalc_size %s: %s title_height=%d comment_height=%d subtitle_height=%d requisition=%s",
               get_source ().get_name (), reason, title_height, comment_height, subtitle_height,
               requisition.to_string ());
#endif

        if (!requisition.approx_equals (old_requisition)) {
#if TRACE_REFLOW_ITEMS
            debug ("recalc_size %s: %s notifying geometry altered", get_source ().get_name (), reason);
#endif
            notify_geometry_altered ();
        }
    }

    protected static Dimensions get_border_dimensions (Dimensions object_dim, int border_width) {
        Dimensions dimensions = Dimensions ();
        dimensions.width = object_dim.width + (border_width * 2);
        dimensions.height = object_dim.height + (border_width * 2);
        return dimensions;
    }

    protected static Gdk.Point get_border_origin (Gdk.Point object_origin, int border_width) {
        Gdk.Point origin = Gdk.Point ();
        origin.x = object_origin.x - border_width;
        origin.y = object_origin.y - border_width;
        return origin;
    }

    public Gdk.Rectangle get_selection_button_area () {
        Gdk.Rectangle selection_button_area = Gdk.Rectangle ();
        selection_button_area.x = allocation.x;
        selection_button_area.y = allocation.y;
        selection_button_area.width = SELECTION_ICON_SIZE;
        selection_button_area.height = SELECTION_ICON_SIZE;
        return selection_button_area;
    }

    public virtual void paint (Cairo.Context ctx, Gtk.StyleContext style_context) {
        style_context.save ();
        string selection_icon = null;
        if (is_selected ()) {
            style_context.set_state (Gtk.StateFlags.CHECKED);
            selection_icon = Resources.ICON_SELECTION_REMOVE;
        } else {
            if (brightened != null) {
                selection_icon = Resources.ICON_SELECTION_ADD;
            }
        }

        var scale_factor = style_context.get_scale ();

        if (display_pixbuf != null) {
            var origin_x = allocation.x + FRAME_WIDTH + BORDER_WIDTH;
            var origin_y = allocation.y + FRAME_WIDTH + BORDER_WIDTH;
            var pixbuf_width = display_pixbuf.width / scale_factor;
            var pixbuf_height = display_pixbuf.height / scale_factor;
            style_context.render_background (ctx, origin_x, origin_y, pixbuf_width, pixbuf_height);
            var radius = style_context.get_property ("border-radius", style_context.get_state ()).get_int ();
            ctx.save ();
            ctx.move_to (origin_x + radius, origin_y);
            ctx.arc (origin_x + pixbuf_width - radius, origin_y + radius, radius, Math.PI * 1.5, Math.PI * 2);
            ctx.arc (origin_x + pixbuf_width - radius, origin_y + pixbuf_height - radius, radius, 0, Math.PI_2);
            ctx.arc (origin_x + radius, origin_y + pixbuf_height - radius, radius, Math.PI_2, Math.PI);
            ctx.arc (origin_x + radius, origin_y + radius, radius, Math.PI, Math.PI * 1.5);
            ctx.close_path ();
            ctx.scale (1.0 / scale_factor, 1.0 / scale_factor);
            Gdk.cairo_set_source_pixbuf (ctx, display_pixbuf, origin_x * scale_factor, origin_y * scale_factor);
            ctx.clip ();
            ctx.paint ();
            ctx.restore ();

            style_context.render_frame (ctx, origin_x, origin_y, pixbuf_width, pixbuf_height);
        }

        // Add the selection helper
        Gdk.Pixbuf? selection_icon_pix = null;

        if (selection_icon != null) {
            try {
                selection_icon_pix = Gtk.IconTheme.get_default ().load_icon_for_scale (selection_icon, SELECTION_ICON_SIZE, scale_factor, Gtk.IconLookupFlags.GENERIC_FALLBACK);
            } catch (Error err) {
                warning ("Could not load %s: %s", selection_icon, err.message);
            }
        }

        if (selection_icon_pix != null) {
            Gdk.Rectangle selection_icon_area = get_selection_button_area ();
            ctx.save ();
            ctx.scale (1.0 / scale_factor, 1.0 / scale_factor);
            style_context.render_icon (ctx, selection_icon_pix, selection_icon_area.x * scale_factor, selection_icon_area.y * scale_factor);
            ctx.restore ();
        }

        // Add the title and subtitle
        style_context.add_class (Gtk.STYLE_CLASS_LABEL);
        // title and subtitles are LABEL_PADDING below bottom of pixbuf
        int text_y = allocation.y + FRAME_WIDTH + (pixbuf_dim.height / scale_factor) + FRAME_WIDTH + LABEL_PADDING;
        if (title != null && title_visible) {
            var title_allocation = title.allocation;
            // get the layout sized so its with is no more than the pixbuf's
            // resize the text width to be no more than the pixbuf's
            title_allocation.x = allocation.x + FRAME_WIDTH;
            title_allocation.y = text_y;
            title_allocation.width = (pixbuf_dim.width / scale_factor);
            title_allocation.height = title.get_height ();

            var layout = title.get_pango_layout (pixbuf_dim.width / scale_factor);
            Pango.cairo_update_layout (ctx, layout);
            style_context.render_layout (ctx, title_allocation.x, title_allocation.y, layout);

            text_y += title.get_height () + LABEL_PADDING;
        }

        if (comment != null && comment_visible) {
            var comment_allocation = comment.allocation;
            comment_allocation.x = allocation.x + FRAME_WIDTH;
            comment_allocation.y = text_y;
            comment_allocation.width = pixbuf_dim.width / scale_factor;
            comment_allocation.height = comment.get_height ();

            var layout = comment.get_pango_layout (pixbuf_dim.width / scale_factor);
            Pango.cairo_update_layout (ctx, layout);
            style_context.render_layout (ctx, comment_allocation.x, comment_allocation.y, layout);

            text_y += comment.get_height () + LABEL_PADDING;
        }

        if (subtitle != null && subtitle_visible) {
            var subtitle_allocation = subtitle.allocation;
            subtitle_allocation.x = allocation.x + FRAME_WIDTH;
            subtitle_allocation.y = text_y;
            subtitle_allocation.width = pixbuf_dim.width / scale_factor;
            subtitle_allocation.height = subtitle.get_height ();

            var layout = subtitle.get_pango_layout (pixbuf_dim.width / scale_factor);
            Pango.cairo_update_layout (ctx, layout);
            style_context.render_layout (ctx, subtitle_allocation.x, subtitle_allocation.y, layout);

            // increment text_y if more text lines follow
        }

        style_context.restore ();
    }

    public void set_grid_coordinates (int col, int row) {
        this.col = col;
        this.row = row;
    }

    public int get_column () {
        return col;
    }

    public int get_row () {
        return row;
    }

    public void brighten () {
        // "should" implies "can" and "didn't already"
        if (brightened != null || pixbuf == null)
            return;

        // create a new lightened pixbuf to display
        brightened = pixbuf.copy ();
        shift_colors (brightened, BRIGHTEN_SHIFT, BRIGHTEN_SHIFT, BRIGHTEN_SHIFT, 0);

        display_pixbuf = brightened;

        notify_view_altered ();
    }

    public void unbrighten () {
        // "should", "can", "didn't already"
        if (brightened == null || pixbuf == null)
            return;

        brightened = null;

        // return to the normal image
        display_pixbuf = pixbuf;

        notify_view_altered ();
    }

    public override void visibility_changed (bool visible) {
        // if going from visible to hidden, unbrighten
        if (!visible)
            unbrighten ();

        base.visibility_changed (visible);
    }

    private bool query_tooltip_on_text (CheckerboardItemText text, Gtk.Tooltip tooltip) {
        if (!text.get_pango_layout ().is_ellipsized ())
            return false;

        if (text.is_marked_up ())
            tooltip.set_markup (text.get_text ());
        else
            tooltip.set_text (text.get_text ());

        return true;
    }

    public bool query_tooltip (int x, int y, Gtk.Tooltip tooltip) {
        if (title != null && title_visible && coord_in_rectangle (x, y, title.allocation))
            return query_tooltip_on_text (title, tooltip);

        if (comment != null && comment_visible && coord_in_rectangle (x, y, comment.allocation))
            return query_tooltip_on_text (comment, tooltip);

        if (subtitle != null && subtitle_visible && coord_in_rectangle (x, y, subtitle.allocation))
            return query_tooltip_on_text (subtitle, tooltip);

        return false;
    }
}
