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

    protected Gtk.Toolbar toolbar;
    protected bool in_view = false;
    protected Gtk.ToolButton show_sidebar_button;

    private string page_name;
    private ViewCollection view = null;
    private Gtk.Window container = null;
    private Gdk.Rectangle last_position = Gdk.Rectangle ();
    private Gtk.Widget event_source = null;
    private bool dnd_enabled = false;
    private ulong last_configure_ms = 0;
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

    protected Page (string page_name) {
        this.page_name = page_name;

        view = new ViewCollection ("ViewCollection for Page %s".printf (page_name));

        last_down = { -1, -1 };

        set_can_focus (true);

        popup_menu.connect (on_context_keypress);

        init_ui ();

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

        debug ("Page %s Destroyed", get_page_name ());
    }

    public string get_page_name () {
        return page_name;
    }

    public virtual void set_page_name (string page_name) {
        this.page_name = page_name;
    }

    public string to_string () {
        return page_name;
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

        disable_drag_source ();

        event_source = null;
    }

    public Gtk.Widget? get_event_source () {
        return event_source;
    }

    public virtual Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            toolbar = new Gtk.Toolbar ();
            toolbar.get_style_context ().add_class ("bottom-toolbar"); // for elementary theme
            toolbar.set_style (Gtk.ToolbarStyle.ICONS);
        }
        return toolbar;
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

    public bool is_in_view () {
        return in_view;
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
            warning ("Page %s: Unable to locate action %s", get_page_name (), name);

        return action;
    }

    public void set_action_sensitive (string name, bool sensitive) {
        Gtk.Action? action = get_action (name);
        if (action != null)
            action.sensitive = sensitive;
    }

    public void set_action_important (string name, bool important) {
        Gtk.Action? action = get_action (name);
        if (action != null)
            action.is_important = important;
    }

    public void set_action_visible (string name, bool visible) {
        Gtk.Action? action = get_action (name);
        if (action == null)
            return;

        action.visible = visible;
        action.sensitive = visible;
    }

    public void set_action_short_label (string name, string short_label) {
        Gtk.Action? action = get_action (name);
        if (action != null)
            action.short_label = short_label;
    }

    public void set_action_details (string name, string? label, string? tooltip, bool sensitive) {
        Gtk.Action? action = get_action (name);
        if (action == null)
            return;

        if (label != null)
            action.label = label;

        if (tooltip != null)
            action.tooltip = tooltip;

        action.sensitive = sensitive;
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
            warning ("Page %s: Unable to locate common action %s", get_page_name (), name);

        return null;
    }

    public void update_sidebar_action (bool show) {
        if (show_sidebar_button == null)
            return;
        if (!show) {
            show_sidebar_button.set_icon_name (Resources.HIDE_PANE);
            show_sidebar_button.set_label (Resources.UNTOGGLE_METAPANE_LABEL);
            show_sidebar_button.set_tooltip_text (Resources.UNTOGGLE_METAPANE_TOOLTIP);
        } else {
            show_sidebar_button.set_icon_name (Resources.SHOW_PANE);
            show_sidebar_button.set_label (Resources.TOGGLE_METAPANE_LABEL);
            show_sidebar_button.set_tooltip_text (Resources.TOGGLE_METAPANE_TOOLTIP);
        }
        var app = AppWindow.get_instance () as LibraryWindow;
        app.update_common_toggle_actions ();
    }

    public void set_common_action_sensitive (string name, bool sensitive) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.sensitive = sensitive;
    }

    public void set_common_action_label (string name, string label) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.set_label (label);
    }

    public void set_common_action_important (string name, bool important) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.is_important = important;
    }

    public void activate_common_action (string name) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.activate ();
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
        AppWindow.get_instance ().get_window ().get_device_position (Gdk.Display.get_default ().
                get_device_manager ().get_client_pointer (), out x, out y, out mask);

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

    public PageWindow? get_page_window () {
        Gtk.Widget p = parent;
        while (p != null) {
            if (p is PageWindow)
                return (PageWindow) p;

            p = p.parent;
        }

        return null;
    }

    public CommandManager get_command_manager () {
        return AppWindow.get_command_manager ();
    }

    private void init_ui () {
        action_group = new Gtk.ActionGroup ("PageActionGroup");

        // Collect all Gtk.Actions and add them to the Page's Gtk.ActionGroup
        Gtk.ActionEntry[] action_entries = init_collect_action_entries ();
        if (action_entries.length > 0)
            action_group.add_actions (action_entries, this);

        // Collect all Gtk.ToggleActionEntries and add them to the Gtk.ActionGroup
        Gtk.ToggleActionEntry[] toggle_entries = init_collect_toggle_action_entries ();
        if (toggle_entries.length > 0)
            action_group.add_toggle_actions (toggle_entries, this);

        // Collect all Gtk.RadioActionEntries and add them to the Gtk.ActionGroup
        // (Would use a similar collection scheme as the other calls, but there is a binding
        // problem with Gtk.RadioActionCallback that doesn't allow it to be stored in a struct)
        register_radio_actions (action_group);

        // Get global (common) action groups from the application window
        common_action_groups = AppWindow.get_instance ().get_common_action_groups ();
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
                "Update actions scheduler for %s".printf (get_page_name ()),
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

    // This method enables drag-and-drop on the event source and routes its events through this
    // object
    public void enable_drag_source (Gdk.DragAction actions, Gtk.TargetEntry[] source_target_entries) {
        if (dnd_enabled)
            return;

        assert (event_source != null);

        Gtk.drag_source_set (event_source, Gdk.ModifierType.BUTTON1_MASK, source_target_entries, actions);

        // hook up handlers which route the event_source's DnD signals to the Page's (necessary
        // because Page is a NO_WINDOW widget and cannot support DnD on its own).
        event_source.drag_begin.connect (on_drag_begin);
        event_source.drag_data_get.connect (on_drag_data_get);
        event_source.drag_data_delete.connect (on_drag_data_delete);
        event_source.drag_end.connect (on_drag_end);
        event_source.drag_failed.connect (on_drag_failed);

        dnd_enabled = true;
    }

    public void disable_drag_source () {
        if (!dnd_enabled)
            return;

        assert (event_source != null);

        event_source.drag_begin.disconnect (on_drag_begin);
        event_source.drag_data_get.disconnect (on_drag_data_get);
        event_source.drag_data_delete.disconnect (on_drag_data_delete);
        event_source.drag_end.disconnect (on_drag_end);
        event_source.drag_failed.disconnect (on_drag_failed);
        Gtk.drag_source_unset (event_source);

        dnd_enabled = false;
    }

    public bool is_dnd_enabled () {
        return dnd_enabled;
    }

    private void on_drag_begin (Gdk.DragContext context) {
        drag_begin (context);
    }

    private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data,
                                   uint info, uint time) {
        drag_data_get (context, selection_data, info, time);
    }

    private void on_drag_data_delete (Gdk.DragContext context) {
        drag_data_delete (context);
    }

    private void on_drag_end (Gdk.DragContext context) {
        drag_end (context);
    }

    // wierdly, Gtk 2.16.1 doesn't supply a drag_failed virtual method in the GtkWidget impl ...
    // Vala binds to it, but it's not available in gtkwidget.h, and so gcc complains.  Have to
    // makeshift one for now.
    // https://bugzilla.gnome.org/show_bug.cgi?id=584247
    public virtual bool source_drag_failed (Gdk.DragContext context, Gtk.DragResult drag_result) {
        return false;
    }

    private bool on_drag_failed (Gdk.DragContext context, Gtk.DragResult drag_result) {
        return source_drag_failed (context, drag_result);
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

        event_source.get_window ().get_device_position (Gdk.Display.get_default ().get_device_manager ()
                .get_client_pointer (), out x, out y, out mask);

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
                if (dx != 0) {
                    horizontal = dx > 0 ? on_mousewheel_right (event) : on_mousewheel_left (event);
                }
                if (dy != 0) {
                    vertical = dy > 0 ? on_mousewheel_down (event) : on_mousewheel_up (event);
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

        if (event == null)
            context_menu.popup (null, null, null, 0, Gtk.get_current_event_time ());
        else
            context_menu.popup (null, null, null, event.button, event.time);

        return true;
    }

    protected void on_event_source_realize () {
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

public abstract class CheckerboardPage : Page {
    private const int AUTOSCROLL_PIXELS = 50;
    private const int AUTOSCROLL_TICKS_MSEC = 50;

    private CheckerboardLayout layout;
    private string page_sidebar_menu_path = null;
    private Gtk.Viewport viewport = new Gtk.Viewport (null, null);
    protected CheckerboardItem anchor = null;
    protected CheckerboardItem cursor = null;
    private CheckerboardItem highlighted = null;
    private bool autoscroll_scheduled = false;
    private bool selection_button_clicked = false;
    private CheckerboardItem activated_item = null;
    private Gee.ArrayList<CheckerboardItem> previously_selected = null;

    public enum Activator {
        KEYBOARD,
        MOUSE
    }

    public struct KeyboardModifiers {
        public KeyboardModifiers (Page page) {
            ctrl_pressed = page.get_ctrl_pressed ();
            alt_pressed = page.get_alt_pressed ();
            shift_pressed = page.get_shift_pressed ();
            super_pressed = page.get_super_pressed ();
        }

        public bool ctrl_pressed;
        public bool alt_pressed;
        public bool shift_pressed;
        public bool super_pressed;
    }

    public CheckerboardPage (string page_name) {
        base (page_name);

        layout = new CheckerboardLayout (get_view ());
        layout.set_name (page_name);

        set_event_source (layout);

        viewport.add (layout);

        // want to set_adjustments before adding to ScrolledWindow to let our signal handlers
        // run first ... otherwise, the thumbnails draw late
        layout.set_adjustments (get_hadjustment (), get_vadjustment ());

        add (viewport);

        // need to monitor items going hidden when dealing with anchor/cursor/highlighted items
        get_view ().items_hidden.connect (on_items_hidden);
        get_view ().contents_altered.connect (on_contents_altered);
        get_view ().items_state_changed.connect (on_items_state_changed);
        get_view ().items_visibility_changed.connect (on_items_visibility_changed);

        // scrollbar policy
        set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
    }

    // Returns the name for the back button that goes to this page
    public virtual string get_back_name () {
        return get_page_name ();
    }

    public void init_page_sidebar_menu (string path) {
        page_sidebar_menu_path = path;
    }

    public Gtk.Menu? get_context_menu () {
        // show page context menu if nothing is selected
        return (get_view ().get_selected_count () != 0) ? get_item_context_menu () :
               get_page_context_menu ();
    }

    public virtual Gtk.Menu? get_item_context_menu () {
        return null;
    }

    protected override bool on_context_keypress () {
        return popup_context_menu (get_context_menu ());
    }

    protected virtual string get_view_empty_message () {
        return _ ("No photos/videos");
    }

    protected virtual string get_filter_no_match_message () {
        return _ ("No photos/videos found");
    }

    protected virtual void on_item_activated (CheckerboardItem item) {
    }

    public CheckerboardLayout get_checkerboard_layout () {
        return layout;
    }

    // Gets the search view filter for this page.
    public abstract SearchViewFilter get_search_view_filter ();

    public virtual Core.ViewTracker? get_view_tracker () {
        return null;
    }

    public override void switching_from () {
        layout.set_in_view (false);
        get_search_view_filter ().refresh.disconnect (on_view_filter_refresh);

        // unselect everything so selection won't persist after page loses focus
        get_view ().unselect_all ();
        base.switching_from ();
    }

    public override void switched_to () {
        layout.set_in_view (true);
        get_search_view_filter ().refresh.connect (on_view_filter_refresh);
        on_view_filter_refresh ();

        if (get_view ().get_selected_count () > 0) {
            CheckerboardItem? item = (CheckerboardItem? ) get_view ().get_selected_at (0);

            // if item is in any way out of view, scroll to it
            Gtk.Adjustment vadj = get_vadjustment ();
            if (! (get_adjustment_relation (vadj, item.allocation.y) == AdjustmentRelation.IN_RANGE
                    && (get_adjustment_relation (vadj, item.allocation.y + item.allocation.height) == AdjustmentRelation.IN_RANGE))) {

                // scroll to see the new item
                int top = 0;
                if (item.allocation.y < vadj.get_value ()) {
                    top = item.allocation.y;
                    top -= CheckerboardLayout.ROW_GUTTER_PADDING / 2;
                } else {
                    top = item.allocation.y + item.allocation.height - (int) vadj.get_page_size ();
                    top += CheckerboardLayout.ROW_GUTTER_PADDING / 2;
                }

                vadj.set_value (top);

            }
        }
        base.switched_to ();
    }

    private void on_view_filter_refresh () {
        update_view_filter_message ();
    }

    private void on_contents_altered (Gee.Iterable<DataObject>? added,
                                      Gee.Iterable<DataObject>? removed) {
        update_view_filter_message ();
    }

    private void on_items_state_changed (Gee.Iterable<DataView> changed) {
        update_view_filter_message ();
    }

    private void on_items_visibility_changed (Gee.Collection<DataView> changed) {
        update_view_filter_message ();
    }

    private void update_view_filter_message () {
        var window = AppWindow.get_instance () as LibraryWindow;
        warn_if_fail (window != null);
        if (window != null)
            window.toggle_welcome_page (false);

        if (get_view ().are_items_filtered_out () && get_view ().get_count () == 0) {
            set_page_message (get_filter_no_match_message ());
        } else if (get_view ().get_count () == 0) {
            set_page_message (get_view_empty_message ());
        } else {
            unset_page_message ();
        }
    }

    public void set_page_message (string message) {
        layout.set_message (message);
        if (is_in_view ())
            layout.queue_draw ();
    }

    public void unset_page_message () {
        layout.unset_message ();
        if (is_in_view ())
            layout.queue_draw ();
    }

    public override void set_page_name (string name) {
        base.set_page_name (name);

        layout.set_name (name);
    }

    public CheckerboardItem? get_item_at_pixel (double x, double y) {
        return layout.get_item_at_pixel (x, y);
    }

    private void on_items_hidden (Gee.Iterable<DataView> hidden) {
        foreach (DataView view in hidden) {
            CheckerboardItem item = (CheckerboardItem) view;

            if (anchor == item)
                anchor = null;

            if (cursor == item)
                cursor = null;

            if (highlighted == item)
                highlighted = null;
        }
    }

    protected override bool key_press_event (Gdk.EventKey event) {
        bool handled = true;

        // mask out the modifiers we're interested in
        uint state = event.state & Gdk.ModifierType.SHIFT_MASK;

        switch (Gdk.keyval_name (event.keyval)) {
        case "Up":
        case "KP_Up":
            move_cursor (CompassPoint.NORTH);
            select_anchor_to_cursor (state);
            break;

        case "Down":
        case "KP_Down":
            move_cursor (CompassPoint.SOUTH);
            select_anchor_to_cursor (state);
            break;

        case "Left":
        case "KP_Left":
            move_cursor (CompassPoint.WEST);
            select_anchor_to_cursor (state);
            break;

        case "Right":
        case "KP_Right":
            move_cursor (CompassPoint.EAST);
            select_anchor_to_cursor (state);
            break;

        case "Home":
        case "KP_Home":
            CheckerboardItem? first = (CheckerboardItem? ) get_view ().get_first ();
            if (first != null)
                cursor_to_item (first);
            select_anchor_to_cursor (state);
            break;

        case "End":
        case "KP_End":
            CheckerboardItem? last = (CheckerboardItem? ) get_view ().get_last ();
            if (last != null)
                cursor_to_item (last);
            select_anchor_to_cursor (state);
            break;

        case "Return":
        case "KP_Enter":
            if (get_view ().get_selected_count () == 1)
                on_item_activated ((CheckerboardItem) get_view ().get_selected_at (0));
            else
                handled = false;
            break;

        default:
            handled = false;
            break;
        }

        if (handled)
            return true;

        return (base.key_press_event != null) ? base.key_press_event (event) : true;
    }

    protected virtual bool is_point_on_item_selection_button (double x, double y, CheckerboardItem item) {
        Gdk.Rectangle button_area = item.get_selection_button_area ();

        // The point does not have to be exactly over button area
        const int x_error_margin = 3;
        const int y_error_margin = 3;
        
        return x >= button_area.x - x_error_margin
            && x <= button_area.x + button_area.width + x_error_margin
            && y >= button_area.y - y_error_margin
            && y <= button_area.y + button_area.height + y_error_margin;
    }
    
    protected override bool on_left_click (Gdk.EventButton event) {
        selection_button_clicked = false;

        // only interested in single-click and double-clicks for now
        if ((event.type != Gdk.EventType.BUTTON_PRESS) && (event.type != Gdk.EventType.2BUTTON_PRESS))
            return false;

        // mask out the modifiers we're interested in
        uint state = event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK);

        // use clicks for multiple selection and activation only; single selects are handled by
        // button release, to allow for multiple items to be selected then dragged
        CheckerboardItem item = get_item_at_pixel (event.x, event.y);
        
        if (item != null) {
            switch (state) {
            case Gdk.ModifierType.CONTROL_MASK:
                // with only Ctrl pressed, multiple selections are possible ... chosen item
                // is toggled
                Marker marker = get_view ().mark (item);
                get_view ().toggle_marked (marker);

                if (item.is_selected ()) {
                    anchor = item;
                    cursor = item;
                }
                break;

            case Gdk.ModifierType.SHIFT_MASK:
                get_view ().unselect_all ();

                if (anchor == null)
                    anchor = item;

                select_between_items (anchor, item);

                cursor = item;
                break;

            case Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK:
                // Ticket #853 - Make Ctrl + Shift + Mouse Button 1 able to start a new run
                // of contiguous selected items without unselecting previously-selected items
                // a la Nautilus.
                // Same as the case for SHIFT_MASK, but don't unselect anything first.
                if (anchor == null)
                    anchor = item;

                select_between_items (anchor, item);

                cursor = item;
                break;

            default:
                // check if user clicked a blank area of the item or the selection button
                if (is_point_on_item_selection_button (event.x, event.y, item)) {
                    
                    debug ("Selection button clicked");

                    // make sure we handle this kind of selection properly on button-release
                    selection_button_clicked = true;

                    // when selection button is clicked, multiple selections are possible ...
                    // chosen item is toggled
                    Marker marker = get_view ().mark (item);
                    get_view ().toggle_marked (marker);

                    if (item.is_selected ()) {
                        anchor = item;
                        cursor = item;
                    }
                } else {
                    activated_item = item;

                    anchor = item;
                    cursor = item;
                }
                break;
            }
        } else {
            // user clicked on "dead" area; only unselect if control is not pressed
            // do we want similar behavior for shift as well?
            if (state != Gdk.ModifierType.CONTROL_MASK)
                get_view ().unselect_all ();

            // grab previously marked items
            previously_selected = new Gee.ArrayList<CheckerboardItem> ();
            foreach (DataView view in get_view ().get_selected ())
                previously_selected.add ((CheckerboardItem) view);

            layout.set_drag_select_origin ((int) event.x, (int) event.y);

            return true;
        }

        // need to determine if the signal should be passed to the DnD handlers
        // Return true to block the DnD handler, false otherwise

        return get_view ().get_selected_count () == 0;
    }

    protected override bool on_left_released (Gdk.EventButton event) {
        previously_selected = null;

        // if drag-selecting, stop here and do nothing else
        if (layout.is_drag_select_active ()) {
            layout.clear_drag_select ();
            anchor = cursor;

            return true;
        }

        // only interested in non-modified button releases
        if ((event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) != 0)
            return false;

        // if the item was activated in the double-click, report it now
        if (activated_item != null) {
            on_item_activated (activated_item);
            activated_item = null;

            return true;
        }

        CheckerboardItem item = get_item_at_pixel (event.x, event.y);
        if (item == null) {
            // released button on "dead" area
            return true;
        }

        if (selection_button_clicked) {
            selection_button_clicked = false;
            return true;
        }

        if (cursor != item) {
            // user released mouse button after moving it off the initial item, or moved from dead
            // space onto one.  either way, unselect everything
            get_view ().unselect_all ();
        } else {
            // the idea is, if a user single-clicks on an item with no modifiers, then all other items
            // should be deselected, however, if they single-click in order to drag one or more items,
            // they should remain selected, hence performing this here rather than on_left_click
            // (item may not be selected if an unimplemented modifier key was used)
            if (item.is_selected ())
                get_view ().unselect_all_but (item);
        }

        return true;
    }

    protected override bool on_right_click (Gdk.EventButton event) {
        // only interested in single-clicks for now
        if (event.type != Gdk.EventType.BUTTON_PRESS)
            return false;

        // get what's right-clicked upon
        CheckerboardItem item = get_item_at_pixel (event.x, event.y);
        if (item != null) {
            // mask out the modifiers we're interested in
            switch (event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) {
            case Gdk.ModifierType.CONTROL_MASK:
                // chosen item is toggled
                Marker marker = get_view ().mark (item);
                get_view ().toggle_marked (marker);
                break;

            case Gdk.ModifierType.SHIFT_MASK:
                // TODO
                break;

            case Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK:
                // TODO
                break;

            default:
                // if the item is already selected, proceed; if item is not selected, a bare right
                // click unselects everything else but it
                if (!item.is_selected ()) {
                    Marker all = get_view ().start_marking ();
                    all.mark_many (get_view ().get_selected ());

                    get_view ().unselect_and_select_marked (all, get_view ().mark (item));
                }
                break;
            }
        } else {
            // clicked in "dead" space, unselect everything
            get_view ().unselect_all ();
        }

        Gtk.Menu context_menu = get_context_menu ();
        return popup_context_menu (context_menu, event);
    }

    protected virtual bool on_mouse_over (CheckerboardItem? item, int x, int y, Gdk.ModifierType mask) {
        // if hovering over the last hovered item, or both are null (nothing highlighted and
        // hovering over empty space), do nothing
        if (item != highlighted) {
            // either something new is highlighted or now hovering over empty space, so dim old item
            if (highlighted != null) {
                highlighted.unbrighten ();
                highlighted = null;
            }

            // if over empty space, done
            if (item != null) {
                // brighten the new item otherwise
                item.brighten ();
                highlighted = item;
            }
        }
        
        // use "hand" cursor only to indicate that an item is ready for activation
        Gdk.CursorType cursor_type = item != null && !is_point_on_item_selection_button (x, y, item)
            ? Gdk.CursorType.HAND1 : Gdk.CursorType.ARROW;
        set_page_cursor (cursor_type);
        
        return true;
    }

    protected override bool on_motion (Gdk.EventMotion event, int x, int y, Gdk.ModifierType mask) {
        // report what item the mouse is hovering over
        if (!on_mouse_over (get_item_at_pixel (x, y), x, y, mask))
            return false;

        // go no further if not drag-selecting
        if (!layout.is_drag_select_active ())
            return false;

        // set the new endpoint of the drag selection
        layout.set_drag_select_endpoint (x, y);

        updated_selection_band ();

        // if out of bounds, schedule a check to auto-scroll the viewport
        if (!autoscroll_scheduled
                && get_adjustment_relation (get_vadjustment (), y) != AdjustmentRelation.IN_RANGE) {
            Timeout.add (AUTOSCROLL_TICKS_MSEC, selection_autoscroll);
            autoscroll_scheduled = true;
        }

        // return true to stop a potential drag-and-drop operation
        return true;
    }

    private void updated_selection_band () {
        assert (layout.is_drag_select_active ());

        // get all items inside the selection
        Gee.List<CheckerboardItem>? intersection = layout.items_in_selection_band ();
        if (intersection == null)
            return;

        Marker to_unselect = get_view ().start_marking ();
        Marker to_select = get_view ().start_marking ();

        // mark all selected items to be unselected
        to_unselect.mark_many (get_view ().get_selected ());

        // except for the items that were selected before the drag began
        assert (previously_selected != null);
        to_unselect.unmark_many (previously_selected);
        to_select.mark_many (previously_selected);

        // toggle selection on everything in the intersection and update the cursor
        cursor = null;

        foreach (CheckerboardItem item in intersection) {
            if (to_select.toggle (item))
                to_unselect.unmark (item);
            else
                to_unselect.mark (item);

            if (cursor == null)
                cursor = item;
        }

        get_view ().select_marked (to_select);
        get_view ().unselect_marked (to_unselect);
    }

    private bool selection_autoscroll () {
        if (!layout.is_drag_select_active ()) {
            autoscroll_scheduled = false;

            return false;
        }

        // as the viewport never scrolls horizontally, only interested in vertical
        Gtk.Adjustment vadj = get_vadjustment ();

        int x, y;
        Gdk.ModifierType mask;
        get_event_source_pointer (out x, out y, out mask);

        int new_value = (int) vadj.get_value ();
        switch (get_adjustment_relation (vadj, y)) {
        case AdjustmentRelation.BELOW:
            // pointer above window, scroll up
            new_value -= AUTOSCROLL_PIXELS;
            layout.set_drag_select_endpoint (x, new_value);
            break;

        case AdjustmentRelation.ABOVE:
            // pointer below window, scroll down, extend selection to bottom of page
            new_value += AUTOSCROLL_PIXELS;
            layout.set_drag_select_endpoint (x, new_value + (int) vadj.get_page_size ());
            break;

        case AdjustmentRelation.IN_RANGE:
            autoscroll_scheduled = false;

            return false;

        default:
            warn_if_reached ();
            break;
        }

        // It appears that in GTK+ 2.18, the adjustment is not clamped the way it was in 2.16.
        // This may have to do with how adjustments are different w/ scrollbars, that they're upper
        // clamp is upper - page_size ... either way, enforce these limits here
        vadj.set_value (new_value.clamp ((int) vadj.get_lower (),
                                         (int) vadj.get_upper () - (int) vadj.get_page_size ()));

        updated_selection_band ();

        return true;
    }

    public void cursor_to_item (CheckerboardItem item) {
        assert (get_view ().contains (item));

        cursor = item;

        get_view ().unselect_all ();

        Marker marker = get_view ().mark (item);
        get_view ().select_marked (marker);

        // if item is in any way out of view, scroll to it
        Gtk.Adjustment vadj = get_vadjustment ();
        if (get_adjustment_relation (vadj, item.allocation.y) == AdjustmentRelation.IN_RANGE
                && (get_adjustment_relation (vadj, item.allocation.y + item.allocation.height) == AdjustmentRelation.IN_RANGE))
            return;

        // scroll to see the new item
        int top = 0;
        if (item.allocation.y < vadj.get_value ()) {
            top = item.allocation.y;
            top -= CheckerboardLayout.ROW_GUTTER_PADDING / 2;
        } else {
            top = item.allocation.y + item.allocation.height - (int) vadj.get_page_size ();
            top += CheckerboardLayout.ROW_GUTTER_PADDING / 2;
        }

        vadj.set_value (top);
    }

    public void move_cursor (CompassPoint point) {
        // if no items, nothing to do
        if (get_view ().get_count () == 0)
            return;

        // if nothing is selected, simply select the first and exit
        if (get_view ().get_selected_count () == 0 || cursor == null) {
            CheckerboardItem item = layout.get_item_at_coordinate (0, 0);
            cursor_to_item (item);
            anchor = item;

            return;
        }

        // move the cursor relative to the "first" item
        CheckerboardItem? item = layout.get_item_relative_to (cursor, point);
        if (item != null)
            cursor_to_item (item);
    }

    public void set_cursor (CheckerboardItem item) {
        Marker marker = get_view ().mark (item);
        get_view ().select_marked (marker);

        cursor = item;
        anchor = item;
    }

    public void select_between_items (CheckerboardItem item_start, CheckerboardItem item_end) {
        Marker marker = get_view ().start_marking ();

        bool passed_start = false;
        bool passed_end = false;

        foreach (DataObject object in get_view ().get_all ()) {
            CheckerboardItem item = (CheckerboardItem) object;

            if (item_start == item)
                passed_start = true;

            if (item_end == item)
                passed_end = true;

            if (passed_start || passed_end)
                marker.mark ((DataView) object);

            if (passed_start && passed_end)
                break;
        }

        get_view ().select_marked (marker);
    }

    public void select_anchor_to_cursor (uint state) {
        if (cursor == null || anchor == null)
            return;

        if (state == Gdk.ModifierType.SHIFT_MASK) {
            get_view ().unselect_all ();
            select_between_items (anchor, cursor);
        } else {
            anchor = cursor;
        }
    }

    protected virtual void set_display_titles (bool display) {
        get_view ().freeze_notifications ();
        get_view ().set_property (CheckerboardItem.PROP_SHOW_TITLES, display);
        get_view ().thaw_notifications ();
    }

    protected virtual void set_display_comments (bool display) {
        get_view ().freeze_notifications ();
        get_view ().set_property (CheckerboardItem.PROP_SHOW_COMMENTS, display);
        get_view ().thaw_notifications ();
    }
}

public abstract class SinglePhotoPage : Page {
    public const Gdk.InterpType FAST_INTERP = Gdk.InterpType.NEAREST;
    public const Gdk.InterpType QUALITY_INTERP = Gdk.InterpType.BILINEAR;
    public const int KEY_REPEAT_INTERVAL_MSEC = 200;

    public enum UpdateReason {
        NEW_PIXBUF,
        QUALITY_IMPROVEMENT,
        RESIZED_CANVAS
    }

    protected Gtk.DrawingArea canvas = new Gtk.DrawingArea ();
    protected Gtk.Viewport viewport = new Gtk.Viewport (null, null);

    private bool scale_up_to_viewport;
    private TransitionClock transition_clock;
    private int transition_duration_msec = 0;
    private Cairo.Surface pixmap = null;
    private Cairo.Context pixmap_ctx = null;
    private Cairo.Context text_ctx = null;
    private Dimensions pixmap_dim = Dimensions ();
    private Gdk.Pixbuf unscaled = null;
    private Dimensions max_dim = Dimensions ();
    private Gdk.Pixbuf scaled = null;
    private Gdk.Pixbuf old_scaled = null; // previous scaled image
    private Gdk.Rectangle scaled_pos = Gdk.Rectangle ();
    private ZoomState static_zoom_state;
    private bool zoom_high_quality = true;
    private ZoomState saved_zoom_state;
    private bool has_saved_zoom_state = false;
    private uint32 last_nav_key = 0;

    public SinglePhotoPage (string page_name, bool scale_up_to_viewport) {
        base (page_name);

        this.scale_up_to_viewport = scale_up_to_viewport;

        transition_clock = TransitionEffectsManager.get_instance ().create_null_transition_clock ();

        // With the current code automatically resizing the image to the viewport, scrollbars
        // should never be shown, but this may change if/when zooming is supported
        set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

        canvas.get_style_context ().add_class ("checkerboard-layout");

        viewport.add (canvas);

        add (viewport);

        // We used to disable GTK double buffering here.  We've had to reenable it
        // due to this bug: http://redmine.yorba.org/issues/4775 .
        //
        // all painting happens in pixmap, and is sent to the window wholesale in on_canvas_expose
        // canvas.set_double_buffered(false);

        canvas.add_events (Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.STRUCTURE_MASK
                           | Gdk.EventMask.SUBSTRUCTURE_MASK);

        viewport.size_allocate.connect (on_viewport_resize);
        canvas.draw.connect (on_canvas_exposed);

        set_event_source (canvas);
    }

    public bool is_transition_in_progress () {
        return transition_clock.is_in_progress ();
    }

    public void cancel_transition () {
        if (transition_clock.is_in_progress ())
            transition_clock.cancel ();
    }

    public void set_transition (string effect_id, int duration_msec) {
        cancel_transition ();

        transition_clock = TransitionEffectsManager.get_instance ().create_transition_clock (effect_id);
        if (transition_clock == null)
            transition_clock = TransitionEffectsManager.get_instance ().create_null_transition_clock ();

        transition_duration_msec = duration_msec;
    }

    // This method includes a call to pixmap_ctx.paint ().
    private void render_zoomed_to_pixmap (ZoomState zoom_state) {
        assert (is_zoom_supported ());

        Gdk.Rectangle view_rect = zoom_state.get_viewing_rectangle_wrt_content ();

        Gdk.Pixbuf zoomed;
        if (get_zoom_buffer () != null) {
            zoomed = (zoom_high_quality) ? get_zoom_buffer ().get_zoomed_image (zoom_state) :
                     get_zoom_buffer ().get_zoom_preview_image (zoom_state);
        } else {
            Gdk.Rectangle view_rect_proj = zoom_state.get_viewing_rectangle_projection (unscaled);

            Gdk.Pixbuf proj_subpixbuf = new Gdk.Pixbuf.subpixbuf (unscaled, view_rect_proj.x,
                    view_rect_proj.y, view_rect_proj.width, view_rect_proj.height);

            zoomed = proj_subpixbuf.scale_simple (view_rect.width, view_rect.height,
                                                  Gdk.InterpType.BILINEAR);
        }

        if (zoomed == null) {
            return;
        }

        int draw_x = (pixmap_dim.width - view_rect.width) / 2;
        draw_x = draw_x.clamp (0, int.MAX);

        int draw_y = (pixmap_dim.height - view_rect.height) / 2;
        draw_y = draw_y.clamp (0, int.MAX);

        Gdk.cairo_set_source_pixbuf (pixmap_ctx, zoomed, draw_x, draw_y);
        pixmap_ctx.paint ();
    }

    protected void on_interactive_zoom (ZoomState interactive_zoom_state) {
        assert (is_zoom_supported ());
        Cairo.Context canvas_ctx = Gdk.cairo_create (canvas.get_window ());

        canvas.get_style_context ().render_background (pixmap_ctx, 0, 0, pixmap_dim.width, pixmap_dim.height);

        bool old_quality_setting = zoom_high_quality;
        zoom_high_quality = false;
        render_zoomed_to_pixmap (interactive_zoom_state);
        zoom_high_quality = old_quality_setting;

        canvas_ctx.set_source_surface (pixmap, 0, 0);
        canvas_ctx.paint ();
    }

    protected void on_interactive_pan (ZoomState interactive_zoom_state) {
        assert (is_zoom_supported ());
        Cairo.Context canvas_ctx = Gdk.cairo_create (canvas.get_window ());

        canvas.get_style_context ().render_background (pixmap_ctx, 0, 0, pixmap_dim.width, pixmap_dim.height);

        bool old_quality_setting = zoom_high_quality;
        zoom_high_quality = true;
        render_zoomed_to_pixmap (interactive_zoom_state);
        zoom_high_quality = old_quality_setting;

        canvas_ctx.set_source_surface (pixmap, 0, 0);
        canvas_ctx.paint ();
    }

    protected virtual bool is_zoom_supported () {
        return false;
    }

    protected virtual void cancel_zoom () {
        if (pixmap != null) {
            canvas.get_style_context ().render_background (pixmap_ctx, 0, 0, pixmap_dim.width, pixmap_dim.height);
        }
    }

    protected virtual void save_zoom_state () {
        saved_zoom_state = static_zoom_state;
        has_saved_zoom_state = true;
    }

    protected virtual void restore_zoom_state () {
        if (!has_saved_zoom_state)
            return;

        static_zoom_state = saved_zoom_state;
        repaint ();
        has_saved_zoom_state = false;
    }

    protected virtual ZoomBuffer? get_zoom_buffer () {
        return null;
    }

    protected ZoomState get_saved_zoom_state () {
        return saved_zoom_state;
    }

    protected void set_zoom_state (ZoomState zoom_state) {
        assert (is_zoom_supported ());

        static_zoom_state = zoom_state;
    }

    protected ZoomState get_zoom_state () {
        assert (is_zoom_supported ());

        return static_zoom_state;
    }

    public override void switched_to () {
        base.switched_to ();

        if (unscaled != null)
            repaint ();
    }

    public override void set_container (Gtk.Window container) {
        base.set_container (container);

        // scrollbar policy in fullscreen mode needs to be auto/auto, else the pixbuf will shift
        // off the screen
        if (container is FullscreenWindow)
            set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
    }

    // max_dim represents the maximum size of the original pixbuf (i.e. pixbuf may be scaled and
    // the caller capable of producing larger ones depending on the viewport size).  max_dim
    // is used when scale_up_to_viewport is set to true.  Pass a Dimensions with no area if
    // max_dim should be ignored (i.e. scale_up_to_viewport is false).
    public void set_pixbuf (Gdk.Pixbuf unscaled, Dimensions max_dim, Direction? direction = null) {
        static_zoom_state = ZoomState (max_dim, pixmap_dim,
                                       static_zoom_state.get_interpolation_factor (),
                                       static_zoom_state.get_viewport_center ());

        cancel_transition ();

        this.unscaled = unscaled;
        this.max_dim = max_dim;
        this.old_scaled = scaled;
        scaled = null;

        // need to make sure this has happened
        canvas.realize ();

        repaint (direction);
    }

    public void blank_display () {
        unscaled = null;
        max_dim = Dimensions ();
        scaled = null;
        pixmap = null;

        // this has to have happened
        canvas.realize ();

        // force a redraw
        invalidate_all ();
    }

    public Cairo.Surface? get_surface () {
        return pixmap;
    }

    public Dimensions get_surface_dim () {
        return pixmap_dim;
    }

    public Cairo.Context get_cairo_context () {
        return pixmap_ctx;
    }

    public void paint_text (Pango.Layout pango_layout, int x, int y) {
        text_ctx.move_to (x, y);
        Pango.cairo_show_layout (text_ctx, pango_layout);
    }

    public Scaling get_canvas_scaling () {
        return (get_container () is FullscreenWindow) ? Scaling.for_screen (get_container (), scale_up_to_viewport)
               : Scaling.for_widget (viewport, scale_up_to_viewport);
    }

    public Gdk.Pixbuf? get_unscaled_pixbuf () {
        return unscaled;
    }

    public Gdk.Pixbuf? get_scaled_pixbuf () {
        return scaled;
    }

    // Returns a rectangle describing the pixbuf in relation to the canvas
    public Gdk.Rectangle get_scaled_pixbuf_position () {
        return scaled_pos;
    }

    public bool is_inside_pixbuf (int x, int y) {
        return coord_in_rectangle (x, y, scaled_pos);
    }

    public void invalidate (Gdk.Rectangle rect) {
        if (canvas.get_window () != null)
            canvas.get_window ().invalidate_rect (rect, false);
    }

    public void invalidate_all () {
        if (canvas.get_window () != null)
            canvas.get_window ().invalidate_rect (null, false);
    }

    private void on_viewport_resize () {
        // do fast repaints while resizing
        internal_repaint (true, null);
    }

    protected override void on_resize_finished (Gdk.Rectangle rect) {
        base.on_resize_finished (rect);

        // when the resize is completed, do a high-quality repaint
        repaint ();
    }

    private bool on_canvas_exposed (Cairo.Context exposed_ctx) {
        // draw pixmap onto canvas unless it's not been instantiated, in which case draw background
        // (so either old image or contents of another page is not left on screen)
        if (pixmap != null) {
            exposed_ctx.set_source_surface (pixmap, 0, 0);
        } else {
            canvas.get_style_context ().render_background (exposed_ctx, 0, 0, get_allocated_width (), get_allocated_height ());
        }

        exposed_ctx.rectangle (0, 0, get_allocated_width (), get_allocated_height ());
        exposed_ctx.paint ();

        return true;
    }

    protected virtual void new_surface (Cairo.Context ctx, Dimensions ctx_dim) {
    }

    protected virtual void updated_pixbuf (Gdk.Pixbuf pixbuf, UpdateReason reason, Dimensions old_dim) {
    }

    protected virtual void paint (Cairo.Context ctx, Dimensions ctx_dim) {
        if (is_zoom_supported () && (!static_zoom_state.is_default ())) {
            canvas.get_style_context ().render_background (ctx, 0, 0, ctx_dim.width, ctx_dim.height);
            render_zoomed_to_pixmap (static_zoom_state);
        } else if (!transition_clock.paint (ctx, ctx_dim.width, ctx_dim.height)) {
            // transition is not running, so paint the full image over the background
            canvas.get_style_context ().render_background (ctx, 0, 0, ctx_dim.width, ctx_dim.height);
            Gdk.cairo_set_source_pixbuf (ctx, scaled, scaled_pos.x, scaled_pos.y);
            ctx.paint ();
        }
    }

    private void repaint_pixmap () {
        if (pixmap_ctx == null)
            return;

        paint (pixmap_ctx, pixmap_dim);
        invalidate_all ();
    }

    public void repaint (Direction? direction = null) {
        internal_repaint (false, direction);
    }

    private void internal_repaint (bool fast, Direction? direction) {
        // if not in view, assume a full repaint needed in future but do nothing more
        if (!is_in_view ()) {
            pixmap = null;
            scaled = null;

            return;
        }

        // no image or window, no painting
        if (unscaled == null || canvas.get_window () == null)
            return;

        Gtk.Allocation allocation;
        viewport.get_allocation (out allocation);

        int width = allocation.width;
        int height = allocation.height;

        if (width <= 0 || height <= 0)
            return;

        bool new_pixbuf = (scaled == null);

        // save if reporting an image being rescaled
        Dimensions old_scaled_dim = Dimensions.for_rectangle (scaled_pos);
        Gdk.Rectangle old_scaled_pos = scaled_pos;

        // attempt to reuse pixmap
        if (pixmap_dim.width != width || pixmap_dim.height != height)
            pixmap = null;

        // if necessary, create a pixmap as large as the entire viewport
        bool new_pixmap = false;
        if (pixmap == null) {
            init_pixmap (width, height);
            new_pixmap = true;
        }

        if (new_pixbuf || new_pixmap) {
            Dimensions unscaled_dim = Dimensions.for_pixbuf (unscaled);

            // determine scaled size of pixbuf ... if a max dimensions is set and not scaling up,
            // respect it
            Dimensions scaled_dim = Dimensions ();
            if (!scale_up_to_viewport && max_dim.has_area () && max_dim.width < width && max_dim.height < height)
                scaled_dim = max_dim;
            else
                scaled_dim = unscaled_dim.get_scaled_proportional (pixmap_dim);

            assert (width >= scaled_dim.width);
            assert (height >= scaled_dim.height);

            // center pixbuf on the canvas
            scaled_pos.x = (width - scaled_dim.width) / 2;
            scaled_pos.y = (height - scaled_dim.height) / 2;
            scaled_pos.width = scaled_dim.width;
            scaled_pos.height = scaled_dim.height;
        }

        Gdk.InterpType interp = (fast) ? FAST_INTERP : QUALITY_INTERP;

        // rescale if canvas rescaled or better quality is requested
        if (scaled == null) {
            scaled = resize_pixbuf (unscaled, Dimensions.for_rectangle (scaled_pos), interp);

            UpdateReason reason = UpdateReason.RESIZED_CANVAS;
            if (new_pixbuf)
                reason = UpdateReason.NEW_PIXBUF;
            else if (!new_pixmap && interp == QUALITY_INTERP)
                reason = UpdateReason.QUALITY_IMPROVEMENT;

            static_zoom_state = ZoomState (max_dim, pixmap_dim,
                                           static_zoom_state.get_interpolation_factor (),
                                           static_zoom_state.get_viewport_center ());

            updated_pixbuf (scaled, reason, old_scaled_dim);
        }

        zoom_high_quality = !fast;

        if (direction != null && !transition_clock.is_in_progress ()) {
            Spit.Transitions.Visuals visuals = new Spit.Transitions.Visuals (old_scaled,
                    old_scaled_pos, scaled, scaled_pos, parse_color ("#000"));

            transition_clock.start (visuals, direction.to_transition_direction (), transition_duration_msec,
                                    repaint_pixmap);
        }

        if (!transition_clock.is_in_progress ())
            repaint_pixmap ();
    }

    private void init_pixmap (int width, int height) {
        assert (unscaled != null);
        assert (canvas.get_window () != null);

        // Cairo backing surface (manual double-buffering)
        pixmap = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
        pixmap_dim = Dimensions (width, height);

        // Cairo context for drawing on the pixmap
        pixmap_ctx = new Cairo.Context (pixmap);

        // need a new pixbuf to fit this scale
        scaled = null;

        // Cairo context for drawing text on the pixmap
        text_ctx = new Cairo.Context (pixmap);
        set_source_color_from_string (text_ctx, "#fff");


        // no need to resize canvas, viewport does that automatically

        new_surface (pixmap_ctx, pixmap_dim);
    }

    protected override bool on_context_keypress () {
        return popup_context_menu (get_page_context_menu ());
    }

    protected virtual void on_previous_photo () {
    }

    protected virtual void on_next_photo () {
    }

    public override bool key_press_event (Gdk.EventKey event) {
        // if the user holds the arrow keys down, we will receive a steady stream of key press
        // events for an operation that isn't designed for a rapid succession of output ...
        // we staunch the supply of new photos to under a quarter second (#533)
        bool nav_ok = (event.time - last_nav_key) > KEY_REPEAT_INTERVAL_MSEC;

        bool handled = true;
        switch (Gdk.keyval_name (event.keyval)) {
        case "Left":
        case "KP_Left":
            if (nav_ok) {
                on_previous_photo ();
                last_nav_key = event.time;
            }
            break;

        case "Right":
        case "KP_Right":
        case "space":
            if (nav_ok) {
                on_next_photo ();
                last_nav_key = event.time;
            }
            break;

        default:
            handled = false;
            break;
        }

        if (handled)
            return true;

        return (base.key_press_event != null) ? base.key_press_event (event) : true;
    }
}

//
// DragAndDropHandler attaches signals to a Page to properly handle drag-and-drop requests for the
// Page as a DnD Source.  (DnD Destination handling is handled by the appropriate AppWindow, i.e.
// LibraryWindow and DirectWindow). Assumes the Page's ViewCollection holds MediaSources.
//
public class DragAndDropHandler {
    private enum TargetType {
        XDS,
        MEDIA_LIST
    }

    private const Gtk.TargetEntry[] SOURCE_TARGET_ENTRIES = {
        { "XdndDirectSave0", Gtk.TargetFlags.OTHER_APP, TargetType.XDS },
        { "shotwell/media-id-atom", Gtk.TargetFlags.SAME_APP, TargetType.MEDIA_LIST }
    };

    private static Gdk.Atom? XDS_ATOM = null;
    private static Gdk.Atom? TEXT_ATOM = null;
    private static uint8[]? XDS_FAKE_TARGET = null;

    private weak Page page;
    private Gtk.Widget event_source;
    private File? drag_destination = null;
    private ExporterUI exporter = null;

    public DragAndDropHandler (Page page) {
        this.page = page;
        this.event_source = page.get_event_source ();
        assert (event_source != null);
        assert (event_source.get_has_window ());

        // Need to do this because static member variables are not properly handled
        if (XDS_ATOM == null)
            XDS_ATOM = Gdk.Atom.intern_static_string ("XdndDirectSave0");

        if (TEXT_ATOM == null)
            TEXT_ATOM = Gdk.Atom.intern_static_string ("text/plain");

        if (XDS_FAKE_TARGET == null)
            XDS_FAKE_TARGET = string_to_uchar_array ("shotwell.txt");

        // register what's available on this DnD Source
        Gtk.drag_source_set (event_source, Gdk.ModifierType.BUTTON1_MASK, SOURCE_TARGET_ENTRIES,
                             Gdk.DragAction.COPY);

        // attach to the event source's DnD signals, not the Page's, which is a NO_WINDOW widget
        // and does not emit them
        event_source.drag_begin.connect (on_drag_begin);
        event_source.drag_data_get.connect (on_drag_data_get);
        event_source.drag_end.connect (on_drag_end);
        event_source.drag_failed.connect (on_drag_failed);
    }

    ~DragAndDropHandler () {
        if (event_source != null) {
            event_source.drag_begin.disconnect (on_drag_begin);
            event_source.drag_data_get.disconnect (on_drag_data_get);
            event_source.drag_end.disconnect (on_drag_end);
            event_source.drag_failed.disconnect (on_drag_failed);
        }

        page = null;
        event_source = null;
    }

    private void on_drag_begin (Gdk.DragContext context) {
        debug ("on_drag_begin (%s)", page.get_page_name ());

        if (page == null || page.get_view ().get_selected_count () == 0 || exporter != null)
            return;

        drag_destination = null;

        // use the first media item as the icon
        ThumbnailSource thumb = (ThumbnailSource) page.get_view ().get_selected_at (0).get_source ();

        try {
            Gdk.Pixbuf icon = thumb.get_thumbnail (AppWindow.DND_ICON_SCALE);
            Gtk.drag_source_set_icon_pixbuf (event_source, icon);
        } catch (Error err) {
            warning ("Unable to fetch icon for drag-and-drop from %s: %s", thumb.to_string (),
                     err.message);
        }

        // set the XDS property to indicate an XDS save is available
#if VALA_0_20
        Gdk.property_change (context.get_source_window (), XDS_ATOM, TEXT_ATOM, 8, Gdk.PropMode.REPLACE,
                             XDS_FAKE_TARGET, 1);
#else
        Gdk.property_change (context.get_source_window (), XDS_ATOM, TEXT_ATOM, 8, Gdk.PropMode.REPLACE,
                             XDS_FAKE_TARGET);
#endif
    }

    private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data,
                                   uint target_type, uint time) {
        debug ("on_drag_data_get (%s)", page.get_page_name ());

        if (page == null || page.get_view ().get_selected_count () == 0)
            return;

        switch (target_type) {
        case TargetType.XDS:
            // Fetch the XDS property that has been set with the destination path
            uchar[] data = new uchar[4096];
            Gdk.Atom actual_type;
            int actual_format = 0;
            bool fetched = Gdk.property_get (context.get_source_window (), XDS_ATOM, TEXT_ATOM,
                                             0, data.length, 0, out actual_type, out actual_format, out data);

            // the destination path is actually for our XDS_FAKE_TARGET, use its parent
            // to determine where the file(s) should go
            if (fetched && data != null && data.length > 0)
                drag_destination = File.new_for_uri (uchar_array_to_string (data)).get_parent ();

            debug ("on_drag_data_get (%s): %s", page.get_page_name (),
                   (drag_destination != null) ? drag_destination.get_path () : "(no path)");

            // Set the property to "S" for Success or "E" for Error
            selection_data.set (XDS_ATOM, 8,
                                string_to_uchar_array ((drag_destination != null) ? "S" : "E"));
            break;

        case TargetType.MEDIA_LIST:
            Gee.Collection<MediaSource> sources =
                (Gee.Collection<MediaSource>) page.get_view ().get_selected_sources ();

            // convert the selected media sources to Gdk.Atom-encoded sourceID strings for
            // internal drag-and-drop
            selection_data.set (Gdk.Atom.intern_static_string ("SourceIDAtom"), (int) sizeof (Gdk.Atom),
                                serialize_media_sources (sources));
            break;

        default:
            warning ("on_drag_data_get (%s): unknown target type %u", page.get_page_name (),
                     target_type);
            break;
        }
    }

    private void on_drag_end () {
        debug ("on_drag_end (%s)", page.get_page_name ());

        if (page == null || page.get_view ().get_selected_count () == 0 || drag_destination == null
                || exporter != null) {
            return;
        }

        debug ("Exporting to %s", drag_destination.get_path ());

        // drag-and-drop export doesn't pop up an export dialog, so use what are likely the
        // most common export settings (the current -- or "working" -- file format, with
        // all transformations applied, at the image's original size).
        if (drag_destination.get_path () != null) {
            exporter = new ExporterUI (new Exporter (
                                           (Gee.Collection<Photo>) page.get_view ().get_selected_sources (),
                                           drag_destination, Scaling.for_original (), ExportFormatParameters.current ()));
            exporter.export (on_export_completed);
        } else {
            AppWindow.error_message (_ ("Photos cannot be exported to this directory."));
        }

        drag_destination = null;
    }

    private bool on_drag_failed (Gdk.DragContext context, Gtk.DragResult drag_result) {
        debug ("on_drag_failed (%s): %d", page.get_page_name (), (int) drag_result);

        if (page == null)
            return false;

        drag_destination = null;

        return false;
    }

    private void on_export_completed () {
        exporter = null;
    }
}

public class ContractMenuItem : Gtk.MenuItem {
    private Granite.Services.Contract contract;
    private Gee.List<DataSource> sources;

    public ContractMenuItem (Granite.Services.Contract contract, Gee.List<DataSource> sources) {
        this.contract = contract;
        this.sources = sources;

        label = contract.get_display_name ();
        tooltip_text = contract.get_description ();
    }

    public override void activate () {
        try {
            File[] modified_files = null;
            foreach (var source in sources) {
                Photo modified_file = (Photo)source;
                if (modified_file.get_file_format () == PhotoFileFormat.RAW || !modified_file.has_alterations ())
                    modified_files += modified_file.get_file ();
                else
                    modified_files += modified_file.get_modified_file ();
            }
            contract.execute_with_files (modified_files);
        } catch (Error err) {
            warning (err.message);
        }
    }
}
