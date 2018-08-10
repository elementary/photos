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
    protected int pos_x = 0;
    protected int pos_y = 0;
    protected Gtk.HeaderBar header;

    private Gtk.ActionGroup common_action_group = new Gtk.ActionGroup ("AppWindowGlobalActionGroup");

    private Gtk.Button redo_btn;
    private Gtk.Button undo_btn;

    protected GLib.Settings window_settings;

    public const string ACTION_PREFIX = "win.";
    public const string ACTION_JUMP_TO_FILE = "action_jump_to_file";
    public const string ACTION_QUIT = "action_quit";

    private const ActionEntry[] action_entries = {
        { ACTION_JUMP_TO_FILE, on_jump_to_file },
        { ACTION_QUIT, on_quit }
    };

    construct {
        add_action_entries (action_entries, this);

        Application.get_instance ().set_accels_for_action (ACTION_JUMP_TO_FILE + ACTION_QUIT, {"<Ctrl><Shift>M"});
        Application.get_instance ().set_accels_for_action (ACTION_PREFIX + ACTION_QUIT, {"<Ctrl>Q"});

        window_settings = new GLib.Settings (GSettingsConfigurationEngine.WINDOW_PREFS_SCHEMA_NAME);
    }

    public AppWindow () {
        // although there are multiple AppWindow types, only one may exist per-process
        assert (instance == null);
        instance = this;
        icon_name = "multimedia-photo-manager";

        header = new Gtk.HeaderBar ();
        header.set_show_close_button (true);
        this.set_titlebar (header);

        title = _(Resources.APP_TITLE);

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("io/elementary/photos/application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var maximized = false;

        // restore previous size and maximization state
        if (this is LibraryWindow) {
            maximized = window_settings.get_boolean ("library-maximize");
            dimensions.width = window_settings.get_int ("library-width");
            dimensions.height = window_settings.get_int ("library-height");
        } else {
            assert (this is DirectWindow);
            maximized = window_settings.get_boolean ("direct-maximize");
            dimensions.width = window_settings.get_int ("direct-width");
            dimensions.height = window_settings.get_int ("direct-height");
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

    protected virtual void build_header_bar () {
        redo_btn = new Gtk.Button ();
        redo_btn.related_action = get_common_action ("CommonRedo");
        redo_btn.image = new Gtk.Image.from_icon_name ("edit-redo", Gtk.IconSize.LARGE_TOOLBAR);

        undo_btn = new Gtk.Button ();
        undo_btn.related_action = get_common_action ("CommonUndo");
        undo_btn.image = new Gtk.Image.from_icon_name ("edit-undo", Gtk.IconSize.LARGE_TOOLBAR);


        header.pack_end (redo_btn);
        header.pack_end (undo_btn);
    }

    private Gtk.ActionEntry[] create_common_actions () {
        Gtk.ActionEntry fullscreen = { "CommonFullscreen", null, _("Fulls_creen"), "F11", _("Fulls_creen"), on_fullscreen };
        Gtk.ActionEntry undo = { "CommonUndo", null, null, "<Ctrl>Z", null, on_undo };
        Gtk.ActionEntry redo = { "CommonRedo", null, null, "<Ctrl><Shift>Z", null, on_redo };
        Gtk.ActionEntry select_all = { "CommonSelectAll", null, Resources.SELECT_ALL_MENU, "<Ctrl>A", Resources.SELECT_ALL_MENU, on_select_all };
        Gtk.ActionEntry select_none = { "CommonSelectNone", null, null, "<Ctrl><Shift>A", TRANSLATABLE, on_select_none };

        Gtk.ActionEntry[] actions = new Gtk.ActionEntry[0];
        actions += fullscreen;
        actions += undo;
        actions += redo;
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

    public static Gtk.Builder create_builder () {
        Gtk.Builder builder = new Gtk.Builder ();
        try {
            builder.add_from_resource ("/io/elementary/photos/shotwell.ui");
            builder.connect_signals (null);
        } catch (GLib.Error error) {
            warning ("Unable to create Gtk.Builder: %s\n", error.message);
        }

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
        panic (_ ("A fatal error occurred when accessing Photos' library.  Photos cannot continue.\n\n%s").printf (
                   err.message));
    }

    public static void panic (string msg) {
        critical (msg);
        error_message (msg);

        Application.get_instance ().panic ();
    }

    public abstract string get_app_role ();

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
        ((SimpleAction) lookup_action (ACTION_JUMP_TO_FILE)).set_enabled (selected_count == 1);

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

    private void decorate_command_manager_action (string name, Gtk.Button button, string default_explanation, CommandDescription? desc) {
        Gtk.Action? action = get_common_action (name);
        if (action == null) {
            return;
        }

        if (desc != null) {
            button.tooltip_text = "%s %s".printf (default_explanation, desc.get_name ());
            action.sensitive = true;
        } else {
            button.tooltip_text = default_explanation;
            action.sensitive = false;
        }
    }

    public void decorate_undo_action () {
        decorate_command_manager_action ("CommonUndo", undo_btn, _("Undo"), get_command_manager ().get_undo_description ());
    }

    public void decorate_redo_action () {
        decorate_command_manager_action ("CommonRedo", redo_btn, _("Redo"), get_command_manager ().get_redo_description ());
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
