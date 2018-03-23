// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class TransitionEffectSelector : Gtk.ToolItem {
    private Gtk.ListBox effect_list_box;
    private GLib.Settings slideshow_settings;
    private TransitionEffectsManager effect_manager;

    construct {
        slideshow_settings = new GLib.Settings (GSettingsConfigurationEngine.SLIDESHOW_PREFS_SCHEMA_NAME);
        effect_manager = TransitionEffectsManager.get_instance ();

        valign = Gtk.Align.CENTER;

        var selected_effect = effect_manager.get_effect_name (slideshow_settings.get_string ("transition-effect-id"));

        var effect_list_store = new GLib.ListStore (typeof (ListStoreItem));

        foreach (var id in effect_manager.get_effect_ids ()) {
            var name = effect_manager.get_effect_name (id);
            effect_list_store.append (new ListStoreItem (id, name));
        }

        effect_list_store.sort ((a, b) => {
            if (((ListStoreItem)a).id == TransitionEffectsManager.NULL_EFFECT_ID) {
                return -1;
            }

            if (((ListStoreItem)b).id == TransitionEffectsManager.NULL_EFFECT_ID) {
                return 1;
            }

            return ((ListStoreItem)a).name.collate (((ListStoreItem)b).name);
        });

        var effect_label = new Gtk.Label (selected_effect);
        effect_label.hexpand = true;
        effect_label.xalign = 0;

        var button_grid = new Gtk.Grid ();
        button_grid.column_spacing = 6;
        button_grid.valign = Gtk.Align.CENTER;
        button_grid.add (effect_label);
        button_grid.add (new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.MENU));

        var button = new Gtk.ToggleButton ();
        button.width_request = 175;
        button.tooltip_text = _("Transition Effect");
        button.add (button_grid);

        var popover = new Gtk.Popover (button);

        effect_list_box = new Gtk.ListBox ();
        effect_list_box.bind_model (effect_list_store, (item) => {
            return new LayoutRow ((item as ListStoreItem).name);
        });

        effect_list_box.row_activated.connect ((row) => {
            var item = effect_list_store.get_item (row.get_index ()) as ListStoreItem;
            if (item != null) {
                effect_label.label = item.name;
                slideshow_settings.set_string ("transition-effect-id", item.id);
            }

            popover.hide ();
        });

        var layout_scrolled = new Gtk.ScrolledWindow (null, null);
        layout_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        layout_scrolled.expand = true;
        layout_scrolled.margin_top = layout_scrolled.margin_bottom = 3;
        layout_scrolled.add (effect_list_box);

        popover.height_request = 300;
        popover.width_request = 200;
        popover.closed.connect (() => {
            AppWindow.get_fullscreen ().auto_dismiss_toolbar = true;
            button.active = false;
        });

        popover.position = Gtk.PositionType.TOP;
        popover.add (layout_scrolled);

        button.toggled.connect (() => {
            if (button.active) {
                popover.relative_to = button;
                popover.show_all ();
                AppWindow.get_fullscreen ().auto_dismiss_toolbar = false;
            } else {
                popover.hide ();
            }
        });

        add (button);
    }

    private class ListStoreItem : Object {
        public string id;
        public string name;

        public ListStoreItem (string id, string name) {
            this.id = id;
            this.name = name;
        }
    }

    private class LayoutRow : Gtk.ListBoxRow {
        public LayoutRow (string name) {
            var label = new Gtk.Label (name);
            label.xalign = 0;
            add (label);
            get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
        }
    }
}
