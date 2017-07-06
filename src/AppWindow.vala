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

public class FullscreenWindow : PageWindow {
    public const int TOOLBAR_INVOCATION_MSEC = 250;
    public const int TOOLBAR_DISMISSAL_SEC = 2;
    public const int TOOLBAR_CHECK_DISMISSAL_MSEC = 500;

    private Gtk.Window toolbar_window;
    private Gtk.ToggleToolButton pin_button;
    private bool is_toolbar_shown = false;
    private bool waiting_for_invoke = false;
    private time_t left_toolbar_time = 0;
    private bool switched_to = false;
    private bool is_toolbar_dismissal_enabled = true;

    public FullscreenWindow (Page page) {
        set_current_page (page);

        ui.ensure_update ();

        Gtk.AccelGroup accel_group = ui.get_accel_group ();
        if (accel_group != null)
            add_accel_group (accel_group);

        set_screen (AppWindow.get_instance ().get_screen ());

        // Needed so fullscreen will occur on correct monitor in multi-monitor setups
        Gdk.Rectangle monitor = get_monitor_geometry ();
        move (monitor.x, monitor.y);

        set_border_width (0);

        pin_button = new Gtk.ToggleToolButton ();
        pin_button.icon_name = "pin-toolbar";
        pin_button.tooltip_text = _("Pin the toolbar open");
        pin_button.clicked.connect (update_toolbar_dismissal);

        var img = new Gtk.Image.from_icon_name ("window-restore-symbolic", Gtk.IconSize.LARGE_TOOLBAR);

        var close_button = new Gtk.ToolButton (img, null);
        close_button.tooltip_text = _("Leave fullscreen");
        close_button.clicked.connect (on_close);

        var toolbar = page.get_toolbar ();

        if (page is SlideshowPage) {
            // slideshow page doesn't own toolbar to hide it, subscribe to signal instead
            ((SlideshowPage) page).hide_toolbar.connect (hide_toolbar);
        } else {
            // only non-slideshow pages should have pin button
            toolbar.insert (pin_button, -1);
        }

        page.set_cursor_hide_time (TOOLBAR_DISMISSAL_SEC * 1000);
        page.start_cursor_hiding ();

        toolbar.insert (close_button, -1);

        // set up toolbar along bottom of screen
        toolbar_window = new Gtk.Window (Gtk.WindowType.POPUP);
        toolbar_window.set_screen (get_screen ());
        toolbar_window.set_border_width (0);
        toolbar_window.add (toolbar);

        toolbar_window.realize.connect (on_toolbar_realized);

        add (page);

        // call to set_default_size () saves one repaint caused by changing
        // size from default to full screen. In slideshow mode, this change
        // also causes pixbuf cache updates, so it really saves some work.
        set_default_size (monitor.width, monitor.height);

        // need to create a Gdk.Window to set masks
        fullscreen ();
        show_all ();

        // capture motion events to show the toolbar
        add_events (Gdk.EventMask.POINTER_MOTION_MASK);

        // start off with toolbar invoked, as a clue for the user
        invoke_toolbar ();
    }

    public void disable_toolbar_dismissal () {
        is_toolbar_dismissal_enabled = false;
    }

    public void update_toolbar_dismissal () {
        is_toolbar_dismissal_enabled = !pin_button.get_active ();
    }

    private Gdk.Rectangle get_monitor_geometry () {
        Gdk.Rectangle monitor;

        get_screen ().get_monitor_geometry (
            get_screen ().get_monitor_at_window (AppWindow.get_instance ().get_window ()), out monitor);

        return monitor;
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        bool result = base.configure_event (event);

        if (!switched_to) {
            get_current_page ().switched_to ();
            switched_to = true;
        }

        return result;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        // check for an escape/abort
        switch (Gdk.keyval_name (event.keyval)) {
            case "F11":
            case "Escape":
                on_close ();
                return true;
        }

        // Make sure this event gets propagated to the underlying window...
        AppWindow.get_instance ().key_press_event (event);

        // ...then let the base class take over
        return (base.key_press_event != null) ? base.key_press_event (event) : false;
    }

