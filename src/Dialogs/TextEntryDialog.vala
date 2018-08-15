/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017-2018 elementary, Inc. (https://elementary.io)
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
    public string initial_text { get; construct; }
    public string label { get; construct; }
    public Gee.Collection<string>? completion_list { get; construct; }
    public string? completion_delimiter { get; construct; }

    public delegate bool OnModifyValidateType (string text);

    private unowned OnModifyValidateType on_modify_validate;
    private Gtk.Entry entry;

    public TextEntryDialog (OnModifyValidateType? modify_validate, string title, string label,
string? initial_text, Gee.Collection<string>? completion_list, string? completion_delimiter) {
        Object (
            completion_delimiter: completion_delimiter,
            completion_list: completion_list,
            initial_text: initial_text,
            label: label,
            title: title
        );

        on_modify_validate = modify_validate;
    }

    construct {
        var name_label = new Gtk.Label (label);
        name_label.halign = Gtk.Align.START;
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        entry = new Gtk.Entry ();
        entry.hexpand = true;
        entry.text = initial_text != null ? initial_text : "";
        entry.grab_focus ();

        if (completion_list != null) { // Textfield with autocompletion
            entry.completion = new EntryMultiCompletion (completion_list, completion_delimiter);
        }

        var grid = new Gtk.Grid ();
        grid.margin_start = grid.margin_end = 6;
        grid.margin_bottom = 18;
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.add (name_label);
        grid.add (entry);

        get_content_area ().add (grid);

        add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
        add_button (_("_Save"), Gtk.ResponseType.OK);

        deletable = false;
        resizable = false;
        transient_for = AppWindow.get_instance ();
        set_default_size (350, 104);
        set_default_response (Gtk.ResponseType.OK);

        entry.changed.connect (on_entry_changed);
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

    private void on_entry_changed () {
        set_response_sensitive (Gtk.ResponseType.OK, on_modify_validate (entry.get_text ()));
    }
}
