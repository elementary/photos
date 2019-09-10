/*
* Copyright (c) 2011-2014 Yorba Foundation
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

private class LibraryProperties : Properties {
    private MediaSource? media_source;
    private string comment;
    private Gtk.Entry tags_entry;
    private PlaceHolderTextView comment_entry;
    private bool is_media;
    private string tags;

    public LibraryProperties () {
        Tag.global.container_contents_altered.connect (on_tag_contents_altered);
    }

    ~LibraryProperties () {
        Tag.global.container_contents_altered.disconnect (on_tag_contents_altered);
    }

    protected override void clear_properties () {
        base.clear_properties ();
        comment = "";
        tags = "";
        is_media = false;
    }
    public override void update_properties (Page page) {
        internal_update_properties (page);
        show_all ();
    }

    protected override void get_single_properties (DataView view) {
        base.get_single_properties (view);

        var source = view.source as MediaSource;

        if (source != media_source) {
            save_changes_to_source ();
        }

        clear_properties ();
        media_source = source;

        Flaggable? flaggable = media_source as Flaggable;
        if (media_source != null && flaggable != null) {
            tags = get_initial_tag_text (media_source);
            comment = media_source.get_comment ();
            is_media = true;
        }
    }

    protected override void internal_update_properties (Page page) {
        base.internal_update_properties (page);
        row_spacing = 12;

        if (is_media) {
            comment_entry = new PlaceHolderTextView (comment, _("Comment"));
            comment_entry.wrap_mode = Gtk.WrapMode.WORD;
            comment_entry.height_request = 50;

            var frame = new Gtk.Frame (null);
            frame.hexpand = true;
            frame.add (comment_entry);

            tags_entry = new Gtk.Entry ();
            tags_entry.placeholder_text = _("Tags, separated by commas");
            if (tags != null) {
                tags_entry.text = tags;
            }

            attach (frame, 0, 0, 1, 1);
            attach (tags_entry, 0, 1, 1, 1);

            tags_entry.changed.connect (tags_entry_changed);
            tags_entry.activate.connect (tags_entry_activate);
        }
    }

    private void tags_entry_changed () {
        tags = tags_entry.get_text ();
    }

    private void tags_entry_activate () {
        tags = tags_entry.get_text ();
        save_changes_to_source ();
    }

    public override void save_changes_to_source () {
        if (media_source != null && is_media) {
            comment = comment_entry.get_text ().strip ();

            if (comment != null && comment != media_source.get_comment ()) {
                AppWindow.get_command_manager ().execute (new EditCommentCommand (media_source, comment));
            }

            Gee.ArrayList<Tag>? new_tags = tag_entry_to_array ();

            if (new_tags != null && tags != get_initial_tag_text (media_source)) {
                AppWindow.get_command_manager ().execute (new ModifyTagsCommand (media_source, new_tags));
            }
        }
    }

    private static string? get_initial_tag_text (MediaSource source) {
        Gee.Collection<Tag>? source_tags = Tag.global.fetch_for_source (source);
        if (source_tags == null)
            return null;

        Gee.Collection<Tag> terminal_tags = Tag.get_terminal_tags (source_tags);

        Gee.SortedSet<string> tag_basenames = new Gee.TreeSet<string> ();
        foreach (Tag tag in terminal_tags)
            tag_basenames.add (HierarchicalTagUtilities.get_basename (tag.get_path ()));

        string? text = null;
        foreach (string name in tag_basenames) {
            if (text == null) {
                text = "";
            } else {
                text += ", ";
            }

            text += name;
        }

        return text;
    }

    private Gee.ArrayList<Tag>? tag_entry_to_array () {
        string? text = tags;
        if (text == null)
            return null;

        Gee.ArrayList<Tag> new_tags = new Gee.ArrayList<Tag> ();

        // return empty list if no tags specified
        if (is_string_empty (text))
            return new_tags;

        // break up by comma-delimiter, prep for use, and separate into list
        string[] tag_names = Tag.prep_tag_names (text.split (","));

        tag_names = HierarchicalTagIndex.get_global_index ().get_paths_for_names_array (tag_names);

        foreach (string name in tag_names)
            new_tags.add (Tag.for_path (name));

        return new_tags;
    }

    private void on_tag_contents_altered (ContainerSource container, Gee.Collection<DataSource>? added,
                                          bool relinking, Gee.Collection<DataSource>? removed, bool unlinking) {
        Flaggable? flaggable = media_source as Flaggable;
        if (media_source != null && flaggable != null) {
            tags = get_initial_tag_text (media_source);
            if (tags != null)
                tags_entry.text = tags;
            else
                tags_entry.text = "";
        }
    }

    private class PlaceHolderTextView : Gtk.TextView {
        public string placeholder_text;
        private Gtk.TextBuffer placeholder_buffer = new Gtk.TextBuffer (null);
        public Gtk.TextBuffer original_buffer = new Gtk.TextBuffer (null);

        public PlaceHolderTextView (string? text, string placeholder_text) {
            this.placeholder_buffer.text = this.placeholder_text = placeholder_text;
            if (text == null || text == "") {
                this.buffer = placeholder_buffer;
                this.original_buffer.text = "";
            } else {
                this.buffer = original_buffer;
                this.buffer.text = text;
            }

            this.focus_in_event.connect (focus_in);
            this.focus_out_event.connect (focus_out);
            this.paste_clipboard.connect (() => {
                if (this.buffer.has_selection) {
                    this.buffer.delete_selection (true, true);
                }

                var clipboard = Gtk.Clipboard.get_for_display (Gdk.Display.get_default (),
                                    Gdk.SELECTION_PRIMARY);
                this.buffer.text = clipboard.wait_for_text ();
            });
        }

        public string get_text () {
            if (original_buffer != null && original_buffer.text != null)
                return original_buffer.text;
            else {
                return "";
            }
        }

        private bool focus_in (Gdk.EventFocus event) {
            this.buffer = original_buffer;
            return false;
        }

        private bool focus_out (Gdk.EventFocus event) {
            if (this.buffer.text == null || this.buffer.text == "")
                this.buffer = placeholder_buffer;
            return false;
        }
    }
}