    private void on_close () {
        hide_toolbar ();
        toolbar_window = null;

        AppWindow.get_instance ().end_fullscreen ();
    }

    public new void close () {
        on_close ();
    }

    public override void destroy () {
        Page? page = get_current_page ();
        clear_current_page ();

        if (page != null) {
            page.stop_cursor_hiding ();
            page.switching_from ();
        }

        base.destroy ();
    }

    public override bool delete_event (Gdk.EventAny event) {
        on_close ();
        AppWindow.get_instance ().destroy ();

        return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (!is_toolbar_shown) {
            // if pointer is in toolbar height range without the mouse down (i.e. in the middle of
            // an edit operation) and it stays there the necessary amount of time, invoke the
            // toolbar
            if (!waiting_for_invoke && is_pointer_in_toolbar ()) {
                Timeout.add (TOOLBAR_INVOCATION_MSEC, on_check_toolbar_invocation);
                waiting_for_invoke = true;
            }
        }

        return (base.motion_notify_event != null) ? base.motion_notify_event (event) : false;
    }

    private bool is_pointer_in_toolbar () {
        Gdk.DeviceManager? devmgr = get_display ().get_device_manager ();
        if (devmgr == null) {
            debug ("No device manager for display");

            return false;
        }

        int py;
        devmgr.get_client_pointer ().get_position (null, null, out py);

        int wy;
        toolbar_window.get_window ().get_geometry (null, out wy, null, null);

        return (py >= wy);
    }

    private bool on_check_toolbar_invocation () {
        waiting_for_invoke = false;

        if (is_toolbar_shown)
            return false;

        if (!is_pointer_in_toolbar ())
            return false;

        invoke_toolbar ();

        return false;
    }

    private void on_toolbar_realized () {
        Gtk.Requisition req;
        toolbar_window.get_preferred_size (null, out req);

        // place the toolbar in the center of the monitor along the bottom edge
        Gdk.Rectangle monitor = get_monitor_geometry ();
        int tx = monitor.x + (monitor.width - req.width) / 2;
        if (tx < 0)
            tx = 0;

        int ty = monitor.y + monitor.height - req.height;
        if (ty < 0)
            ty = 0;

        toolbar_window.move (tx, ty);
        toolbar_window.set_opacity (Resources.TRANSIENT_WINDOW_OPACITY);
    }

    private void invoke_toolbar () {
        toolbar_window.show_all ();

        is_toolbar_shown = true;

        Timeout.add (TOOLBAR_CHECK_DISMISSAL_MSEC, on_check_toolbar_dismissal);
    }

    private bool on_check_toolbar_dismissal () {
        if (!is_toolbar_shown)
            return false;

        if (toolbar_window == null)
            return false;

        // if dismissal is disabled, keep open but keep checking
        if ((!is_toolbar_dismissal_enabled))
            return true;

        // if the pointer is in toolbar range, keep it alive, but keep checking
        if (is_pointer_in_toolbar ()) {
            left_toolbar_time = 0;

            return true;
        }

        // if this is the first time noticed, start the timer and keep checking
        if (left_toolbar_time == 0) {
            left_toolbar_time = time_t ();

            return true;
        }

        // see if enough time has elapsed
        time_t now = time_t ();
        assert (now >= left_toolbar_time);

        if (now - left_toolbar_time < TOOLBAR_DISMISSAL_SEC)
            return true;

        hide_toolbar ();

        return false;
    }

    private void hide_toolbar () {
        toolbar_window.hide ();
        is_toolbar_shown = false;
    }
}

// PageWindow is a Gtk.Window with essential functions for hosting a Page.  There may be more than
// one PageWindow in the system, and closing one does not imply exiting the application.
//
// PageWindow offers support for hosting a single Page; multiple Pages must be handled by the
// subclass.  A subclass should set current_page to the user-visible Page for it to receive
// various notifications.  It is the responsibility of the subclass to notify Pages when they're
// switched to and from, and other aspects of the Page interface.
public abstract class PageWindow : Gtk.Window {
    protected Gtk.UIManager ui = new Gtk.UIManager ();

