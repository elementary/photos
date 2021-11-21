/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
*               2009-2013 Yorba Foundation
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

// AppWindow is the parent window for most windows in Photos (FullscreenWindow is the exception).
// There are multiple types of AppWindows (LibraryWindow, DirectWindow) for different tasks, but only
// one AppWindow may exist per process.  Thus, if the user closes an AppWindow, the program exits.
//
// AppWindow also offers support for going into fullscreen mode.  It handles the interface
// notifications Page is expecting when switching back and forth.
public abstract class AppWindow : PageWindow {
    protected static AppWindow instance = null;

    private static FullscreenWindow fullscreen_window = null;
    private static CommandManager command_manager = null;

    // the AppWindow maintains its own UI manager because the first UIManager an action group is
    // added to is the one that claims its accelerators
    protected Gtk.ActionGroup[] common_action_groups;
    protected Dimensions dimensions;
    private int pos_x = 0;
    private int pos_y = 0;
    protected Hdy.HeaderBar header;

    protected Gtk.Button redo_btn;
    protected Gtk.Button undo_btn;

    protected GLib.Settings window_settings;

    public const string ACTION_PREFIX = "win.";
    public const string ACTION_FULLSCREEN = "action_fullscreen";
    public const string ACTION_JUMP_TO_FILE = "action_jump_to_file";
    public const string ACTION_QUIT = "action_quit";
    public const string ACTION_REDO = "action_redo";
    public const string ACTION_SELECT_ALL = "action_select_all";
    public const string ACTION_SELECT_NONE = "action_select_none";
    public const string ACTION_UNDO = "action_undo";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_FULLSCREEN, on_fullscreen },
        { ACTION_JUMP_TO_FILE, on_jump_to_file },
        { ACTION_QUIT, on_quit },
        { ACTION_REDO, on_redo },
        { ACTION_SELECT_ALL, on_select_all },
        { ACTION_SELECT_NONE, on_select_none },
        { ACTION_UNDO, on_undo }
    };

    protected AppWindow () {
        // although there are multiple AppWindow types, only one may exist per-process
        assert (instance == null);
        instance = this;
    }

    construct {
        assert (command_manager == null);
        command_manager = new CommandManager ();
        command_manager.altered.connect (on_command_manager_altered);

        redo_btn = new Gtk.Button.from_icon_name ("edit-redo", Gtk.IconSize.LARGE_TOOLBAR);
        redo_btn.action_name = ACTION_PREFIX + ACTION_REDO;

        undo_btn = new Gtk.Button.from_icon_name ("edit-undo", Gtk.IconSize.LARGE_TOOLBAR);
        undo_btn.action_name = ACTION_PREFIX + ACTION_UNDO;

        header = new Hdy.HeaderBar ();
        header.show_close_button = true;

        icon_name = "multimedia-photo-manager";
        title = _(Resources.APP_TITLE);

        add_action_entries (ACTION_ENTRIES, this);

        weak Photos.Application application_instance = ((Photos.Application) GLib.Application.get_default ());
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_FULLSCREEN, {"F11"});
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_JUMP_TO_FILE, {"<Ctrl><Shift>M"});
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_QUIT, {"<Ctrl>Q"});
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_REDO, {"<Ctrl><Shift>Z"});
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_SELECT_ALL, {"<Ctrl>A"});
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_SELECT_NONE, {"<Ctrl><Shift>A"});
        application_instance.set_accels_for_action (ACTION_PREFIX + ACTION_UNDO, {"<Ctrl>Z"});

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("io/elementary/photos/application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        window_settings = new GLib.Settings (GSettingsConfigurationEngine.WINDOW_PREFS_SCHEMA_NAME);

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
    }

    protected abstract void on_fullscreen ();

    public static AppWindow get_instance () {
        return instance;
    }

    public static FullscreenWindow get_fullscreen () {
        return fullscreen_window;
    }

    public static void error_message (string title, string? message = null, Gtk.Window? parent = null) {
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            title,
            message,
            "dialog-error",
            Gtk.ButtonsType.CLOSE
        );
        dialog.transient_for = parent ?? get_instance ();
        dialog.run ();
        dialog.destroy ();
    }

    public static Gtk.ResponseType cancel_affirm_question (string message, string affirmative, string? title = null) {
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            title ?? _(Resources.APP_TITLE),
            message,
            "dialog-question",
            Gtk.ButtonsType.CANCEL
        );
        dialog.transient_for = get_instance ();
        dialog.add_button (affirmative, Gtk.ResponseType.YES);
        int response = dialog.run ();
        dialog.destroy ();

        return (Gtk.ResponseType) response;
    }

    public static void database_error (DatabaseError err) {
        panic (_ ("A fatal error occurred when accessing Photos' library. Photos cannot continue.\n\n%s").printf (
                   err.message));
    }

    public static void panic (string msg) {
        critical (msg);
        error_message (msg, null);

        ((Photos.Application) GLib.Application.get_default ()).panic ();
    }

    public abstract string get_app_role ();

    protected virtual void on_quit () {
        ((Photos.Application) GLib.Application.get_default ()).exit ();
    }

    private void on_jump_to_file () {
        if (get_current_page ().get_view ().get_selected_count () != 1)
            return;

        MediaSource? media = get_current_page ().get_view ().get_selected_at (0).source as MediaSource;
        if (media == null)
            return;

        try {
            AppWindow.get_instance ().show_file_uri (media.get_master_file ());
        } catch (Error err) {
            error_message (Resources.jump_to_file_failed (err));
        }
    }

    protected override void destroy () {
        on_quit ();
    }

    private void show_file_uri (File file) throws Error {
        AppInfo app_info = AppInfo.get_default_for_type ("inode/directory", true);
        var file_list = new List<File> ();
        file_list.append (file);
        app_info.launch (file_list, get_window ().get_screen ().get_display ().get_app_launch_context ());
    }

    protected virtual Gtk.ActionGroup[] create_common_action_groups () {
        Gtk.ActionGroup[] groups = new Gtk.ActionGroup[0];
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

        ((SimpleAction) lookup_action (ACTION_SELECT_ALL)).set_enabled (is_checkerboard);
        ((SimpleAction) lookup_action (ACTION_SELECT_NONE)).set_enabled (is_checkerboard);
    }

    // This is a counterpart to Page.update_actions (), but for common GLib.Actions
    // NOTE: Although ACTION_FULLSCREEN is declared here, it's implementation is up to the subclasses,
    // therefore they need to update its action.
    protected virtual void update_common_actions (Page page, int selected_count, int count) {
        if (page is CheckerboardPage) {
            ((SimpleAction) lookup_action (ACTION_SELECT_ALL)).set_enabled (count > 0);
        }

        ((SimpleAction) lookup_action (ACTION_JUMP_TO_FILE)).set_enabled (selected_count == 1);

        on_command_manager_altered ();
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
        decorate_command_manager_action (ACTION_UNDO, undo_btn, _("Undo"), get_command_manager ().get_undo_description ());
        decorate_command_manager_action (ACTION_REDO, redo_btn, _("Redo"), get_command_manager ().get_redo_description ());
    }

    private void decorate_command_manager_action (string name, Gtk.Button button, string default_explanation, CommandDescription? desc) {
        var action = ((SimpleAction) lookup_action (name));
        if (action == null) {
            return;
        }

        if (desc != null) {
            button.tooltip_text = "%s %s".printf (default_explanation, desc.get_command_name ());
            action.set_enabled (true);
        } else {
            button.tooltip_text = default_explanation;
            action.set_enabled (false);
        }
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
        if (!is_maximized)
            get_size (out dimensions.width, out dimensions.height);

        return base.configure_event (event);
    }
}
