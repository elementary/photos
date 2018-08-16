/*
* Copyright (c) 2009-2013 Yorba Foundation
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

public abstract class EditingHostPage : SinglePhotoPage {
    public const int TRINKET_SCALE = 24;
    public const int TRINKET_PADDING = 1;

    public const double ZOOM_INCREMENT_SIZE = 0.03;
    public const int PAN_INCREMENT_SIZE = 64; /* in pixels */
    public const int TOOL_WINDOW_SEPARATOR = 8;
    public const int PIXBUF_CACHE_COUNT = 5;
    public const int ORIGINAL_PIXBUF_CACHE_COUNT = 5;

    private class EditingHostCanvas : EditingTools.PhotoCanvas {
        private EditingHostPage host_page;

        public EditingHostCanvas (EditingHostPage host_page) {
            base (host_page.get_container (), host_page.canvas.get_window (), host_page.get_photo (),
                  host_page.get_cairo_context (), host_page.get_surface_dim (), host_page.get_scaled_pixbuf (),
                  host_page.get_scaled_pixbuf_position ());

            this.host_page = host_page;
        }

        public override void repaint () {
            host_page.repaint ();
        }

        public override unowned Gtk.StyleContext get_style_context () {
            return host_page.canvas.get_style_context ();
        }
    }

    private SourceCollection sources;
    private ViewCollection? parent_view = null;
    private Gdk.Pixbuf swapped = null;
    private bool pixbuf_dirty = true;
    protected Gtk.ToolButton rotate_button = null;
    private Gtk.ToolButton flip_button = null;
    private Gtk.ToggleToolButton crop_button = null;
    private Gtk.ToggleToolButton redeye_button = null;
    private Gtk.ToggleToolButton adjust_button = null;
    private Gtk.ToggleToolButton straighten_button = null;
    protected Gtk.ToggleToolButton enhance_button = null;
    private SliderAssembly zoom_slider = null;
    private Gtk.ToolButton prev_button = null;
    private Gtk.ToolButton next_button = null;
    private EditingTools.EditingTool current_tool = null;
    private Gtk.ToggleToolButton current_editing_toggle = null;
    private Gtk.Settings settings;
    private Gdk.Pixbuf cancel_editing_pixbuf = null;
    private bool photo_missing = false;
    private PixbufCache cache = null;
    private PixbufCache master_cache = null;
    private DragAndDropHandler dnd_handler = null;
    private Gdk.Point zoom_pan_start_point;
    private bool is_pan_in_progress = false;
    private double saved_slider_val = 0.0;
    private ZoomBuffer? zoom_buffer = null;
    private Gee.HashMap<string, int> last_locations = new Gee.HashMap<string, int> ();

    public EditingHostPage (SourceCollection sources, string name) {
        base (name, false);

        this.sources = sources;
        settings = get_settings ();

        // when photo is altered need to update it here
        sources.items_altered.connect (on_photos_altered);

        // monitor when the ViewCollection's contents change
        get_view ().contents_altered.connect (on_view_contents_ordering_altered);
        get_view ().ordering_changed.connect (on_view_contents_ordering_altered);

        // the viewport can change size independent of the window being resized (when the searchbar
        // disappears, for example)
        viewport.size_allocate.connect (on_viewport_resized);

        toolbar = get_toolbar ();
    }

    public override Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            // set up page's toolbar (used by AppWindow for layout and FullscreenWindow as a popup)

            rotate_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("object-rotate-right", Gtk.IconSize.LARGE_TOOLBAR), _("Rotate"));
            rotate_button.tooltip_text = Resources.ROTATE_CW_TOOLTIP;
            rotate_button.clicked.connect (on_rotate_clockwise);

            flip_button = new Gtk.ToolButton (null, null);
            flip_button.icon_name = "object-flip-horizontal";
            flip_button.tooltip_text = Resources.HFLIP_TOOLTIP;
            flip_button.clicked.connect (on_flip_horizontally);

            crop_button = new Gtk.ToggleToolButton ();
            crop_button.icon_widget = new Gtk.Image.from_icon_name ("image-crop", Gtk.IconSize.LARGE_TOOLBAR);
            crop_button.tooltip_text = Resources.CROP_TOOLTIP;
            crop_button.toggled.connect (on_crop_toggled);

            straighten_button = new Gtk.ToggleToolButton ();
            straighten_button.icon_widget = new Gtk.Image.from_icon_name ("object-straighten", Gtk.IconSize.LARGE_TOOLBAR);
            straighten_button.tooltip_text = Resources.STRAIGHTEN_TOOLTIP;
            straighten_button.toggled.connect (on_straighten_toggled);

            redeye_button = new Gtk.ToggleToolButton ();
            redeye_button.icon_widget = new Gtk.Image.from_icon_name ("image-red-eye", Gtk.IconSize.LARGE_TOOLBAR);
            redeye_button.tooltip_text = Resources.RED_EYE_TOOLTIP;
            redeye_button.toggled.connect (on_redeye_toggled);

            adjust_button = new Gtk.ToggleToolButton ();
            adjust_button.icon_widget = new Gtk.Image.from_icon_name ("image-adjust", Gtk.IconSize.LARGE_TOOLBAR);
            adjust_button.tooltip_text = Resources.ADJUST_TOOLTIP;
            adjust_button.toggled.connect (on_adjust_toggled);

            enhance_button = new Gtk.ToggleToolButton ();
            enhance_button.icon_widget = new Gtk.Image.from_icon_name ("image-auto-adjust", Gtk.IconSize.LARGE_TOOLBAR);
            enhance_button.tooltip_text = Resources.ENHANCE_TOOLTIP;
            enhance_button.clicked.connect (on_enhance);

            var separator = new Gtk.SeparatorToolItem ();
            separator.set_expand (true);

            var zoom_original = new Gtk.Button.from_icon_name ("zoom-original-symbolic", Gtk.IconSize.MENU);
            zoom_original.tooltip_text = _("Zoom 1:1");
            zoom_original.valign = Gtk.Align.CENTER;
            zoom_original.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            zoom_original.clicked.connect (() => {
                snap_zoom_to_isomorphic ();
            });

            zoom_slider = new SliderAssembly (0, 1.1, 0.1, 0);
            zoom_slider.value_changed.connect (on_zoom_slider_value_changed);

            var zoom_group = new Gtk.Grid ();
            zoom_group.column_spacing = 6;
            zoom_group.add (zoom_original);
            zoom_group.add (zoom_slider);

            var group_wrapper = new Gtk.ToolItem ();
            group_wrapper.add (zoom_group);

            prev_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR), null);
            prev_button.tooltip_text = _("Previous photo");
            prev_button.clicked.connect (on_previous_photo);

            next_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR), null);
            next_button.tooltip_text = _("Next photo");
            next_button.clicked.connect (on_next_photo);

            toolbar = base.get_toolbar ();
            toolbar.add (prev_button);
            toolbar.add (next_button);
            toolbar.add (new Gtk.SeparatorToolItem ());
            toolbar.add (rotate_button);
            toolbar.add (flip_button);
            toolbar.add (new Gtk.SeparatorToolItem ());
            toolbar.add (crop_button);
            toolbar.add (straighten_button);
            toolbar.add (new Gtk.SeparatorToolItem ());
            toolbar.add (redeye_button);
            toolbar.add (adjust_button);
            toolbar.add (enhance_button);
            toolbar.add (separator);
            toolbar.add (group_wrapper);

            //  show metadata sidebar button
            var app = AppWindow.get_instance () as LibraryWindow;
            if (app != null) {
                show_sidebar_button = MediaPage.create_sidebar_button ();
                show_sidebar_button.clicked.connect (on_show_sidebar);
                toolbar.insert (show_sidebar_button, -1);
                update_sidebar_action (!app.is_metadata_sidebar_visible ());
            }
        }

        return toolbar;
    }

    ~EditingHostPage () {
        sources.items_altered.disconnect (on_photos_altered);

        get_view ().contents_altered.disconnect (on_view_contents_ordering_altered);
        get_view ().ordering_changed.disconnect (on_view_contents_ordering_altered);
    }

    private void on_show_sidebar () {
        var app = AppWindow.get_instance () as LibraryWindow;
        if (app != null) {
            app.set_metadata_sidebar_visible (!app.is_metadata_sidebar_visible ());
            update_sidebar_action (!app.is_metadata_sidebar_visible ());
        }
    }

    private void on_zoom_slider_value_changed () {
        ZoomState new_zoom_state = ZoomState.rescale (get_zoom_state (), zoom_slider.slider_value);

        if (new_zoom_state.is_default ()) {
            cancel_zoom ();
        } else {
            set_zoom_state (new_zoom_state);
        }

        repaint ();

        update_cursor_for_zoom_context ();
    }

    private Gdk.Point get_cursor_wrt_viewport (Gdk.EventScroll event) {
        Gdk.Point cursor_wrt_canvas = {0};
        cursor_wrt_canvas.x = (int) event.x;
        cursor_wrt_canvas.y = (int) event.y;

        Gdk.Rectangle viewport_wrt_canvas = get_zoom_state ().get_viewing_rectangle_wrt_screen ();
        Gdk.Point result = {0};
        result.x = cursor_wrt_canvas.x - viewport_wrt_canvas.x;
        result.x = result.x.clamp (0, viewport_wrt_canvas.width);
        result.y = cursor_wrt_canvas.y - viewport_wrt_canvas.y;
        result.y = result.y.clamp (0, viewport_wrt_canvas.height);

        return result;
    }

    private Gdk.Point get_cursor_wrt_viewport_center (Gdk.EventScroll event) {
        Gdk.Point cursor_wrt_viewport = get_cursor_wrt_viewport (event);
        Gdk.Rectangle viewport_wrt_canvas = get_zoom_state ().get_viewing_rectangle_wrt_screen ();

        Gdk.Point viewport_center = {0};
        viewport_center.x = viewport_wrt_canvas.width / 2;
        viewport_center.y = viewport_wrt_canvas.height / 2;

        return subtract_points (cursor_wrt_viewport, viewport_center);
    }

    private Gdk.Point get_iso_pixel_under_cursor (Gdk.EventScroll event) {
        Gdk.Point viewport_center_iso = scale_point (get_zoom_state ().get_viewport_center (),
                                        1.0 / get_zoom_state ().get_zoom_factor ());

        Gdk.Point cursor_wrt_center_iso = scale_point (get_cursor_wrt_viewport_center (event),
                                          1.0 / get_zoom_state ().get_zoom_factor ());

        return add_points (viewport_center_iso, cursor_wrt_center_iso);
    }

    private double snap_interpolation_factor (double interp) {
        if (interp < 0.03)
            interp = 0.0;
        else if (interp > 0.97)
            interp = 1.0;

        return interp;
    }

    private double adjust_interpolation_factor (double adjustment) {
        return snap_interpolation_factor (get_zoom_state ().get_interpolation_factor () + adjustment);
    }

    private void zoom_about_event_cursor_point (Gdk.EventScroll event, double zoom_increment) {
        if (photo_missing)
            return;

        Gdk.Point cursor_wrt_viewport_center = get_cursor_wrt_viewport_center (event);
        Gdk.Point iso_pixel_under_cursor = get_iso_pixel_under_cursor (event);

        double interp = adjust_interpolation_factor (zoom_increment);
        zoom_slider.value_changed.disconnect (on_zoom_slider_value_changed);
        zoom_slider.slider_value = interp;
        zoom_slider.value_changed.connect (on_zoom_slider_value_changed);

        ZoomState new_zoom_state = ZoomState.rescale (get_zoom_state (), interp);

        if (new_zoom_state.is_min ()) {
            cancel_zoom ();
            update_cursor_for_zoom_context ();
            repaint ();
            return;
        }

        Gdk.Point new_zoomed_old_cursor = scale_point (iso_pixel_under_cursor,
                                          new_zoom_state.get_zoom_factor ());
        Gdk.Point desired_new_viewport_center = subtract_points (new_zoomed_old_cursor,
                                                cursor_wrt_viewport_center);

        new_zoom_state = ZoomState.pan (new_zoom_state, desired_new_viewport_center);

        set_zoom_state (new_zoom_state);
        repaint ();

        update_cursor_for_zoom_context ();
    }

    protected void snap_zoom_to_min () {
        zoom_slider.slider_value = 0.0;
    }

    protected void snap_zoom_to_max () {
        zoom_slider.slider_value = 1.0;
    }

    protected void snap_zoom_to_isomorphic () {
        ZoomState iso_state = ZoomState.rescale_to_isomorphic (get_zoom_state ());
        zoom_slider.slider_value = iso_state.get_interpolation_factor ();
    }

    protected virtual bool on_zoom_slider_key_press (Gdk.EventKey event) {
        switch (Gdk.keyval_name (event.keyval)) {
        case "equal":
        case "plus":
        case "KP_Add":
            activate_action ("IncreaseSize");
            return true;

        case "minus":
        case "underscore":
        case "KP_Subtract":
            activate_action ("DecreaseSize");
            return true;

        case "KP_Divide":
            activate_action ("Zoom100");
            return true;

        case "KP_Multiply":
            activate_action ("ZoomFit");
            return true;
        }

        return false;
    }

    protected virtual void on_increase_size () {
        zoom_slider.increase_step ();
    }

    protected virtual void on_decrease_size () {
        zoom_slider.decrease_step ();
    }

    protected override void save_zoom_state () {
        base.save_zoom_state ();
        saved_slider_val = zoom_slider.slider_value;
    }

    protected override ZoomBuffer? get_zoom_buffer () {
        return zoom_buffer;
    }

    protected override bool on_mousewheel_up (Gdk.EventScroll event) {
        if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0)
            return false;

        if (get_zoom_state ().is_max () || !zoom_slider.get_sensitive ())
            return false;

        zoom_about_event_cursor_point (event, ZOOM_INCREMENT_SIZE);
        return false;
    }

    protected override bool on_mousewheel_down (Gdk.EventScroll event) {
        if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0)
            return false;

        if (get_zoom_state ().is_min () || !zoom_slider.get_sensitive ())
            return false;

        zoom_about_event_cursor_point (event, -ZOOM_INCREMENT_SIZE);
        return false;
    }

    protected override void restore_zoom_state () {
        base.restore_zoom_state ();

        zoom_slider.value_changed.disconnect (on_zoom_slider_value_changed);
        zoom_slider.slider_value = saved_slider_val;
        zoom_slider.value_changed.connect (on_zoom_slider_value_changed);
    }

    public override bool is_zoom_supported () {
        return true;
    }

    public override void set_container (Gtk.Window container) {
        base.set_container (container);

        // DnD not available in fullscreen mode
        if (! (container is FullscreenWindow))
            dnd_handler = new DragAndDropHandler (this);
    }

    public ViewCollection? get_parent_view () {
        return parent_view;
    }

    protected void update_enhance_action () {
        if (has_photo ()) {
            Gtk.Action? action = get_action ("Enhance");
            assert (action != null);

            bool is_enhanced = get_photo ().is_enhanced ();

            action.label = is_enhanced ? Resources.UNENHANCE_MENU : Resources.ENHANCE_MENU;
            action.sensitive = true;

            enhance_button.clicked.disconnect (on_enhance);
            enhance_button.active = get_photo ().is_enhanced ();
            enhance_button.clicked.connect (on_enhance);
        } else
            set_action_sensitive ("Enhance", false);
    }

    public bool has_photo () {
        return get_photo () != null;
    }

    public Photo? get_photo () {
        // If there is currently no selected photo, return null.
        if (get_view ().get_selected_count () == 0)
            return null;

        // Use the selected photo.  There should only ever be one selected photo,
        // which is the currently displayed photo.
        assert (get_view ().get_selected_count () == 1);
        return (Photo) get_view ().get_selected_at (0).get_source ();
    }

    // Called before the photo changes.
    protected virtual void photo_changing (Photo new_photo) {
        // If this is a raw image with a missing development, we can regenerate it,
        // so don't mark it as missing.
        if (new_photo.get_file_format () == PhotoFileFormat.RAW)
            set_photo_missing (false);
        else
            set_photo_missing (!new_photo.get_file ().query_exists ());

        update_enhance_action ();
        update_ui (photo_missing);
    }

    private void set_photo (Photo photo) {
        zoom_slider.value_changed.disconnect (on_zoom_slider_value_changed);
        zoom_slider.slider_value = 0.0;
        zoom_slider.value_changed.connect (on_zoom_slider_value_changed);
        photo_changing (photo);
        DataView view = get_view ().get_view_for_source (photo);
        assert (view != null);

        // Select photo.
        get_view ().unselect_all ();
        Marker marker = get_view ().mark (view);
        get_view ().select_marked (marker);

        // also select it in the parent view's collection, so when the user returns to that view
        // it's apparent which one was being viewed here
        if (parent_view != null) {
            parent_view.unselect_all ();
            DataView? view_in_parent = parent_view.get_view_for_source_filtered (photo);
            if (null != view_in_parent)
                parent_view.select_marked (parent_view.mark (view_in_parent));
        }
    }

    public override void realize () {
        base.realize ();

        rebuild_caches ("realize");
    }

    public override void switched_to () {
        base.switched_to ();

        rebuild_caches ("switched_to");

        // check if the photo altered while away
        if (has_photo () && pixbuf_dirty)
            replace_photo (get_photo ());

        var app = AppWindow.get_instance () as LibraryWindow;
        if (app != null) {
            update_sidebar_action (!app.is_metadata_sidebar_visible ());
        }
    }

    public override void switching_from () {
        base.switching_from ();

        is_pan_in_progress = false;

        deactivate_tool ();

        // Ticket #3255 - Checkerboard page didn't `remember` what was selected
        // when the user went into and out of the photo page without navigating
        // to next or previous.
        // Since the base class intentionally unselects everything in the parent
        // view, reselect the currently marked photo here...
        if ((has_photo ()) && (parent_view != null)) {
            parent_view.select_marked (parent_view.mark (parent_view.get_view_for_source (get_photo ())));
        }

        parent_view = null;
        get_view ().clear ();
    }

    public override void switching_to_fullscreen (FullscreenWindow fsw) {
        base.switching_to_fullscreen (fsw);

        deactivate_tool ();

        cancel_zoom ();
        is_pan_in_progress = false;

        Page page = fsw.get_current_page ();
        if (page != null)
            page.get_view ().items_selected.connect (on_selection_changed);
    }

    public override void returning_from_fullscreen (FullscreenWindow fsw) {
        base.returning_from_fullscreen (fsw);

        repaint ();

        Page page = fsw.get_current_page ();
        if (page != null)
            page.get_view ().items_selected.disconnect (on_selection_changed);
    }

    private void on_selection_changed (Gee.Iterable<DataView> selected) {
        foreach (DataView view in selected) {
            replace_photo ((Photo) view.get_source ());
            break;
        }
    }

    protected void enable_rotate (bool should_enable) {
        rotate_button.set_sensitive (should_enable);
    }

    // This function should be called if the viewport has changed and the pixbuf cache needs to be
    // regenerated.  Use refresh_caches () if the contents of the ViewCollection have changed
    // but not the viewport.
    private void rebuild_caches (string caller) {
        Scaling scaling = get_canvas_scaling ();

        // only rebuild if not the same scaling
        if (cache != null && cache.get_scaling ().equals (scaling))
            return;

        debug ("Rebuild pixbuf caches: %s (%s)", caller, scaling.to_string ());

        // if dropping an old cache, clear the signal handler so currently executing requests
        // don't complete and cancel anything queued up
        if (cache != null) {
            cache.fetched.disconnect (on_pixbuf_fetched);
            cache.cancel_all ();
        }

        cache = new PixbufCache (sources, PixbufCache.PhotoType.BASELINE, scaling, PIXBUF_CACHE_COUNT);
        cache.fetched.connect (on_pixbuf_fetched);

        master_cache = new PixbufCache (sources, PixbufCache.PhotoType.MASTER, scaling,
                                        ORIGINAL_PIXBUF_CACHE_COUNT, master_cache_filter);

        refresh_caches (caller);
    }

    // See note at rebuild_caches () for usage.
    private void refresh_caches (string caller) {
        if (has_photo ()) {
            debug ("Refresh pixbuf caches (%s): prefetching neighbors of %s", caller,
                   get_photo ().to_string ());
            prefetch_neighbors (get_view (), get_photo ());
        } else {
            debug ("Refresh pixbuf caches (%s): (no photo)", caller);
        }
    }

    private bool master_cache_filter (Photo photo) {
        return photo.has_transformations () || photo.has_editable ();
    }

    private void on_pixbuf_fetched (Photo photo, Gdk.Pixbuf? pixbuf, Error? err) {
        // if not of the current photo, nothing more to do
        if (!photo.equals (get_photo ()))
            return;

        if (pixbuf != null) {
            // update the preview image in the zoom buffer
            if ((zoom_buffer != null) && (zoom_buffer.get_backing_photo () == photo))
                zoom_buffer = new ZoomBuffer (this, photo, pixbuf);

            // if no tool, use the pixbuf directly, otherwise, let the tool decide what should be
            // displayed
            Dimensions max_dim = photo.get_dimensions ();
            if (current_tool != null) {
                try {
                    Dimensions tool_pixbuf_dim;
                    Gdk.Pixbuf? tool_pixbuf = current_tool.get_display_pixbuf (get_canvas_scaling (),
                                              photo, out tool_pixbuf_dim);

                    if (tool_pixbuf != null) {
                        pixbuf = tool_pixbuf;
                        max_dim = tool_pixbuf_dim;
                    }
                } catch (Error err) {
                    warning ("Unable to fetch tool pixbuf for %s: %s", photo.to_string (), err.message);
                    set_photo_missing (true);

                    return;
                }
            }

            set_pixbuf (pixbuf, max_dim);
            pixbuf_dirty = false;

            notify_photo_backing_missing ((Photo) photo, false);
        } else if (err != null) {
            // this call merely updates the UI, and can be called indiscriminantly, whether or not
            // the photo is actually missing
            set_photo_missing (true);

            // this call should only be used when we're sure the photo is missing
            notify_photo_backing_missing ((Photo) photo, true);
        }
    }

    private void prefetch_neighbors (ViewCollection controller, Photo photo) {
        PixbufCache.PixbufCacheBatch normal_batch = new PixbufCache.PixbufCacheBatch ();
        PixbufCache.PixbufCacheBatch master_batch = new PixbufCache.PixbufCacheBatch ();

        normal_batch.set (BackgroundJob.JobPriority.HIGHEST, photo);
        master_batch.set (BackgroundJob.JobPriority.LOW, photo);

        DataSource next_source, prev_source;
        if (!controller.get_immediate_neighbors (photo, out next_source, out prev_source, Photo.TYPENAME))
            return;

        Photo next = (Photo) next_source;
        Photo prev = (Photo) prev_source;

        // prefetch the immediate neighbors and their outer neighbors, for plenty of readahead
        foreach (DataSource neighbor_source in controller.get_extended_neighbors (photo, Photo.TYPENAME)) {
            Photo neighbor = (Photo) neighbor_source;

            BackgroundJob.JobPriority priority = BackgroundJob.JobPriority.NORMAL;
            if (neighbor.equals (next) || neighbor.equals (prev))
                priority = BackgroundJob.JobPriority.HIGH;

            normal_batch.set (priority, neighbor);
            master_batch.set (BackgroundJob.JobPriority.LOWEST, neighbor);
        }

        cache.prefetch_batch (normal_batch);
        master_cache.prefetch_batch (master_batch);
    }

    // Cancels prefetches of old neighbors, but does not cancel them if they are the new
    // neighbors
    private void cancel_prefetch_neighbors (ViewCollection old_controller, Photo old_photo,
                                            ViewCollection new_controller, Photo new_photo) {
        Gee.Set<Photo> old_neighbors = (Gee.Set<Photo>)
                                       old_controller.get_extended_neighbors (old_photo, Photo.TYPENAME);
        Gee.Set<Photo> new_neighbors = (Gee.Set<Photo>)
                                       new_controller.get_extended_neighbors (new_photo, Photo.TYPENAME);

        foreach (Photo old_neighbor in old_neighbors) {
            // cancel prefetch and drop from cache if old neighbor is not part of the new
            // neighborhood
            if (!new_neighbors.contains (old_neighbor) && !new_photo.equals (old_neighbor)) {
                cache.drop (old_neighbor);
                master_cache.drop (old_neighbor);
            }
        }

        // do same for old photo
        if (!new_neighbors.contains (old_photo) && !new_photo.equals (old_photo)) {
            cache.drop (old_photo);
            master_cache.drop (old_photo);
        }
    }

    protected virtual DataView create_photo_view (DataSource source) {
        return new PhotoView ((PhotoSource) source);
    }

    private bool is_photo (DataSource source) {
        return source is PhotoSource;
    }

    protected void display_copy_of (ViewCollection controller, Photo starting_photo) {
        assert (controller.get_view_for_source (starting_photo) != null);

        if (controller != get_view () && controller != parent_view) {
            get_view ().clear ();
            get_view ().copy_into (controller, create_photo_view, is_photo);
            parent_view = controller;
        }

        replace_photo (starting_photo);
    }

    protected void display_mirror_of (ViewCollection controller, Photo starting_photo) {
        assert (controller.get_view_for_source (starting_photo) != null);

        if (controller != get_view () && controller != parent_view) {
            get_view ().clear ();
            get_view ().mirror (controller, create_photo_view, is_photo);
            parent_view = controller;
        }

        replace_photo (starting_photo);
    }

    protected virtual void update_ui (bool missing) {
        bool sensitivity = !missing;

        flip_button.sensitive = sensitivity;
        rotate_button.sensitive = sensitivity;
        crop_button.sensitive = sensitivity;
        straighten_button.sensitive = sensitivity;
        redeye_button.sensitive = sensitivity;
        adjust_button.sensitive = sensitivity;
        enhance_button.sensitive = sensitivity;
        zoom_slider.sensitive = sensitivity;

        deactivate_tool ();
    }

    // This should only be called when it's known that the photo is actually missing.
    protected virtual void notify_photo_backing_missing (Photo photo, bool missing) {
    }

    private void draw_message (string message) {
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

        paint_text (pango_layout, x, y);
    }

    // This method can be called indiscriminantly, whether or not the backing is actually present.
    protected void set_photo_missing (bool missing) {
        if (photo_missing == missing)
            return;

        photo_missing = missing;

        Photo? photo = get_photo ();
        if (photo == null)
            return;

        update_ui (missing);

        if (photo_missing) {
            try {
                Gdk.Pixbuf pixbuf = photo.get_preview_pixbuf (get_canvas_scaling ());

                pixbuf = pixbuf.composite_color_simple (pixbuf.get_width (), pixbuf.get_height (),
                                                        Gdk.InterpType.NEAREST, 100, 2, 0, 0);

                set_pixbuf (pixbuf, photo.get_dimensions ());
            } catch (GLib.Error err) {
                warning ("%s", err.message);
            }
        }
    }

    public bool get_photo_missing () {
        return photo_missing;
    }

    protected virtual bool confirm_replace_photo (Photo? old_photo, Photo new_photo) {
        return true;
    }

    private Gdk.Pixbuf get_zoom_pixbuf (Photo new_photo) {
        Gdk.Pixbuf? pixbuf = cache.get_ready_pixbuf (new_photo);
        if (pixbuf == null) {
            try {
                pixbuf = new_photo.get_preview_pixbuf (get_canvas_scaling ());
            } catch (Error err) {
                warning ("%s", err.message);
            }
        }
        if (pixbuf == null) {
            weak Gtk.IconTheme icon_theme = Gtk.IconTheme.get_for_screen (get_window ().get_screen ());
            // Create empty pixbuf.
            try {
                pixbuf = icon_theme.load_icon ("image-missing", Gtk.IconSize.DIALOG, Gtk.IconLookupFlags.GENERIC_FALLBACK);
                get_canvas_scaling ().perform_on_pixbuf (pixbuf, Gdk.InterpType.NEAREST, true);
            } catch (Error e) {
                critical (e.message);
            }

        }
        return pixbuf;
    }

    private void replace_photo (Photo new_photo) {
        // if it's the same Photo object, the scaling hasn't changed, and the photo's file
        // has not gone missing or re-appeared, there's nothing to do otherwise,
        // just need to reload the image for the proper scaling. Of course, the photo's pixels
        // might've changed, so rebuild the zoom buffer.
        if (new_photo.equals (get_photo ()) && !pixbuf_dirty && !photo_missing) {
            zoom_buffer = new ZoomBuffer (this, new_photo, get_zoom_pixbuf (new_photo));
            return;
        }

        // only check if okay to replace if there's something to replace and someone's concerned
        if (has_photo () && !new_photo.equals (get_photo ()) && confirm_replace_photo != null) {
            if (!confirm_replace_photo (get_photo (), new_photo))
                return;
        }

        deactivate_tool ();

        // swap out new photo and old photo and process change
        Photo old_photo = get_photo ();
        set_photo (new_photo);
        page_name = new_photo.get_name ();

        // clear out the swap buffer
        swapped = null;

        // reset flags
        set_photo_missing (!new_photo.get_file ().query_exists ());
        pixbuf_dirty = true;

        // it's possible for this to be called prior to the page being realized, however, the
        // underlying canvas has a scaling, so use that (hence rebuild rather than refresh)
        rebuild_caches ("replace_photo");

        if (old_photo != null)
            cancel_prefetch_neighbors (get_view (), old_photo, get_view (), new_photo);

        cancel_zoom ();

        zoom_buffer = new ZoomBuffer (this, new_photo, get_zoom_pixbuf (new_photo));

        quick_update_pixbuf ();

        // now refresh the caches, which ensures that the neighbors get pulled into memory
        refresh_caches ("replace_photo");
    }

    protected override void cancel_zoom () {
        base.cancel_zoom ();

        zoom_slider.value_changed.disconnect (on_zoom_slider_value_changed);
        zoom_slider.value_changed.connect (on_zoom_slider_value_changed);

        if (get_photo () != null)
            set_zoom_state (ZoomState (get_photo ().get_dimensions (), get_surface_dim (), 0.0));

        // when cancelling zoom, panning becomes impossible, so set the cursor back to
        // a left pointer in case it had been a hand-grip cursor indicating that panning
        // was possible; the null guards are required because zoom can be cancelled at
        // any time
        if (canvas != null && canvas.get_window () != null)
            set_page_cursor (Gdk.CursorType.LEFT_PTR);

        repaint ();
    }

    private void quick_update_pixbuf () {
        Gdk.Pixbuf? pixbuf = cache.get_ready_pixbuf (get_photo ());
        if (pixbuf != null) {
            set_pixbuf (pixbuf, get_photo ().get_dimensions ());
            pixbuf_dirty = false;

            return;
        }

        Scaling scaling = get_canvas_scaling ();

        debug ("Using progressive load for %s (%s)", get_photo ().to_string (), scaling.to_string ());

        // throw a resized large thumbnail up to get an image on the screen quickly,
        // and when ready decode and display the full image
        try {
            set_pixbuf (get_photo ().get_preview_pixbuf (scaling), get_photo ().get_dimensions ());
        } catch (Error err) {
            warning ("%s", err.message);
        }

        cache.prefetch (get_photo (), BackgroundJob.JobPriority.HIGHEST);

        // although final pixbuf not in place, it's on its way, so set this to clean so later calls
        // don't reload again
        pixbuf_dirty = false;
    }

    private bool update_pixbuf () {
#if MEASURE_PIPELINE
        Timer timer = new Timer ();
#endif

        Photo? photo = get_photo ();
        if (photo == null)
            return false;

        Gdk.Pixbuf pixbuf = null;
        Dimensions max_dim = photo.get_dimensions ();

        try {
            Dimensions tool_pixbuf_dim = {0};
            if (current_tool != null)
                pixbuf = current_tool.get_display_pixbuf (get_canvas_scaling (), photo, out tool_pixbuf_dim);

            if (pixbuf != null)
                max_dim = tool_pixbuf_dim;
        } catch (Error err) {
            warning ("%s", err.message);
            set_photo_missing (true);
        }

        if (!photo_missing) {
            // if no pixbuf, see if it's waiting in the cache
            if (pixbuf == null)
                pixbuf = cache.get_ready_pixbuf (photo);

            // if still no pixbuf, background fetch and let the signal handler update the display
            if (pixbuf == null)
                cache.prefetch (photo);
        }

        if (!photo_missing && pixbuf != null) {
            set_pixbuf (pixbuf, max_dim);
            pixbuf_dirty = false;
        }

#if MEASURE_PIPELINE
        debug ("UPDATE_PIXBUF: total=%lf", timer.elapsed ());
#endif

        return false;
    }

    protected override void on_resize (Gdk.Rectangle rect) {
        base.on_resize (rect);

        track_tool_window ();
    }

    protected override void on_resize_finished (Gdk.Rectangle rect) {
        // because we've loaded SinglePhotoPage with an image scaled to window size, as the window
        // is resized it scales that, which pixellates, especially scaling upward.  Once the window
        // resize is complete, we get a fresh image for the new window's size
        rebuild_caches ("on_resize_finished");
        pixbuf_dirty = true;

        update_pixbuf ();
    }

    private void on_viewport_resized () {
        // this means the viewport (the display area) has changed, but not necessarily the
        // toplevel window's dimensions
        rebuild_caches ("on_viewport_resized");
        pixbuf_dirty = true;

        update_pixbuf ();
    }

    protected override void update_actions (int selected_count, int count) {
        bool multiple_photos = get_view ().get_sources_of_type_count (typeof (Photo)) > 1;

        prev_button.sensitive = multiple_photos;
        next_button.sensitive = multiple_photos;

        Photo? photo = get_photo ();
        Scaling scaling = get_canvas_scaling ();

        rotate_button.sensitive = ((photo != null) && (!photo_missing) && photo.check_can_rotate ()) ?
                                  is_rotate_available (photo) : false;
        crop_button.sensitive = ((photo != null) && (!photo_missing)) ?
                                EditingTools.CropTool.is_available (photo, scaling) : false;
        redeye_button.sensitive = ((photo != null) && (!photo_missing)) ?
                                  EditingTools.RedeyeTool.is_available (photo, scaling) : false;
        adjust_button.sensitive = ((photo != null) && (!photo_missing)) ?
                                  EditingTools.AdjustTool.is_available (photo, scaling) : false;
        enhance_button.sensitive = ((photo != null) && (!photo_missing)) ?
                                   is_enhance_available (photo) : false;
        straighten_button.sensitive = ((photo != null) && (!photo_missing)) ?
                                      EditingTools.StraightenTool.is_available (photo, scaling) : false;
        base.update_actions (selected_count, count);
    }

    protected override bool on_shift_pressed (Gdk.EventKey? event) {
        // show quick compare of original only if no tool is in use, the original pixbuf is handy
        if (current_tool == null && !get_ctrl_pressed () && !get_alt_pressed ())
            swap_in_original ();

        return base.on_shift_pressed (event);
    }

    protected override bool on_shift_released (Gdk.EventKey? event) {
        if (current_tool == null)
            swap_out_original ();

        return base.on_shift_released (event);
    }

    protected override bool on_alt_pressed (Gdk.EventKey? event) {
        if (current_tool == null)
            swap_out_original ();

        return base.on_alt_pressed (event);
    }

    protected override bool on_alt_released (Gdk.EventKey? event) {
        if (current_tool == null && get_shift_pressed () && !get_ctrl_pressed ())
            swap_in_original ();

        return base.on_alt_released (event);
    }

    private void swap_in_original () {
        Gdk.Pixbuf? original;

        original =
            get_photo ().get_original_orientation ().rotate_pixbuf (get_photo ().get_prefetched_copy ());

        if (original == null)
            return;

        // store what's currently displayed only for the duration of the shift pressing
        swapped = get_unscaled_pixbuf ();

        // save the zoom state and cancel zoom so that the user can see all of the original
        // photo
        if (zoom_slider.slider_value != 0.0) {
            save_zoom_state ();
            cancel_zoom ();
        }

        set_pixbuf (original, get_photo ().get_master_dimensions ());
    }

    private void swap_out_original () {
        if (swapped != null) {
            set_pixbuf (swapped, get_photo ().get_dimensions ());

            restore_zoom_state ();
            update_cursor_for_zoom_context ();

            // only store swapped once; it'll be set the next on_shift_pressed
            swapped = null;
        }
    }

    private void activate_tool (EditingTools.EditingTool tool) {
        // cancel any zoom -- we don't currently allow tools to be used when an image is zoomed,
        // though we may at some point in the future.
        save_zoom_state ();
        cancel_zoom ();

        // deactivate current tool ... current implementation is one tool at a time.  In the future,
        // tools may be allowed to be executing at the same time.
        deactivate_tool ();

        // save current pixbuf to use if user cancels operation
        cancel_editing_pixbuf = get_unscaled_pixbuf ();

        // see if the tool wants a different pixbuf displayed and what its max dimensions should be
        Gdk.Pixbuf unscaled;
        Dimensions max_dim = get_photo ().get_dimensions ();
        try {
            Dimensions tool_pixbuf_dim = {0};
            unscaled = tool.get_display_pixbuf (get_canvas_scaling (), get_photo (), out tool_pixbuf_dim);

            if (unscaled != null)
                max_dim = tool_pixbuf_dim;
        } catch (Error err) {
            warning ("%s", err.message);
            set_photo_missing (true);

            // untoggle tool button (usually done after deactivate, but tool never deactivated)
            assert (current_editing_toggle != null);
            current_editing_toggle.active = false;

            return;
        }

        if (unscaled != null)
            set_pixbuf (unscaled, max_dim);

        // create the PhotoCanvas object for a two-way interface to the tool
        EditingTools.PhotoCanvas photo_canvas = new EditingHostCanvas (this);

        // hook tool into event system and activate it
        current_tool = tool;
        current_tool.activate (photo_canvas);

        // if the tool has an auxiliary window, move it properly on the screen
        place_tool_window ();

        // repaint entire view, with the tool now hooked in
        repaint ();
    }

    private void deactivate_tool (Command? command = null, Gdk.Pixbuf? new_pixbuf = null,
                                  Dimensions new_max_dim = Dimensions (), bool needs_improvement = false) {
        if (current_tool == null)
            return;

        EditingTools.EditingTool tool = current_tool;
        current_tool = null;

        // save the position of the tool
        EditingTools.EditingToolWindow? tool_window = tool.get_tool_window ();
        if (tool_window != null && tool_window.has_user_moved ()) {
            int last_location_x, last_location_y;
            tool_window.get_position (out last_location_x, out last_location_y);
            last_locations[tool.name + "_x"] = last_location_x;
            last_locations[tool.name + "_y"] = last_location_y;
        }

        // deactivate with the tool taken out of the hooks and
        // disconnect any signals we may have connected on activating
        tool.deactivate ();

        tool.activated.disconnect (on_tool_activated);
        tool.deactivated.disconnect (on_tool_deactivated);
        tool.applied.disconnect (on_tool_applied);
        tool.cancelled.disconnect (on_tool_cancelled);
        tool.aborted.disconnect (on_tool_aborted);

        tool = null;

        // only null the toggle when the tool is completely deactivated; that is, deactive the tool
        // before updating the UI
        current_editing_toggle = null;

        // display the (possibly) new photo
        Gdk.Pixbuf replacement = null;
        if (new_pixbuf != null) {
            replacement = new_pixbuf;
        } else if (cancel_editing_pixbuf != null) {
            replacement = cancel_editing_pixbuf;
            new_max_dim = Dimensions.for_pixbuf (replacement);
            needs_improvement = false;
        } else {
            needs_improvement = true;
        }

        if (replacement != null)
            set_pixbuf (replacement, new_max_dim);
        cancel_editing_pixbuf = null;

        // if this is a rough pixbuf, schedule an improvement
        if (needs_improvement) {
            pixbuf_dirty = true;
            Idle.add (update_pixbuf);
        }

        // execute the tool's command
        if (command != null)
            get_command_manager ().execute (command);
    }

    // This virtual method is called only when the user double-clicks on the page and no tool
    // is active
    protected virtual bool on_double_click (Gdk.EventButton event) {
        return false;
    }

    // Return true to block the DnD handler from activating a drag
    protected override bool on_left_click (Gdk.EventButton event) {
        // report double-click if no tool is active, otherwise all double-clicks are eaten
        if (event.type == Gdk.EventType.2BUTTON_PRESS)
            return (current_tool == null) ? on_double_click (event) : false;

        int x = (int) event.x;
        int y = (int) event.y;

        // if no editing tool, then determine whether we should start a pan operation over the
        // zoomed photo or fall through to the default DnD behavior if we're not zoomed
        if ((current_tool == null) && (zoom_slider.slider_value != 0.0)) {
            zoom_pan_start_point.x = (int) event.x;
            zoom_pan_start_point.y = (int) event.y;
            is_pan_in_progress = true;
            suspend_cursor_hiding ();

            return true;
        }

        // default behavior when photo isn't zoomed -- return false to start DnD operation
        if (current_tool == null) {
            return false;
        }

        // only concerned about mouse-downs on the pixbuf ... return true prevents DnD when the
        // user drags outside the displayed photo
        if (!is_inside_pixbuf (x, y))
            return true;

        current_tool.on_left_click (x, y);

        // block DnD handlers if tool is enabled
        return true;
    }

    protected override bool on_left_released (Gdk.EventButton event) {
        if (is_pan_in_progress) {
            Gdk.Point viewport_center = get_zoom_state ().get_viewport_center ();
            int delta_x = ((int) event.x) - zoom_pan_start_point.x;
            int delta_y = ((int) event.y) - zoom_pan_start_point.y;
            viewport_center.x -= delta_x;
            viewport_center.y -= delta_y;

            ZoomState zoom_state = ZoomState.pan (get_zoom_state (), viewport_center);
            set_zoom_state (zoom_state);
            get_zoom_buffer ().flush_demand_cache (zoom_state);

            is_pan_in_progress = false;
            restore_cursor_hiding ();
        }

        // report all releases, as it's possible the user click and dragged from inside the
        // pixbuf to the gutters
        if (current_tool == null)
            return false;

        current_tool.on_left_released ((int) event.x, (int) event.y);

        if (current_tool.get_tool_window () != null)
            current_tool.get_tool_window ().present ();

        return false;
    }

    protected override bool on_right_click (Gdk.EventButton event) {
        return on_context_buttonpress (event);
    }

    private void on_photos_altered (Gee.Map<DataObject, Alteration> map) {
        if (!map.has_key (get_photo ()))
            return;

        pixbuf_dirty = true;

        // if transformed, want to prefetch the original pixbuf for this photo, but after the
        // signal is completed as PixbufCache may remove it in this round of fired signals
        if (get_photo ().has_transformations ())
            Idle.add (on_fetch_original);

        update_actions (get_view ().get_selected_count (), get_view ().get_count ());
    }

    private void on_view_contents_ordering_altered () {
        refresh_caches ("on_view_contents_ordering_altered");
    }

    private bool on_fetch_original () {
        if (has_photo ())
            master_cache.prefetch (get_photo (), BackgroundJob.JobPriority.LOW);

        return false;
    }

    private bool is_panning_possible () {
        // panning is impossible if all the content to be drawn completely fits on the drawing
        // canvas
        Dimensions content_dim = {0};
        content_dim.width = get_zoom_state ().get_zoomed_width ();
        content_dim.height = get_zoom_state ().get_zoomed_height ();
        Dimensions canvas_dim = get_surface_dim ();

        return (! (canvas_dim.width >= content_dim.width && canvas_dim.height >= content_dim.height));
    }

    private void update_cursor_for_zoom_context () {
        if (is_panning_possible ())
            set_page_cursor (Gdk.CursorType.FLEUR);
        else
            set_page_cursor (Gdk.CursorType.LEFT_PTR);
    }

    // Return true to block the DnD handler from activating a drag
    protected override bool on_motion (Gdk.EventMotion event, int x, int y, Gdk.ModifierType mask) {
        if (current_tool != null) {
            current_tool.on_motion (x, y, mask);

            // this requests more events after "hints"
            Gdk.Event.request_motions (event);

            return true;
        }

        update_cursor_for_zoom_context ();

        if (is_pan_in_progress) {
            int delta_x = ((int) event.x) - zoom_pan_start_point.x;
            int delta_y = ((int) event.y) - zoom_pan_start_point.y;

            Gdk.Point viewport_center = get_zoom_state ().get_viewport_center ();
            viewport_center.x -= delta_x;
            viewport_center.y -= delta_y;

            ZoomState zoom_state = ZoomState.pan (get_zoom_state (), viewport_center);

            on_interactive_pan (zoom_state);
            return true;
        }

        return base.on_motion (event, x, y, mask);
    }

    protected override bool on_leave_notify_event () {
        if (current_tool != null)
            return current_tool.on_leave_notify_event ();

        return base.on_leave_notify_event ();
    }

    private void track_tool_window () {
        // if editing tool window is present and the user hasn't touched it, it moves with the window
        if (current_tool != null) {
            EditingTools.EditingToolWindow tool_window = current_tool.get_tool_window ();
            if (tool_window != null && !tool_window.has_user_moved ())
                place_tool_window ();
        }
    }

    protected override void on_move (Gdk.Rectangle rect) {
        track_tool_window ();

        base.on_move (rect);
    }

    protected override void on_move_finished (Gdk.Rectangle rect) {
        last_locations.clear ();

        base.on_move_finished (rect);
    }

    private bool on_keyboard_pan_event (Gdk.EventKey event) {
        ZoomState current_zoom_state = get_zoom_state ();
        Gdk.Point viewport_center = current_zoom_state.get_viewport_center ();

        switch (Gdk.keyval_name (event.keyval)) {
        case "Left":
        case "KP_Left":
        case "KP_4":
            viewport_center.x -= PAN_INCREMENT_SIZE;
            break;

        case "Right":
        case "KP_Right":
        case "KP_6":
            viewport_center.x += PAN_INCREMENT_SIZE;
            break;

        case "Down":
        case "KP_Down":
        case "KP_2":
            viewport_center.y += PAN_INCREMENT_SIZE;
            break;

        case "Up":
        case "KP_Up":
        case "KP_8":
            viewport_center.y -= PAN_INCREMENT_SIZE;
            break;

        default:
            return false;
        }

        ZoomState new_zoom_state = ZoomState.pan (current_zoom_state, viewport_center);
        set_zoom_state (new_zoom_state);
        repaint ();

        return true;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        // editing tool gets first crack at the keypress
        if (current_tool != null) {
            if (current_tool.on_keypress (event))
                return true;
        }

        // if panning is possible, the pan handler (on MUNI?) gets second crack at the keypress
        if (is_panning_possible ()) {
            if (on_keyboard_pan_event (event))
                return true;
        }

        // if the user pressed the "0", "1" or "2" keys then handle the event as if were
        // directed at the zoom slider ("0", "1" and "2" are hotkeys that jump to preset
        // zoom levels
        if (on_zoom_slider_key_press (event))
            return true;

        bool handled = true;

        switch (Gdk.keyval_name (event.keyval)) {
        // this block is only here to prevent base from moving focus to toolbar
        case "Down":
        case "KP_Down":
            ;
            break;

        case "equal":
        case "plus":
        case "KP_Add":
            activate_action ("IncreaseSize");
            break;

        // underscore is the keysym generated by SHIFT-[minus sign] -- this means zoom out
        case "minus":
        case "underscore":
        case "KP_Subtract":
            activate_action ("DecreaseSize");
            break;

        default:
            handled = false;
            break;
        }

        if (handled)
            return true;

        return (base.key_press_event != null) ? base.key_press_event (event) : true;
    }

    protected override void new_surface (Cairo.Context default_ctx, Dimensions dim) {
        // if tool is open, update its canvas object
        if (current_tool != null)
            current_tool.canvas.set_surface (default_ctx, dim);
    }

    protected override void updated_pixbuf (Gdk.Pixbuf pixbuf, SinglePhotoPage.UpdateReason reason,
                                            Dimensions old_dim) {
        // only purpose here is to inform editing tool of change and drop the cancelled
        // pixbuf, which is now sized incorrectly
        if (current_tool != null && reason != SinglePhotoPage.UpdateReason.QUALITY_IMPROVEMENT) {
            current_tool.canvas.resized_pixbuf (old_dim, pixbuf, get_scaled_pixbuf_position ());
            cancel_editing_pixbuf = null;
        }
    }

    protected virtual Gdk.Pixbuf? get_bottom_left_trinket (int scale) {
        return null;
    }

    protected virtual Gdk.Pixbuf? get_top_left_trinket (int scale) {
        return null;
    }

    protected virtual Gdk.Pixbuf? get_top_right_trinket (int scale) {
        return null;
    }

    protected virtual Gdk.Pixbuf? get_bottom_right_trinket (int scale) {
        return null;
    }

    protected override void paint (Cairo.Context ctx, Dimensions ctx_dim) {
        if (current_tool != null) {
            current_tool.paint (ctx);

            return;
        }

        if (photo_missing && has_photo ()) {
            canvas.get_style_context ().render_background (ctx, 0, 0, ctx_dim.width, ctx_dim.height);
            ctx.paint ();
            draw_message (_ ("Photo source file missing: %s").printf (get_photo ().get_file ().get_path ()));
            return;
        }

        base.paint (ctx, ctx_dim);

        if (!get_zoom_state ().is_default ())
            return;

        // paint trinkets last
        Gdk.Rectangle scaled_rect = get_scaled_pixbuf_position ();

        Gdk.Pixbuf? trinket = get_bottom_left_trinket (TRINKET_SCALE);
        if (trinket != null) {
            int x = scaled_rect.x + TRINKET_PADDING;
            int y = scaled_rect.y + scaled_rect.height - trinket.height - TRINKET_PADDING;
            Gdk.cairo_set_source_pixbuf (ctx, trinket, x, y);
            ctx.rectangle (x, y, trinket.width, trinket.height);
            ctx.fill ();
        }

        trinket = get_top_left_trinket (TRINKET_SCALE);
        if (trinket != null) {
            int x = scaled_rect.x + TRINKET_PADDING;
            int y = scaled_rect.y + TRINKET_PADDING;
            Gdk.cairo_set_source_pixbuf (ctx, trinket, x, y);
            ctx.rectangle (x, y, trinket.width, trinket.height);
            ctx.fill ();
        }

        trinket = get_top_right_trinket (TRINKET_SCALE);
        if (trinket != null) {
            int x = scaled_rect.x + scaled_rect.width - trinket.width - TRINKET_PADDING;
            int y = scaled_rect.y + TRINKET_PADDING;
            Gdk.cairo_set_source_pixbuf (ctx, trinket, x, y);
            ctx.rectangle (x, y, trinket.width, trinket.height);
            ctx.fill ();
        }

        trinket = get_bottom_right_trinket (TRINKET_SCALE);
        if (trinket != null) {
            int x = scaled_rect.x + scaled_rect.width - trinket.width - TRINKET_PADDING;
            int y = scaled_rect.y + scaled_rect.height - trinket.height - TRINKET_PADDING;
            Gdk.cairo_set_source_pixbuf (ctx, trinket, x, y);
            ctx.rectangle (x, y, trinket.width, trinket.height);
            ctx.fill ();
        }
    }

    public bool is_rotate_available (Photo photo) {
        return !photo_missing;
    }

    private void rotate (Rotation rotation, string name, string description) {
        cancel_zoom ();

        deactivate_tool ();

        if (!has_photo ())
            return;

        RotateSingleCommand command = new RotateSingleCommand (get_photo (), rotation, name,
                description);
        get_command_manager ().execute (command);
    }

    public void on_rotate_clockwise () {
        rotate (Rotation.CLOCKWISE, Resources.ROTATE_CW_FULL_LABEL, Resources.ROTATE_CW_TOOLTIP);
    }

    public void on_rotate_counterclockwise () {
        rotate (Rotation.COUNTERCLOCKWISE, Resources.ROTATE_CCW_FULL_LABEL, Resources.ROTATE_CCW_TOOLTIP);
    }

    public void on_flip_horizontally () {
        rotate (Rotation.MIRROR, Resources.HFLIP_LABEL, "");
    }

    public void on_flip_vertically () {
        rotate (Rotation.UPSIDE_DOWN, Resources.VFLIP_LABEL, "");
    }

    public void on_revert () {
        if (photo_missing)
            return;

        deactivate_tool ();

        if (!has_photo ())
            return;

        if (get_photo ().has_editable ()) {
            if (!revert_editable_dialog (AppWindow.get_instance (),
                                         (Gee.Collection<Photo>) get_view ().get_sources ())) {
                return;
            }

            get_photo ().revert_to_master ();
        }

        cancel_zoom ();

        set_photo_missing (false);

        RevertSingleCommand command = new RevertSingleCommand (get_photo ());
        get_command_manager ().execute (command);
    }

    public void on_adjust_date_time () {
        if (!has_photo ())
            return;

        AdjustDateTimeDialog dialog = new AdjustDateTimeDialog (get_photo (), 1, ! (this is DirectPhotoPage));

        int64 time_shift;
        bool keep_relativity, modify_originals;
        if (dialog.execute (out time_shift, out keep_relativity, out modify_originals)) {
            get_view ().get_selected ();

            AdjustDateTimePhotoCommand command = new AdjustDateTimePhotoCommand (get_photo (),
                    time_shift, modify_originals);
            get_command_manager ().execute (command);
        }
    }

    protected override bool on_ctrl_pressed (Gdk.EventKey? event) {
        rotate_button.set_icon_widget (new Gtk.Image.from_icon_name ("object-rotate-left", Gtk.IconSize.LARGE_TOOLBAR));
        rotate_button.set_tooltip_text (Resources.ROTATE_CCW_TOOLTIP);
        rotate_button.show_all ();
        rotate_button.clicked.disconnect (on_rotate_clockwise);
        rotate_button.clicked.connect (on_rotate_counterclockwise);

        flip_button.set_icon_name (Resources.VFLIP);
        flip_button.set_label (Resources.VFLIP_LABEL);
        flip_button.set_tooltip_text (Resources.VFLIP_TOOLTIP);
        flip_button.clicked.disconnect (on_flip_horizontally);
        flip_button.clicked.connect (on_flip_vertically);

        if (current_tool == null)
            swap_out_original ();

        return base.on_ctrl_pressed (event);
    }

    protected override bool on_ctrl_released (Gdk.EventKey? event) {
        rotate_button.set_icon_widget (new Gtk.Image.from_icon_name ("object-rotate-right", Gtk.IconSize.LARGE_TOOLBAR));
        rotate_button.set_tooltip_text (Resources.ROTATE_CW_TOOLTIP);
        rotate_button.show_all ();
        rotate_button.clicked.disconnect (on_rotate_counterclockwise);
        rotate_button.clicked.connect (on_rotate_clockwise);

        flip_button.set_icon_name (Resources.HFLIP);
        flip_button.set_label (Resources.HFLIP_LABEL);
        flip_button.set_tooltip_text (Resources.HFLIP_TOOLTIP);
        flip_button.clicked.disconnect (on_flip_vertically);
        flip_button.clicked.connect (on_flip_horizontally);

        if (current_tool == null && get_shift_pressed () && !get_alt_pressed ())
            swap_in_original ();

        return base.on_ctrl_released (event);
    }

    protected void on_tool_button_toggled (Gtk.ToggleToolButton toggle, EditingTools.EditingTool.Factory factory) {
        // if the button is an activate, deactivate any current tool running; if the button is
        // a deactivate, deactivate the current tool and exit
        bool deactivating_only = (!toggle.active && current_editing_toggle == toggle);
        deactivate_tool ();

        if (deactivating_only) {
            restore_cursor_hiding ();
            return;
        }

        suspend_cursor_hiding ();

        current_editing_toggle = toggle;

        // create the tool, hook its signals, and activate
        EditingTools.EditingTool tool = factory ();
        tool.activated.connect (on_tool_activated);
        tool.deactivated.connect (on_tool_deactivated);
        tool.applied.connect (on_tool_applied);
        tool.cancelled.connect (on_tool_cancelled);
        tool.aborted.connect (on_tool_aborted);

        activate_tool (tool);
    }

    private void on_tool_activated () {
        assert (current_editing_toggle != null);
        zoom_slider.set_sensitive (false);
        current_editing_toggle.active = true;
    }

    private void on_tool_deactivated () {
        assert (current_editing_toggle != null);
        zoom_slider.set_sensitive (true);
        current_editing_toggle.active = false;
    }

    private void on_tool_applied (Command? command, Gdk.Pixbuf? new_pixbuf, Dimensions new_max_dim,
                                  bool needs_improvement) {
        deactivate_tool (command, new_pixbuf, new_max_dim, needs_improvement);
    }

    private void on_tool_cancelled () {
        deactivate_tool ();

        update_enhance_action ();
        restore_zoom_state ();
        repaint ();
    }

    private void on_tool_aborted () {
        deactivate_tool ();
        set_photo_missing (true);
    }

    protected void toggle_crop () {
        crop_button.set_active (!crop_button.get_active ());
    }

    protected void toggle_straighten () {
        straighten_button.set_active (!straighten_button.get_active ());
    }

    protected void toggle_redeye () {
        redeye_button.set_active (!redeye_button.get_active ());
    }

    protected void toggle_adjust () {
        adjust_button.set_active (!adjust_button.get_active ());
    }

    private void on_straighten_toggled () {
        on_tool_button_toggled (straighten_button, EditingTools.StraightenTool.factory);
    }

    private void on_crop_toggled () {
        on_tool_button_toggled (crop_button, EditingTools.CropTool.factory);
    }

    private void on_redeye_toggled () {
        on_tool_button_toggled (redeye_button, EditingTools.RedeyeTool.factory);
    }

    private void on_adjust_toggled () {
        on_tool_button_toggled (adjust_button, EditingTools.AdjustTool.factory);

        // with adjust tool open turn enhance into normal non toggle button
        if (adjust_button.active) {
            enhance_button.clicked.disconnect (on_enhance);
            enhance_button.active = false;
            enhance_button.clicked.connect (on_enhance);
        }
    }

    public bool is_enhance_available (Photo photo) {
        return !photo_missing;
    }

    public void on_enhance () {
        // because running multiple tools at once is not currently supported, deactivate any current
        // tool; however, there is a special case of running enhancement while the AdjustTool is
        // open, so allow for that
        if (! (current_tool is EditingTools.AdjustTool)) {
            deactivate_tool ();

            cancel_zoom ();
        }

        if (!has_photo ())
            return;

        EditingTools.AdjustTool adjust_tool = current_tool as EditingTools.AdjustTool;
        if (adjust_tool != null) {
            adjust_tool.enhance ();
            // with adjust tool open turn enhance into normal non toggle button
            enhance_button.clicked.disconnect (on_enhance);
            enhance_button.active = false;
            enhance_button.clicked.connect (on_enhance);
            return;
        }

        if (get_photo ().is_enhanced ()) {
            // Just undo if last on stack was enhance
            EnhanceSingleCommand cmd = get_command_manager ().get_undo_description () as EnhanceSingleCommand;
            if (cmd != null && cmd.source == get_photo ())
                get_command_manager ().undo ();
            else {
                UnEnhanceSingleCommand command = new UnEnhanceSingleCommand (get_photo ());
                get_command_manager ().execute (command);
            }
            get_photo ().set_enhanced (false);
        } else {
            // Just undo if last on stack was unenhance
            UnEnhanceSingleCommand cmd = get_command_manager ().get_undo_description () as UnEnhanceSingleCommand;
            if (cmd != null && cmd.source == get_photo ())
                get_command_manager ().undo ();
            else {
                EnhanceSingleCommand command = new EnhanceSingleCommand (get_photo ());
                get_command_manager ().execute (command);
            }
            get_photo ().set_enhanced (true);
        }

        update_enhance_action ();
    }

    public void on_copy_adjustments () {
        if (!has_photo ())
            return;
        PixelTransformationBundle.set_copied_color_adjustments (get_photo ().get_color_adjustments ());
        set_action_sensitive ("PasteColorAdjustments", true);
    }

    public void on_paste_adjustments () {
        PixelTransformationBundle? copied_adjustments = PixelTransformationBundle.get_copied_color_adjustments ();
        if (!has_photo () || copied_adjustments == null)
            return;

        AdjustColorsSingleCommand command = new AdjustColorsSingleCommand (get_photo (), copied_adjustments,
                Resources.PASTE_ADJUSTMENTS_LABEL, Resources.PASTE_ADJUSTMENTS_TOOLTIP);
        get_command_manager ().execute (command);
    }

    private void place_tool_window () {
        if (current_tool == null)
            return;

        EditingTools.EditingToolWindow tool_window = current_tool.get_tool_window ();
        if (tool_window == null)
            return;

        // do this so window size is properly allocated, but window not shown
        tool_window.show_all ();
        tool_window.hide ();

        Gtk.Allocation tool_alloc;
        tool_window.get_allocation (out tool_alloc);
        int x, y;

        // Check if the last location of the adjust tool is stored.
        if (last_locations.has_key (current_tool.name + "_x")) {
            x = last_locations[current_tool.name + "_x"];
            y = last_locations[current_tool.name + "_y"];
        } else {
            // No stored position
            if (get_container () == AppWindow.get_instance ()) {

                // Normal: position crop tool window centered on viewport/canvas at the bottom,
                // straddling the canvas and the toolbar
                int rx, ry;
                get_container ().get_window ().get_root_origin (out rx, out ry);

                Gtk.Allocation viewport_allocation;
                viewport.get_allocation (out viewport_allocation);

                int cx, cy, cwidth, cheight;
                cx = viewport_allocation.x;
                cy = viewport_allocation.y;
                cwidth = viewport_allocation.width;
                cheight = viewport_allocation.height;

                // it isn't clear why, but direct mode seems to want to position tool windows
                // differently than library mode...
                x = (this is DirectPhotoPage) ? (rx + cx + (cwidth / 2) - (tool_alloc.width / 2)) :
                    (rx + cx + (cwidth / 2));
                y = ry + cy + cheight - ((tool_alloc.height / 4) * 3);
            } else {
                assert (get_container () is FullscreenWindow);

                // Fullscreen: position crop tool window centered on screen at the bottom, just above the
                // toolbar
                Gtk.Allocation toolbar_alloc;
                get_toolbar ().get_allocation (out toolbar_alloc);

                var dimensions = Scaling.get_screen_dimensions (get_container ());
                x = dimensions.width;
                y = dimensions.height - toolbar_alloc.height - tool_alloc.height - TOOL_WINDOW_SEPARATOR;

                // put larger adjust tool off to the side
                if (current_tool is EditingTools.AdjustTool) {
                    x = x * 3 / 4;
                } else {
                    x = (x - tool_alloc.width) / 2;
                }
            }
        }

        // however, clamp the window so it's never off-screen initially
        var dimensions = Scaling.get_screen_dimensions (get_container ());
        x = x.clamp (0, dimensions.width - tool_alloc.width);
        y = y.clamp (0, dimensions.height - tool_alloc.height);

        tool_window.move (x, y);
        tool_window.show ();
        tool_window.present ();
    }

    protected override void on_next_photo () {
        deactivate_tool ();

        if (!has_photo ())
            return;

        Photo? current_photo = get_photo ();
        assert (current_photo != null);

        DataView current = get_view ().get_view_for_source (get_photo ());
        if (current == null)
            return;

        // search through the collection until the next photo is found or back at the starting point
        DataView? next = current;
        for (;;) {
            next = get_view ().get_next (next);
            if (next == null)
                break;

            Photo? next_photo = next.get_source () as Photo;
            if (next_photo == null)
                continue;

            if (next_photo == current_photo)
                break;

            replace_photo (next_photo);

            break;
        }
    }

    protected override void on_previous_photo () {
        deactivate_tool ();

        if (!has_photo ())
            return;

        Photo? current_photo = get_photo ();
        assert (current_photo != null);

        DataView current = get_view ().get_view_for_source (get_photo ());
        if (current == null)
            return;

        // loop until a previous photo is found or back at the starting point
        DataView? previous = current;
        for (;;) {
            previous = get_view ().get_previous (previous);
            if (previous == null)
                break;

            Photo? previous_photo = previous.get_source () as Photo;
            if (previous_photo == null)
                continue;

            if (previous_photo == current_photo)
                break;

            replace_photo (previous_photo);

            break;
        }
    }

    public bool has_current_tool () {
        return (current_tool != null);
    }

    protected void unset_view_collection () {
        parent_view = null;
    }
}
