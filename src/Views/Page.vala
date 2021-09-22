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

public abstract class Page : Gtk.ScrolledWindow {
    private const int CONSIDER_CONFIGURE_HALTED_MSEC = 400;

    protected Gtk.ActionBar? toolbar = null;
    protected Gtk.Button? show_sidebar_button = null;

    private ViewCollection view = null;
    private Gtk.Window container = null;
    private Gdk.Rectangle last_position = Gdk.Rectangle ();
    private Gtk.Widget event_source = null;
    private int64 last_configure_ms = 0;
    private bool report_move_finished = false;
    private bool report_resize_finished = false;
    private Gdk.Point last_down = Gdk.Point ();
    private bool is_destroyed = false;
    private bool ctrl_pressed = false;
    private bool alt_pressed = false;
    private bool shift_pressed = false;
    private bool super_pressed = false;
    private Gdk.CursorType last_cursor = Gdk.CursorType.LEFT_PTR;
    private bool cursor_hidden = false;
    private int cursor_hide_msec = 0;
    private uint last_timeout_id = 0;
    private int cursor_hide_time_cached = 0;
    private bool are_actions_attached = false;
    private OneShotScheduler? update_actions_scheduler = null;
    private Gtk.ActionGroup? action_group = null;
    private Gtk.ActionGroup[]? common_action_groups = null;
    private GLib.List<Gtk.Widget>? contractor_menu_items = null;
    protected Gtk.Box header_box;

    public bool in_view { get; private set; default = false; }
    public string page_name { get; construct set; }

    protected Page (string page_name) {
        Object (page_name: page_name);
    }

    construct {
        view = new ViewCollection ("ViewCollection for Page %s".printf (page_name));

        last_down = { -1, -1 };

        set_can_focus (true);

        popup_menu.connect (on_context_keypress);

        action_group = new Gtk.ActionGroup ("PageActionGroup");

        // Collect all Gtk.Actions and add them to the Page's Gtk.ActionGroup
        Gtk.ActionEntry[] action_entries = init_collect_action_entries ();
        if (action_entries.length > 0) {
            action_group.add_actions (action_entries, this);
        }

        // Collect all Gtk.ToggleActionEntries and add them to the Gtk.ActionGroup
        Gtk.ToggleActionEntry[] toggle_entries = init_collect_toggle_action_entries ();
        if (toggle_entries.length > 0) {
            action_group.add_toggle_actions (toggle_entries, this);
        }

        // Collect all Gtk.RadioActionEntries and add them to the Gtk.ActionGroup
        // (Would use a similar collection scheme as the other calls, but there is a binding
        // problem with Gtk.RadioActionCallback that doesn't allow it to be stored in a struct)
        register_radio_actions (action_group);

        // Get global (common) action groups from the application window
        common_action_groups = AppWindow.get_instance ().get_common_action_groups ();

        realize.connect (attach_view_signals);
    }

    ~Page () {
#if TRACE_DTORS
        debug ("DTOR: Page %s", page_name);
#endif
    }

    protected void populate_contractor_menu (Gtk.Menu menu) {
        File[] files = {};
        Gee.List<Granite.Services.Contract> contracts = null;
        try {
            var selected = get_view ().get_selected_sources ();
            foreach (var item in selected)
                files += (((Photo)item).get_file ());
            contracts = Granite.Services.ContractorProxy.get_contracts_for_files (files);
        } catch (Error e) {
            warning (e.message);
        }
        // Remove old contracts
        contractor_menu_items.foreach ((item) => {
            if (item != null && item is ContractMenuItem) item.destroy ();
        });

        //and replace it with menu_item from contractor
        for (int i = 0; i < contracts.size; i++) {
            var contract = contracts.get (i);
            Gtk.MenuItem menu_item;

            menu_item = new ContractMenuItem (contract, get_view ().get_selected_sources ());
            menu.append (menu_item);
            contractor_menu_items.append (menu_item);
        }
        menu.show_all ();
    }