    private Page current_page = null;
    private int busy_counter = 0;

    protected virtual void switched_pages (Page? old_page, Page? new_page) {
    }

    public PageWindow () {
        // the current page needs to know when modifier keys are pressed
        add_events (Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK
                    | Gdk.EventMask.STRUCTURE_MASK);

        set_has_resize_grip (false);
    }

    public Page? get_current_page () {
        return current_page;
    }

    public virtual void set_current_page (Page page) {
        if (current_page != null)
            current_page.clear_container ();

        Page? old_page = current_page;
        current_page = page;
        current_page.set_container (this);

        switched_pages (old_page, page);
    }

    public virtual void clear_current_page () {
        if (current_page != null)
            current_page.clear_container ();

        Page? old_page = current_page;
        current_page = null;

        switched_pages (old_page, null);
    }

    public override bool key_press_event (Gdk.EventKey event) {
        if (get_focus () is Gtk.Entry && get_focus ().key_press_event (event))
            return true;

        if (current_page != null && current_page.notify_app_key_pressed (event))
            return true;

        return (base.key_press_event != null) ? base.key_press_event (event) : false;
    }

    public override bool key_release_event (Gdk.EventKey event) {
        if (get_focus () is Gtk.Entry && get_focus ().key_release_event (event))
            return true;

        if (current_page != null && current_page.notify_app_key_released (event))
            return true;

        return (base.key_release_event != null) ? base.key_release_event (event) : false;
    }

    public override bool focus_in_event (Gdk.EventFocus event) {
        if (current_page != null && current_page.notify_app_focus_in (event))
            return true;

        return (base.focus_in_event != null) ? base.focus_in_event (event) : false;
    }

    public override bool focus_out_event (Gdk.EventFocus event) {
        if (current_page != null && current_page.notify_app_focus_out (event))
            return true;

        return (base.focus_out_event != null) ? base.focus_out_event (event) : false;
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (current_page != null) {
            if (current_page.notify_configure_event (event))
                return true;
        }

        return (base.configure_event != null) ? base.configure_event (event) : false;
    }

    public void set_busy_cursor () {
        if (busy_counter++ > 0)
            return;

        get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
        spin_event_loop ();
    }

    public void set_normal_cursor () {
        if (busy_counter <= 0) {
            busy_counter = 0;
            return;
        } else if (--busy_counter > 0) {
            return;
        }

        get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.LEFT_PTR));
        spin_event_loop ();
    }

}

// AppWindow is the parent window for most windows in Shotwell (FullscreenWindow is the exception).
// There are multiple types of AppWindows (LibraryWindow, DirectWindow) for different tasks, but only
// one AppWindow may exist per process.  Thus, if the user closes an AppWindow, the program exits.
//
// AppWindow also offers support for going into fullscreen mode.  It handles the interface
// notifications Page is expecting when switching back and forth.
public abstract class AppWindow : PageWindow {
    public const int DND_ICON_SCALE = 128;

    protected static AppWindow instance = null;

    private static FullscreenWindow fullscreen_window = null;
    private static CommandManager command_manager = null;

    // the AppWindow maintains its own UI manager because the first UIManager an action group is
    // added to is the one that claims its accelerators
    protected Gtk.ActionGroup[] common_action_groups;
    protected bool maximized = false;
    protected Dimensions dimensions;
    protected int pos_x = 0;
    protected int pos_y = 0;
    protected Gtk.HeaderBar header;

    private Gtk.ActionGroup common_action_group = new Gtk.ActionGroup ("AppWindowGlobalActionGroup");

