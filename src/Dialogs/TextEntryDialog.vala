/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary  LLC. (https://github.com/elementary/photos)
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

public class TextEntryDialog : Gtk.Dialog {
    public delegate bool OnModifyValidateType (string text);

    private unowned OnModifyValidateType on_modify_validate;
    private Gtk.Entry entry;
    private Gtk.Builder builder;
    private Gtk.Button button1;
    private Gtk.Button button2;
    private Gtk.ButtonBox action_area_box;

    public void set_builder (Gtk.Builder builder) {
        this.builder = builder;
    }

    public void setup (OnModifyValidateType? modify_validate, string title, string label,
                       string? initial_text, Gee.Collection<string>? completion_list, string? completion_delimiter) {
        set_title (title);
        set_resizable (true);
        set_deletable (false);
        set_default_size (350, 104);
        set_parent_window (AppWindow.get_instance ().get_parent_window ());
        set_transient_for (AppWindow.get_instance ());
        on_modify_validate = modify_validate;

        Gtk.Label name_label = builder.get_object ("label") as Gtk.Label;
        name_label.set_text (label);

        entry = builder.get_object ("entry") as Gtk.Entry;
        entry.set_text (initial_text != null ? initial_text : "");
        entry.grab_focus ();
        entry.changed.connect (on_entry_changed);

        action_area_box = (Gtk.ButtonBox) get_action_area ();
        action_area_box.set_layout (Gtk.ButtonBoxStyle.END);

        button1 = (Gtk.Button) add_button (_ ("_Cancel"), Gtk.ResponseType.CANCEL);
        button2 = (Gtk.Button) add_button (_ ("_Save"), Gtk.ResponseType.OK);
        set_default_response (Gtk.ResponseType.OK);

        if (completion_list != null) { // Textfield with autocompletion
            EntryMultiCompletion completion = new EntryMultiCompletion (completion_list,
                    completion_delimiter);
            entry.set_completion (completion);
        }

        set_default_response (Gtk.ResponseType.OK);
        set_has_resize_grip (false);
    }

    public string? execute () {
        string? text = null;

        // validate entry to start with
        set_response_sensitive (Gtk.ResponseType.OK, on_modify_validate (entry.get_text ()));

        show_all ();

        if (run () == Gtk.ResponseType.OK)
            text = entry.get_text ();

        entry.changed.disconnect (on_entry_changed);
        destroy ();

        return text;
    }

    public void on_entry_changed () {
        set_response_sensitive (Gtk.ResponseType.OK, on_modify_validate (entry.get_text ()));
    }
}
