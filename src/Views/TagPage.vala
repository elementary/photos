/*
* Copyright (c) 2010-2013 Yorba Foundation
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

public class TagPage : CollectionPage {
    private Tag tag;
    private Gtk.Menu page_sidebar_menu;

    public TagPage (Tag tag) {
        base (tag.get_name ());

        this.tag = tag;

        Tag.global.items_altered.connect (on_tags_altered);
        tag.mirror_sources (get_view (), create_thumbnail);
    }

    ~TagPage () {
        get_view ().halt_mirroring ();
        Tag.global.items_altered.disconnect (on_tags_altered);
    }

    public override Gtk.Menu? get_page_sidebar_menu () {
        if (page_sidebar_menu == null) {
            page_sidebar_menu = new Gtk.Menu ();

            var new_child_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.NEW_CHILD_TAG_SIDEBAR_MENU);
            var new_child_action = get_action ("NewChildTagSidebar");
            new_child_action.bind_property ("sensitive", new_child_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            new_child_menu_item.activate.connect (() => new_child_action.activate ());

            var rename_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.RENAME_TAG_SIDEBAR_MENU);
            var rename_action = get_action ("RenameTagSidebar");
            rename_action.bind_property ("sensitive", rename_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            rename_menu_item.activate.connect (() => rename_action.activate ());

            var delete_menu_item = new Gtk.MenuItem.with_mnemonic (Resources.DELETE_TAG_SIDEBAR_MENU);
            var delete_action = get_action ("DeleteTagSidebar");
            delete_action.bind_property ("sensitive", delete_menu_item, "sensitive", BindingFlags.SYNC_CREATE);
            delete_menu_item.activate.connect (() => delete_action.activate ());

            page_sidebar_menu.add (new_child_menu_item);
            page_sidebar_menu.add (new Gtk.SeparatorMenuItem ());
            page_sidebar_menu.add (rename_menu_item);
            page_sidebar_menu.add (delete_menu_item);
            page_sidebar_menu.show_all ();
        }

        return page_sidebar_menu;
    }

    public Tag get_tag () {
        return tag;
    }

    protected override void get_config_photos_sort (out bool sort_order, out int sort_by) {
        sort_order = ui_settings.get_boolean ("event-photos-sort-ascending");
        sort_by = ui_settings.get_int ("event-photos-sort-by");
    }

    protected override void set_config_photos_sort (bool sort_order, int sort_by) {
        ui_settings.set_boolean ("event-photos-sort-ascending", sort_order);
        ui_settings.set_int ("event-photos-sort-by", sort_by);
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry delete_tag = { "DeleteTag", null, TRANSLATABLE, null, null, on_delete_tag };
        // label and tooltip are assigned when the menu is displayed
        actions += delete_tag;

        Gtk.ActionEntry rename_tag = { "RenameTag", null, TRANSLATABLE, null, null, on_rename_tag };
        // label and tooltip are assigned when the menu is displayed
        actions += rename_tag;

        Gtk.ActionEntry remove_tag = { "RemoveTagFromPhotos", null, TRANSLATABLE, null, null,
                                       on_remove_tag_from_photos
                                     };
        // label and tooltip are assigned when the menu is displayed
        actions += remove_tag;

        Gtk.ActionEntry delete_tag_sidebar = { "DeleteTagSidebar", null, Resources.DELETE_TAG_SIDEBAR_MENU,
                                               null, null, on_delete_tag
                                             };
        actions += delete_tag_sidebar;

        Gtk.ActionEntry rename_tag_sidebar = { "RenameTagSidebar", null, Resources.RENAME_TAG_SIDEBAR_MENU,
                                               null, null, on_rename_tag
                                             };
        actions += rename_tag_sidebar;

        Gtk.ActionEntry new_child_tag_sidebar = { "NewChildTagSidebar", null, Resources.NEW_CHILD_TAG_SIDEBAR_MENU,
                                                  null, null, on_new_child_tag_sidebar
                                                };
        actions += new_child_tag_sidebar;

        return actions;
    }

    private void on_tags_altered (Gee.Map<DataObject, Alteration> map) {
        if (map.has_key (tag)) {
            page_name = tag.get_name ();
            update_actions (get_view ().get_selected_count (), get_view ().get_count ());
        }
    }

    protected override void update_actions (int selected_count, int count) {
        set_action_details ("DeleteTag",
                            Resources.delete_tag_menu (tag.get_user_visible_name ()),
                            null,
                            true);

        set_action_details ("RenameTag",
                            Resources.rename_tag_menu (tag.get_user_visible_name ()),
                            null,
                            true);

        set_action_details ("RemoveTagFromPhotos",
                            Resources.untag_photos_menu (tag.get_user_visible_name (), selected_count),
                            null,
                            selected_count > 0);

        base.update_actions (selected_count, count);
    }

    private void on_new_child_tag_sidebar () {
        NewChildTagCommand creation_command = new NewChildTagCommand (tag);

        AppWindow.get_command_manager ().execute (creation_command);

        LibraryWindow.get_app ().rename_tag_in_sidebar (creation_command.get_created_child ());
    }

    private void on_rename_tag () {
        LibraryWindow.get_app ().rename_tag_in_sidebar (tag);
    }

    private void on_delete_tag () {
        if (Dialogs.confirm_delete_tag (tag))
            AppWindow.get_command_manager ().execute (new DeleteTagCommand (tag));
    }

    private void on_remove_tag_from_photos () {
        if (get_view ().get_selected_count () > 0) {
            get_command_manager ().execute (new TagUntagPhotosCommand (tag,
                                           (Gee.Collection<MediaSource>) get_view ().get_selected_sources (),
                                           get_view ().get_selected_count (), false));
        }
    }
}