    public AppWindow () {
        // although there are multiple AppWindow types, only one may exist per-process
        assert (instance == null);
        instance = this;
        icon_name = "multimedia-photo-manager";

        header = new Gtk.HeaderBar ();
        header.set_show_close_button (true);
        this.set_titlebar (header);

        set_default_title ();

        // restore previous size and maximization state
        if (this is LibraryWindow) {
            Config.Facade.get_instance ().get_library_window_state (out maximized, out dimensions);
        } else {
            assert (this is DirectWindow);
            Config.Facade.get_instance ().get_direct_window_state (out maximized, out dimensions);
        }

        set_default_size (dimensions.width, dimensions.height);

        if (maximized)
            maximize ();

        assert (command_manager == null);
        command_manager = new CommandManager ();
        command_manager.altered.connect (on_command_manager_altered);

        // Because the first UIManager to associated with an ActionGroup claims the accelerators,
        // need to create the AppWindow's ActionGroup early on and add it to an application-wide
        // UIManager.  In order to activate those accelerators, we need to create a dummy UI string
        // that lists all the common actions.  We build it on-the-fly from the actions associated
        // with each ActionGroup while we're adding the groups to the UIManager.
        common_action_groups = create_common_action_groups ();
        foreach (Gtk.ActionGroup group in common_action_groups)
            ui.insert_action_group (group, 0);

        try {
            ui.add_ui_from_string (build_dummy_ui_string (common_action_groups), -1);
        } catch (Error err) {
            error ("Unable to add AppWindow UI: %s", err.message);
        }

        ui.ensure_update ();
        add_accel_group (ui.get_accel_group ());

        build_header_bar ();
    }

    protected virtual void set_default_title () {
        title = _ (Resources.APP_TITLE);
    }

    protected virtual void build_header_bar () {
        var redo_action = get_common_action ("CommonRedo");
        var redo_btn = redo_action.create_tool_item ();
        redo_btn.sensitive = true;
        header.pack_end (redo_btn);

        var undo_action = get_common_action ("CommonUndo");
        var undo_btn = undo_action.create_tool_item ();
        undo_btn.sensitive = true;
        header.pack_end (undo_btn);
    }


    private Gtk.ActionEntry[] create_common_actions () {
        Gtk.ActionEntry quit = { "CommonQuit", null, _("_Quit"), "<Ctrl>Q", _("_Quit"), on_quit };
        Gtk.ActionEntry fullscreen = { "CommonFullscreen", null, _("Fulls_creen"), "F11", _("Fulls_creen"), on_fullscreen };
        Gtk.ActionEntry undo = { "CommonUndo", "edit-undo", Resources.UNDO_MENU, "<Ctrl>Z", Resources.UNDO_MENU, on_undo };
        Gtk.ActionEntry redo = { "CommonRedo", "edit-redo", Resources.REDO_MENU, "<Ctrl><Shift>Z", Resources.REDO_MENU, on_redo };
        Gtk.ActionEntry jump_to_file = { "CommonJumpToFile", null, Resources.JUMP_TO_FILE_MENU, "<Ctrl><Shift>M", Resources.JUMP_TO_FILE_MENU, on_jump_to_file };
        Gtk.ActionEntry select_all = { "CommonSelectAll", null, Resources.SELECT_ALL_MENU, "<Ctrl>A", Resources.SELECT_ALL_MENU, on_select_all };
        Gtk.ActionEntry select_none = { "CommonSelectNone", null, null, "<Ctrl><Shift>A", TRANSLATABLE, on_select_none };

        Gtk.ActionEntry[] actions = new Gtk.ActionEntry[0];
        actions += quit;
        actions += fullscreen;
        actions += undo;
        actions += redo;
        actions += jump_to_file;
        actions += select_all;
        actions += select_none;

        return actions;
    }

    protected abstract void on_fullscreen ();

    public static bool has_instance () {
        return instance != null;
    }

    public static AppWindow get_instance () {
        return instance;
    }

    public static FullscreenWindow get_fullscreen () {
        return fullscreen_window;
    }