    // This is called by the page
    // controller when it has removed this page ... pages should override
    // this (or the signal) to clean up
    public override void destroy () {
        if (is_destroyed)
            return;

        // untie signals
        detach_event_source ();
        detach_view_signals ();
        view.close ();

        // remove refs to external objects which may be pointing to the Page
        clear_container ();

        if (toolbar != null)
            toolbar.destroy ();

        // halt any pending callbacks
        if (update_actions_scheduler != null)
            update_actions_scheduler.cancel ();

        is_destroyed = true;

        base.destroy ();

        debug ("Page %s Destroyed", page_name);
    }

    public ViewCollection get_view () {
        return view;
    }

    public Gtk.Window? get_container () {
        return container;
    }

    public virtual void set_container (Gtk.Window container) {
        assert (this.container == null);

        this.container = container;
    }

    public virtual void clear_container () {
        container = null;
    }

    public void set_event_source (Gtk.Widget event_source) {
        assert (this.event_source == null);

        this.event_source = event_source;
        event_source.set_can_focus (true);

        // interested in mouse button and motion events on the event source
        event_source.add_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK
                                 | Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.POINTER_MOTION_HINT_MASK
                                 | Gdk.EventMask.BUTTON_MOTION_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK
                                 | Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK);
        event_source.button_press_event.connect (on_button_pressed_internal);
        event_source.button_release_event.connect (on_button_released_internal);
        event_source.motion_notify_event.connect (on_motion_internal);
        event_source.leave_notify_event.connect (on_leave_notify_event);
        event_source.scroll_event.connect (on_mousewheel_internal);
        event_source.realize.connect (on_event_source_realize);
    }

    private void detach_event_source () {
        if (event_source == null)
            return;

        event_source.button_press_event.disconnect (on_button_pressed_internal);
        event_source.button_release_event.disconnect (on_button_released_internal);
        event_source.motion_notify_event.disconnect (on_motion_internal);
        event_source.leave_notify_event.disconnect (on_leave_notify_event);
        event_source.scroll_event.disconnect (on_mousewheel_internal);

        event_source = null;
    }

    public Gtk.Widget? get_event_source () {
        return event_source;
    }

    /* Parameters add ability to have a widget inserted (by the parent) before or after the parents actionbar widgets
     * Otherwise Any widgets packed into the actionbar after getting it from the parent will appear inside the 
     * parent's widgets. */
    public Gtk.ActionBar get_toolbar (Gtk.Widget? add_widget = null,
                                      Gtk.PackType position = Gtk.PackType.START) {

        if (toolbar == null) {
            toolbar = new Gtk.ActionBar ();
            toolbar.get_style_context ().add_class ("bottom-toolbar"); // for elementary theme
            toolbar.valign = Gtk.Align.END;
            toolbar.halign = Gtk.Align.FILL;

            if (add_widget != null && position == Gtk.PackType.START) {
                toolbar.pack_start (add_widget);
            }

            add_toolbar_widgets (toolbar);

            if (add_widget != null && position == Gtk.PackType.END) {
                toolbar.pack_end (add_widget);
            }

            show_all ();
        }

        return toolbar;
    }

    protected virtual void add_toolbar_widgets (Gtk.ActionBar toolbar) {
    }

    public virtual Gtk.Menu? get_page_context_menu () {
        return null;
    }

    public virtual Gtk.Menu? get_page_sidebar_menu () {
        return null;
    }

    public virtual void switching_from () {
        in_view = false;
        toolbar = null;
    }

    public virtual void switched_to () {
        in_view = true;
        update_modifiers ();
    }

    public virtual void ready () {
    }

    public virtual void switching_to_fullscreen (FullscreenWindow fsw) {
    }

    public virtual void returning_from_fullscreen (FullscreenWindow fsw) {
    }

    public Gtk.Action? get_action (string name) {
        if (action_group == null)
            return null;

        Gtk.Action? action = action_group.get_action (name);
        if (action == null)
            action = get_common_action (name, false);

        if (action == null)
            warning ("Page %s: Unable to locate action %s", page_name, name);

        return action;
    }

    public void set_action_sensitive (string name, bool sensitive) {
        Gtk.Action? action = get_action (name);
        if (action != null)
            action.sensitive = sensitive;
    }

    public void set_action_visible (string name, bool visible) {
        Gtk.Action? action = get_action (name);
        if (action == null)
            return;

        action.visible = visible;
        action.sensitive = visible;
    }

    public void activate_action (string name) {
        Gtk.Action? action = get_action (name);
        if (action != null)
            action.activate ();
    }

    public Gtk.Action? get_common_action (string name, bool log_warning = true) {
        if (common_action_groups == null)
            return null;

        foreach (Gtk.ActionGroup group in common_action_groups) {
            Gtk.Action? action = group.get_action (name);
            if (action != null)
                return action;
        }

        if (log_warning)
            warning ("Page %s: Unable to locate common action %s", page_name, name);

        return null;
    }

    public void update_sidebar_action (bool show) {
        if (show_sidebar_button == null)
            return;
        if (!show) {
            show_sidebar_button.image = new Gtk.Image.from_icon_name (Resources.HIDE_PANE, Gtk.IconSize.LARGE_TOOLBAR);
            show_sidebar_button.tooltip_text = Resources.UNTOGGLE_METAPANE_TOOLTIP;
        } else {
            show_sidebar_button.image = new Gtk.Image.from_icon_name (Resources.SHOW_PANE, Gtk.IconSize.LARGE_TOOLBAR);
            show_sidebar_button.tooltip_text = Resources.TOGGLE_METAPANE_TOOLTIP;
        }
        var app = AppWindow.get_instance () as LibraryWindow;
        app.update_common_toggle_actions ();
    }

    public bool get_ctrl_pressed () {
        return ctrl_pressed;
    }

    public bool get_alt_pressed () {
        return alt_pressed;
    }

    public bool get_shift_pressed () {
        return shift_pressed;
    }

    public bool get_super_pressed () {
        return super_pressed;
    }

    private bool get_modifiers (out bool ctrl, out bool alt, out bool shift, out bool super) {
        if (AppWindow.get_instance ().get_window () == null) {
            ctrl = false;
            alt = false;
            shift = false;
            super = false;

            return false;
        }

        int x, y;
        Gdk.ModifierType mask;
        var seat = Gdk.Display.get_default ().get_default_seat ();
        AppWindow.get_instance ().get_window ().get_device_position (seat.get_pointer (), out x, out y, out mask);

        ctrl = (mask & Gdk.ModifierType.CONTROL_MASK) != 0;
        alt = (mask & Gdk.ModifierType.MOD1_MASK) != 0;
        shift = (mask & Gdk.ModifierType.SHIFT_MASK) != 0;
        super = (mask & Gdk.ModifierType.MOD4_MASK) != 0; // not SUPER_MASK

        return true;
    }

    private void update_modifiers () {
        bool ctrl_currently_pressed, alt_currently_pressed, shift_currently_pressed,
             super_currently_pressed;
        if (!get_modifiers (out ctrl_currently_pressed, out alt_currently_pressed,
                            out shift_currently_pressed, out super_currently_pressed)) {
            return;
        }

        if (ctrl_pressed && !ctrl_currently_pressed)
            on_ctrl_released (null);
        else if (!ctrl_pressed && ctrl_currently_pressed)
            on_ctrl_pressed (null);

        if (alt_pressed && !alt_currently_pressed)
            on_alt_released (null);
        else if (!alt_pressed && alt_currently_pressed)
            on_alt_pressed (null);

        if (shift_pressed && !shift_currently_pressed)
            on_shift_released (null);
        else if (!shift_pressed && shift_currently_pressed)
            on_shift_pressed (null);

        if (super_pressed && !super_currently_pressed)
            on_super_released (null);
        else if (!super_pressed && super_currently_pressed)
            on_super_pressed (null);

        ctrl_pressed = ctrl_currently_pressed;
        alt_pressed = alt_currently_pressed;
        shift_pressed = shift_currently_pressed;
        super_pressed = super_currently_pressed;
    }

    public CommandManager get_command_manager () {
        return AppWindow.get_command_manager ();
    }

    public virtual Gtk.Box get_header_buttons () {
        header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        return header_box;
    }

    // Called from "realize"
    private void attach_view_signals () {
        if (are_actions_attached)
            return;

        // initialize the Gtk.Actions according to current state
        int selected_count = get_view ().get_selected_count ();
        int count = get_view ().get_count ();
        init_actions (selected_count, count);
        update_actions (selected_count, count);

        // monitor state changes to update actions
        get_view ().items_state_changed.connect (on_update_actions);
        get_view ().selection_group_altered.connect (on_update_actions);
        get_view ().items_visibility_changed.connect (on_update_actions);
        get_view ().contents_altered.connect (on_update_actions);

        are_actions_attached = true;
    }

    // Called from destroy ()
    private void detach_view_signals () {
        if (!are_actions_attached)
            return;

        get_view ().items_state_changed.disconnect (on_update_actions);
        get_view ().selection_group_altered.disconnect (on_update_actions);
        get_view ().items_visibility_changed.disconnect (on_update_actions);
        get_view ().contents_altered.disconnect (on_update_actions);

        are_actions_attached = false;
    }

    private void on_update_actions () {
        if (update_actions_scheduler == null) {
            update_actions_scheduler = new OneShotScheduler (
                "Update actions scheduler for %s".printf (page_name),
                on_update_actions_on_idle);
        }

        update_actions_scheduler.at_priority_idle (Priority.LOW);
    }

    private void on_update_actions_on_idle () {
        if (is_destroyed)
            return;

        update_actions (get_view ().get_selected_count (), get_view ().get_count ());
    }

    // This is called during init_ui () to collect all Gtk.ActionEntries for the page.
    protected virtual Gtk.ActionEntry[] init_collect_action_entries () {
        return new Gtk.ActionEntry[0];
    }

    // This is called during init_ui () to collect all Gtk.ToggleActionEntries for the page
    protected virtual Gtk.ToggleActionEntry[] init_collect_toggle_action_entries () {
        return new Gtk.ToggleActionEntry[0];
    }

    // This is called during init_ui () to collect all Gtk.RadioActionEntries for the page
    protected virtual void register_radio_actions (Gtk.ActionGroup action_group) {
    }

    // This is called during "map" allowing for Gtk.Actions to be updated at
    // initialization time.
    protected virtual void init_actions (int selected_count, int count) {
    }

    // This is called during "map" and during ViewCollection selection, visibility,
    // and collection content altered events.  This can be used to both initialize Gtk.Actions and
    // update them when selection or visibility has been altered.
    protected virtual void update_actions (int selected_count, int count) {
    }

    // Use this function rather than GDK or GTK's get_pointer, especially if called during a
    // button-down mouse drag (i.e. a window grab).
    //
    // For more information, see: https://bugzilla.gnome.org/show_bug.cgi?id=599937
    public bool get_event_source_pointer (out int x, out int y, out Gdk.ModifierType mask) {
        if (event_source == null) {
            x = 0;
            y = 0;
            mask = 0;

            return false;
        }

        var seat = Gdk.Display.get_default ().get_default_seat ();
        event_source.get_window ().get_device_position (seat.get_pointer (), out x, out y, out mask);

        if (last_down.x < 0 || last_down.y < 0)
            return true;

        // check for bogus values inside a drag which goes outside the window
        // caused by (most likely) X windows signed 16-bit int overflow and fixup
        // (https://bugzilla.gnome.org/show_bug.cgi?id=599937)

        if ((x - last_down.x).abs () >= 0x7FFF)
            x += 0xFFFF;

        if ((y - last_down.y).abs () >= 0x7FFF)
            y += 0xFFFF;

        return true;
    }

    protected virtual bool on_left_click (Gdk.EventButton event) {
        return false;
    }

    protected virtual bool on_middle_click (Gdk.EventButton event) {
        return false;
    }

    protected virtual bool on_right_click (Gdk.EventButton event) {
        return false;
    }

    protected virtual bool on_left_released (Gdk.EventButton event) {
        return false;
    }

    protected virtual bool on_middle_released (Gdk.EventButton event) {
        return false;
    }

    protected virtual bool on_right_released (Gdk.EventButton event) {
        return false;
    }

    private bool on_button_pressed_internal (Gdk.EventButton event) {
        switch (event.button) {
        case 1:
            if (event_source != null)
                event_source.grab_focus ();

            // stash location of mouse down for drag fixups
            last_down.x = (int) event.x;
            last_down.y = (int) event.y;

            return on_left_click (event);

        case 2:
            return on_middle_click (event);

        case 3:
            return on_right_click (event);

        default:
            return false;
        }
    }

    private bool on_button_released_internal (Gdk.EventButton event) {
        switch (event.button) {
        case 1:
            // clear when button released, only for drag fixups
            last_down = { -1, -1 };

            return on_left_released (event);

        case 2:
            return on_middle_released (event);

        case 3:
            return on_right_released (event);

        default:
            return false;
        }
    }

    protected virtual bool on_ctrl_pressed (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_ctrl_released (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_alt_pressed (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_alt_released (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_shift_pressed (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_shift_released (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_super_pressed (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_super_released (Gdk.EventKey? event) {
        return false;
    }

    protected virtual bool on_app_key_pressed (Gdk.EventKey event) {
        return false;
    }

    protected virtual bool on_app_key_released (Gdk.EventKey event) {
        return false;
    }

    public bool notify_app_key_pressed (Gdk.EventKey event) {
        bool ctrl_currently_pressed, alt_currently_pressed, shift_currently_pressed,
             super_currently_pressed;
        get_modifiers (out ctrl_currently_pressed, out alt_currently_pressed,
                       out shift_currently_pressed, out super_currently_pressed);

        switch (Gdk.keyval_name (event.keyval)) {
        case "Control_L":
        case "Control_R":
            if (!ctrl_currently_pressed || ctrl_pressed)
                return false;

            ctrl_pressed = true;

            return on_ctrl_pressed (event);

        case "Meta_L":
        case "Meta_R":
        case "Alt_L":
        case "Alt_R":
            if (!alt_currently_pressed || alt_pressed)
                return false;

            alt_pressed = true;

            return on_alt_pressed (event);

        case "Shift_L":
        case "Shift_R":
            if (!shift_currently_pressed || shift_pressed)
                return false;

            shift_pressed = true;

            return on_shift_pressed (event);

        case "Super_L":
        case "Super_R":
            if (!super_currently_pressed || super_pressed)
                return false;

            super_pressed = true;

            return on_super_pressed (event);
        }

        return on_app_key_pressed (event);
    }

    public bool notify_app_key_released (Gdk.EventKey event) {
        bool ctrl_currently_pressed, alt_currently_pressed, shift_currently_pressed,
             super_currently_pressed;
        get_modifiers (out ctrl_currently_pressed, out alt_currently_pressed,
                       out shift_currently_pressed, out super_currently_pressed);

        switch (Gdk.keyval_name (event.keyval)) {
        case "Control_L":
        case "Control_R":
            if (ctrl_currently_pressed || !ctrl_pressed)
                return false;

            ctrl_pressed = false;

            return on_ctrl_released (event);

        case "Meta_L":
        case "Meta_R":
        case "Alt_L":
        case "Alt_R":
            if (alt_currently_pressed || !alt_pressed)
                return false;

            alt_pressed = false;

            return on_alt_released (event);

        case "Shift_L":
        case "Shift_R":
            if (shift_currently_pressed || !shift_pressed)
                return false;

            shift_pressed = false;

            return on_shift_released (event);

        case "Super_L":
        case "Super_R":
            if (super_currently_pressed || !super_pressed)
                return false;

            super_pressed = false;

            return on_super_released (event);
        }

        return on_app_key_released (event);
    }

    public bool notify_app_focus_in (Gdk.EventFocus event) {
        update_modifiers ();

        return false;
    }

    public bool notify_app_focus_out (Gdk.EventFocus event) {
        return false;
    }

    protected virtual void on_move (Gdk.Rectangle rect) {
    }

    protected virtual void on_move_start (Gdk.Rectangle rect) {
    }

    protected virtual void on_move_finished (Gdk.Rectangle rect) {
    }

    protected virtual void on_resize (Gdk.Rectangle rect) {
    }

    protected virtual void on_resize_start (Gdk.Rectangle rect) {
    }

    protected virtual void on_resize_finished (Gdk.Rectangle rect) {
    }

    protected virtual bool on_configure (Gdk.EventConfigure event, Gdk.Rectangle rect) {
        return false;
    }

    public bool notify_configure_event (Gdk.EventConfigure event) {
        Gdk.Rectangle rect = Gdk.Rectangle ();
        rect.x = event.x;
        rect.y = event.y;
        rect.width = event.width;
        rect.height = event.height;

        // special case events, to report when a configure first starts (and appears to end)
        if (last_configure_ms == 0) {
            if (last_position.x != rect.x || last_position.y != rect.y) {
                on_move_start (rect);
                report_move_finished = true;
            }

            if (last_position.width != rect.width || last_position.height != rect.height) {
                on_resize_start (rect);
                report_resize_finished = true;
            }

            // need to check more often then the timeout, otherwise it could be up to twice the
            // wait time before it's noticed
            Timeout.add (CONSIDER_CONFIGURE_HALTED_MSEC / 8, check_configure_halted);
        }

        if (last_position.x != rect.x || last_position.y != rect.y)
            on_move (rect);

        if (last_position.width != rect.width || last_position.height != rect.height)
            on_resize (rect);

        last_position = rect;
        last_configure_ms = now_ms ();

        return on_configure (event, rect);
    }

    private bool check_configure_halted () {
        if (is_destroyed)
            return false;

        if ((now_ms () - last_configure_ms) < CONSIDER_CONFIGURE_HALTED_MSEC)
            return true;

        Gtk.Allocation allocation;
        get_allocation (out allocation);

        if (report_move_finished)
            on_move_finished ((Gdk.Rectangle) allocation);

        if (report_resize_finished)
            on_resize_finished ((Gdk.Rectangle) allocation);

        last_configure_ms = 0;
        report_move_finished = false;
        report_resize_finished = false;

        return false;
    }

    protected virtual bool on_motion (Gdk.EventMotion event, int x, int y, Gdk.ModifierType mask) {
        check_cursor_hiding ();

        return false;
    }

    protected virtual bool on_leave_notify_event () {
        return false;
    }

    private bool on_motion_internal (Gdk.EventMotion event) {
        int x, y;
        Gdk.ModifierType mask;
        if (event.is_hint == 1) {
            get_event_source_pointer (out x, out y, out mask);
        } else {
            x = (int) event.x;
            y = (int) event.y;
            mask = event.state;
        }

        return on_motion (event, x, y, mask);
    }

    private double total_dx = 0.0;
    private double total_dy = 0.0;
    private bool on_mousewheel_internal (Gdk.EventScroll event) {
        switch (event.direction) {
        case Gdk.ScrollDirection.UP:
            return on_mousewheel_up (event);

        case Gdk.ScrollDirection.DOWN:
            return on_mousewheel_down (event);

        case Gdk.ScrollDirection.LEFT:
            return on_mousewheel_left (event);

        case Gdk.ScrollDirection.RIGHT:
            return on_mousewheel_right (event);

        case Gdk.ScrollDirection.SMOOTH:
            double dx, dy;
            bool vertical = false;
            bool horizontal = false;
            if (event.get_scroll_deltas (out dx, out dy)) {
                total_dx += dx;
                total_dy += dy;
                if (total_dx.abs () > 0.05) {
                    horizontal = total_dx > 0 ? on_mousewheel_right (event) : on_mousewheel_left (event);
                    total_dx = 0.0;
                }
                if (total_dy.abs () > 0.05) {
                    vertical = total_dy > 0 ? on_mousewheel_down (event) : on_mousewheel_up (event);
                    total_dy = 0.0;
                }

                return horizontal || vertical;
            }

            return false;
        default:
            return false;
        }
    }

    protected virtual bool on_mousewheel_up (Gdk.EventScroll event) {
        return false;
    }

    protected virtual bool on_mousewheel_down (Gdk.EventScroll event) {
        return false;
    }

    protected virtual bool on_mousewheel_left (Gdk.EventScroll event) {
        return false;
    }

    protected virtual bool on_mousewheel_right (Gdk.EventScroll event) {
        return false;
    }

    protected virtual bool on_context_keypress () {
        return false;
    }

    protected virtual bool on_context_buttonpress (Gdk.EventButton event) {
        return false;
    }

    protected virtual bool on_context_invoked () {
        return true;
    }

    protected bool popup_context_menu (Gtk.Menu? context_menu,
                                       Gdk.EventButton? event = null) {

        if (context_menu == null || !on_context_invoked ())
            return false;

        if (event == null) {
            context_menu.popup (null, null, null, 0, Gtk.get_current_event_time ());
        } else {
            context_menu.popup (null, null, null, event.button, event.time);
        }

        return true;
    }

    private void on_event_source_realize () {
        assert (event_source.get_window () != null); // the realize event means the Widget has a window

        if (event_source.get_window ().get_cursor () != null) {
            last_cursor = event_source.get_window ().get_cursor ().get_cursor_type ();
            return;
        }

        // no custom cursor defined, check parents
        Gdk.Window? parent_window = event_source.get_window ();
        do {
            parent_window = parent_window.get_parent ();
        } while (parent_window != null && parent_window.get_cursor () == null);

        if (parent_window != null)
            last_cursor = parent_window.get_cursor ().get_cursor_type ();
    }

    public void set_cursor_hide_time (int hide_time) {
        cursor_hide_msec = hide_time;
    }

    public void start_cursor_hiding () {
        check_cursor_hiding ();
    }

    public void stop_cursor_hiding () {
        if (last_timeout_id != 0) {
            Source.remove (last_timeout_id);
            last_timeout_id = 0;
        }
    }

    public void suspend_cursor_hiding () {
        cursor_hide_time_cached = cursor_hide_msec;

        if (last_timeout_id != 0) {
            Source.remove (last_timeout_id);
            last_timeout_id = 0;
        }

        cursor_hide_msec = 0;
    }

    public void restore_cursor_hiding () {
        cursor_hide_msec = cursor_hide_time_cached;
        check_cursor_hiding ();
    }

    // Use this method to set the cursor for a page, NOT window.set_cursor(...)
    protected virtual void set_page_cursor (Gdk.CursorType cursor_type) {
        last_cursor = cursor_type;

        if (!cursor_hidden && event_source != null)
            event_source.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), cursor_type));
    }

    private void check_cursor_hiding () {
        if (cursor_hidden) {
            cursor_hidden = false;
            set_page_cursor (last_cursor);
        }

        if (cursor_hide_msec != 0) {
            if (last_timeout_id != 0)
                Source.remove (last_timeout_id);
            last_timeout_id = Timeout.add (cursor_hide_msec, on_hide_cursor);
        }
    }

    private bool on_hide_cursor () {
        cursor_hidden = true;

        if (event_source != null)
            event_source.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.BLANK_CURSOR));

        last_timeout_id = 0;
        return false;
    }
}
