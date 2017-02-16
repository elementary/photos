/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary  LLC. (https://launchpad.net/pantheon-photos)
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

public class MultiTextEntryDialog : Gtk.Dialog {
    public delegate bool OnModifyValidateType (string text);

    private unowned OnModifyValidateType on_modify_validate;
    private Gtk.TextView entry;
    private Gtk.Builder builder;
    private Gtk.Button button1;
    private Gtk.Button button2;
    private Gtk.ButtonBox action_area_box;

    public void set_builder (Gtk.Builder builder) {
        this.builder = builder;
    }

    public void setup (OnModifyValidateType? modify_validate, string title, string label, string? initial_text) {
        set_title (title);
        set_resizable (true);
        set_deletable (false);
        set_default_size (500, 300);
        set_parent_window (AppWindow.get_instance ().get_parent_window ());
        set_transient_for (AppWindow.get_instance ());
        on_modify_validate = modify_validate;

        Gtk.Label name_label = builder.get_object ("label9") as Gtk.Label;
        name_label.set_text (label);

        Gtk.ScrolledWindow scrolled = builder.get_object ("scrolledwindow1") as Gtk.ScrolledWindow;
        scrolled.set_shadow_type (Gtk.ShadowType.ETCHED_IN);

        entry = builder.get_object ("textview1") as Gtk.TextView;
        entry.set_wrap_mode (Gtk.WrapMode.WORD);
        entry.buffer = new Gtk.TextBuffer (null);
        entry.buffer.text = (initial_text != null ? initial_text : "");

        entry.grab_focus ();

        action_area_box = (Gtk.ButtonBox) get_action_area ();
        action_area_box.set_layout (Gtk.ButtonBoxStyle.END);

        button1 = (Gtk.Button) add_button (_ ("_Cancel"), Gtk.ResponseType.CANCEL);
        button2 = (Gtk.Button) add_button (_ ("_Save"), Gtk.ResponseType.OK);

        set_has_resize_grip (true);
    }

    public string? execute () {
        string? text = null;

        show_all ();

        if (run () == Gtk.ResponseType.OK)
            text = entry.buffer.text;

        destroy ();

        return text;
    }
}