    public static Gtk.Builder create_builder (string glade_filename = "shotwell.ui", void *user = null) {
        Gtk.Builder builder = new Gtk.Builder ();
        try {
            builder.add_from_file (AppDirs.get_resources_dir ().get_child ("ui").get_child (
                                       glade_filename).get_path ());
        } catch (GLib.Error error) {
            warning ("Unable to create Gtk.Builder: %s\n", error.message);
        }

        builder.connect_signals (user);

        return builder;
    }

    public static void error_message (string message, Gtk.Window? parent = null) {
        error_message_with_title (_ (Resources.APP_TITLE), message, parent);
    }

    public static void error_message_with_title (string title, string message, Gtk.Window? parent = null, bool should_escape = true) {
        // Per the Gnome HIG (http://library.gnome.org/devel/hig-book/2.32/windows-alert.html.en),
        // alert-style dialogs mustn't have titles; we use the title as the primary text, and the
        // existing message as the secondary text.
        Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, "%s", build_alert_body_text (title, message, should_escape));

        // Occasionally, with_markup doesn't actually do anything, but set_markup always works.
        dialog.set_markup (build_alert_body_text (title, message, should_escape));

        dialog.use_markup = true;
        dialog.run ();
        dialog.destroy ();
    }

    public static bool negate_affirm_question (string message, string negative, string affirmative,
            string? title = null, Gtk.Window? parent = null) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", build_alert_body_text (title, message));

        dialog.set_markup (build_alert_body_text (title, message));
        dialog.add_buttons (negative, Gtk.ResponseType.NO, affirmative, Gtk.ResponseType.YES);
        dialog.set_urgency_hint (true);

        bool response = (dialog.run () == Gtk.ResponseType.YES);

        dialog.destroy ();

        return response;
    }

    public static Gtk.ResponseType negate_affirm_cancel_question (string message, string negative,
            string affirmative, string? title = null, Gtk.Window? parent = null) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", build_alert_body_text (title, message));

        dialog.add_buttons (negative, Gtk.ResponseType.NO, affirmative, Gtk.ResponseType.YES,
                            _ ("_Cancel"), Gtk.ResponseType.CANCEL);

        // Occasionally, with_markup doesn't actually enable markup, but set_markup always works.
        dialog.set_markup (build_alert_body_text (title, message));
        dialog.use_markup = true;

        int response = dialog.run ();

        dialog.destroy ();

        return (Gtk.ResponseType) response;
    }

    public static Gtk.ResponseType affirm_cancel_negate_question (string message,
            string affirmative, string negative,
            string? title = null, Gtk.Window? parent = null) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", build_alert_body_text (title, message));

        dialog.add_buttons (affirmative, Gtk.ResponseType.YES,
                            _ ("_Cancel"), Gtk.ResponseType.CANCEL,
                            negative, Gtk.ResponseType.NO);

        // Occasionally, with_markup doesn't actually enable markup, but set_markup always works.
        dialog.set_markup (build_alert_body_text (title, message));
        dialog.use_markup = true;

        int response = dialog.run ();

        dialog.destroy ();

        return (Gtk.ResponseType) response;
    }

    public static Gtk.ResponseType affirm_cancel_question (string message, string affirmative,
            string? title = null, Gtk.Window? parent = null) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", message);
        // Occasionally, with_markup doesn't actually enable markup...? Force the issue.
        dialog.set_markup (message);
        dialog.use_markup = true;
        dialog.title = (title != null) ? title : _ (Resources.APP_TITLE);
        dialog.add_buttons (affirmative, Gtk.ResponseType.YES, _ ("_Cancel"),
                            Gtk.ResponseType.CANCEL);

        int response = dialog.run ();

        dialog.destroy ();

        return (Gtk.ResponseType) response;
    }

    public static Gtk.ResponseType cancel_affirm_question (string message, string affirmative,
            string? title = null, Gtk.Window? parent = null) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog.with_markup ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", message);
        // Occasionally, with_markup doesn't actually enable markup...? Force the issue.
        dialog.set_markup (message);
        dialog.use_markup = true;
        dialog.title = (title != null) ? title : _ (Resources.APP_TITLE);
        dialog.add_buttons (_("_Cancel"), Gtk.ResponseType.CANCEL,
                            affirmative, Gtk.ResponseType.YES);

        int response = dialog.run ();

        dialog.destroy ();

        return (Gtk.ResponseType) response;
    }

    public static Gtk.ResponseType negate_affirm_all_cancel_question (string message,
            string negative, string affirmative, string affirmative_all, string? title = null,
            Gtk.Window? parent = null) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog ((parent != null) ? parent : get_instance (),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", message);
        dialog.title = (title != null) ? title : _ (Resources.APP_TITLE);
        dialog.add_buttons (negative, Gtk.ResponseType.NO, affirmative, Gtk.ResponseType.YES,
                            affirmative_all, Gtk.ResponseType.APPLY,  _ ("_Cancel"), Gtk.ResponseType.CANCEL);

        int response = dialog.run ();

        dialog.destroy ();

        return (Gtk.ResponseType) response;
    }

    public static void database_error (DatabaseError err) {
        panic (_ ("A fatal error occurred when accessing Shotwell's library.  Shotwell cannot continue.\n\n%s").printf (
                   err.message));
    }

    public static void panic (string msg) {
        critical (msg);
        error_message (msg);

        Application.get_instance ().panic ();
    }

    public abstract string get_app_role ();

    protected void on_about () {
        Application.get_instance ().show_about (this);
    }

    protected virtual void on_quit () {
        Application.get_instance ().exit ();
    }

    protected void on_jump_to_file () {
        if (get_current_page ().get_view ().get_selected_count () != 1)
            return;

        MediaSource? media = get_current_page ().get_view ().get_selected_at (0).get_source ()
                             as MediaSource;
        if (media == null)
            return;

        try {
            AppWindow.get_instance ().show_file_uri (media.get_master_file ());
        } catch (Error err) {
            AppWindow.error_message (Resources.jump_to_file_failed (err));
        }
    }

    protected override void destroy () {
        on_quit ();
    }

    public void show_file_uri (File file) throws Error {
        AppInfo app_info = AppInfo.get_default_for_type ("inode/directory", true);
        var file_list = new List<File> ();
        file_list.append (file);
        app_info.launch (file_list, get_window ().get_screen ().get_display ().get_app_launch_context ());
    }

    public void show_uri (string url) throws Error {
        sys_show_uri (get_window ().get_screen (), url);
    }

    protected virtual Gtk.ActionGroup[] create_common_action_groups () {
        Gtk.ActionGroup[] groups = new Gtk.ActionGroup[0];

        common_action_group.add_actions (create_common_actions (), this);
        groups += common_action_group;

        return groups;
    }

    public Gtk.ActionGroup[] get_common_action_groups () {
        return common_action_groups;
    }

    public void go_fullscreen (Page page) {
        // if already fullscreen, use that
        if (fullscreen_window != null) {
            fullscreen_window.present ();

            return;
        }

        get_position (out pos_x, out pos_y);
        hide ();

        FullscreenWindow fsw = new FullscreenWindow (page);

        if (get_current_page () != null)
            get_current_page ().switching_to_fullscreen (fsw);

        fullscreen_window = fsw;
        fullscreen_window.present ();
    }

    public void end_fullscreen () {
        if (fullscreen_window == null)
            return;

        move (pos_x, pos_y);

        show_all ();

        if (get_current_page () != null)
            get_current_page ().returning_from_fullscreen (fullscreen_window);

        fullscreen_window.hide ();
        fullscreen_window.destroy ();
        fullscreen_window = null;

        present ();
    }

    public Gtk.Action? get_common_action (string name) {
        foreach (Gtk.ActionGroup group in common_action_groups) {
            Gtk.Action? action = group.get_action (name);
            if (action != null)
                return action;
        }

        warning ("No common action found: %s", name);

        return null;
    }

    public void set_common_action_sensitive (string name, bool sensitive) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.sensitive = sensitive;
    }

    public void set_common_action_important (string name, bool important) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.is_important = important;
    }

    public void set_common_action_visible (string name, bool visible) {
        Gtk.Action? action = get_common_action (name);
        if (action != null)
            action.visible = visible;
    }

    protected override void switched_pages (Page? old_page, Page? new_page) {
        update_common_action_availability (old_page, new_page);

        if (old_page != null) {
            old_page.get_view ().contents_altered.disconnect (on_update_common_actions);
            old_page.get_view ().selection_group_altered.disconnect (on_update_common_actions);
            old_page.get_view ().items_state_changed.disconnect (on_update_common_actions);
        }

        if (new_page != null) {
            new_page.get_view ().contents_altered.connect (on_update_common_actions);
            new_page.get_view ().selection_group_altered.connect (on_update_common_actions);
            new_page.get_view ().items_state_changed.connect (on_update_common_actions);

            update_common_actions (new_page, new_page.get_view ().get_selected_count (),
                                   new_page.get_view ().get_count ());
        }

        base.switched_pages (old_page, new_page);
    }

    // This is called when a Page is switched out and certain common actions are simply
    // unavailable for the new one.  This is different than update_common_actions () in that that
    // call is made when state within the Page has changed.
    protected virtual void update_common_action_availability (Page? old_page, Page? new_page) {
        bool is_checkerboard = new_page is CheckerboardPage;

        set_common_action_sensitive ("CommonSelectAll", is_checkerboard);
        set_common_action_sensitive ("CommonSelectNone", is_checkerboard);
    }

    // This is a counterpart to Page.update_actions (), but for common Gtk.Actions
    // NOTE: Although CommonFullscreen is declared here, it's implementation is up to the subclasses,
    // therefore they need to update its action.
    protected virtual void update_common_actions (Page page, int selected_count, int count) {
        if (page is CheckerboardPage)
            set_common_action_sensitive ("CommonSelectAll", count > 0);
        set_common_action_sensitive ("CommonJumpToFile", selected_count == 1);

        decorate_undo_action ();
        decorate_redo_action ();
    }

    private void on_update_common_actions () {
        Page? page = get_current_page ();
        if (page != null)
            update_common_actions (page, page.get_view ().get_selected_count (), page.get_view ().get_count ());
    }

    public static CommandManager get_command_manager () {
        return command_manager;
    }

    private void on_command_manager_altered () {
        decorate_undo_action ();
        decorate_redo_action ();
    }

    private void decorate_command_manager_action (string name, string prefix,
            string default_explanation, CommandDescription? desc) {
        Gtk.Action? action = get_common_action (name);
        if (action == null)
            return;

        if (desc != null) {
            action.label = "%s %s".printf (prefix, desc.get_name ());
            action.tooltip = action.label;
            action.sensitive = true;
        } else {
            action.label = prefix;
            action.tooltip = default_explanation;
            action.sensitive = false;
        }
    }

    public void decorate_undo_action () {
        decorate_command_manager_action ("CommonUndo", Resources.UNDO_LABEL, "",
                                         get_command_manager ().get_undo_description ());
    }

    public void decorate_redo_action () {
        decorate_command_manager_action ("CommonRedo", Resources.REDO_LABEL, "",
                                         get_command_manager ().get_redo_description ());
    }

    private void on_undo () {
        command_manager.undo ();
    }

    private void on_redo () {
        command_manager.redo ();
    }

    private void on_select_all () {
        Page? page = get_current_page () as CheckerboardPage;
        if (page != null)
            page.get_view ().select_all ();
    }

    private void on_select_none () {
        Page? page = get_current_page () as CheckerboardPage;
        if (page != null)
            page.get_view ().unselect_all ();
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        maximized = (get_window ().get_state () == Gdk.WindowState.MAXIMIZED);

        if (!maximized)
            get_size (out dimensions.width, out dimensions.height);

        return base.configure_event (event);
    }

}
