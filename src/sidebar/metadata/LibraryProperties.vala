/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class LibraryProperties : Properties {
    private MediaSource? media_source;
    private string comment;
    private Gtk.Entry title_entry;
    private Gtk.Entry tags_entry;
    private PlaceHolderTextView comment_entry;
    private bool is_media;
    private string title;
    private string tags;

    public LibraryProperties () {
        set_column_homogeneous (true);
        Tag.global.container_contents_altered.connect (on_tag_contents_altered);
    }

    ~LibraryProperties () {
        Tag.global.container_contents_altered.disconnect (on_tag_contents_altered);
    }

    public override string get_header_title () {
        return Resources.LIBRARY_PROPERTIES_LABEL;
    }

    protected override void clear_properties () {
        base.clear_properties ();
        comment = "";
        title = "";
        tags = "";
        is_media = false;
    }
    public override void update_properties (Page page) {
        internal_update_properties (page);
        show_all ();
    }

    protected override void get_single_properties (DataView view) {
        base.get_single_properties (view);

        MediaSource source = view.get_source () as MediaSource;
        if (source != media_source)
            save_changes_to_source ();

        clear_properties ();
        media_source = source;

        Flaggable? flaggable = media_source as Flaggable;
        if (media_source != null && flaggable != null) {
            tags = get_initial_tag_text (media_source);
            title = media_source.get_name ();
            comment = media_source.get_comment ();
            is_media = true;
        }
    }

    protected override void internal_update_properties (Page page) {
        base.internal_update_properties (page);

        if (is_media) {
            title_entry = new Gtk.Entry ();
            if (title != null)
                title_entry.set_text (title);
            title_entry.changed.connect (title_entry_changed);
            add_entry_line (_("Title"), title_entry);

            comment_entry = new PlaceHolderTextView (comment, _("Comment"));
            comment_entry.set_wrap_mode (Gtk.WrapMode.WORD);
            comment_entry.set_size_request (-1, 50);
            // textview in sidebar css class for non entry we make an exception
            comment_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_ENTRY);
            add_entry_line (_("Comment"), comment_entry);

            var spacerrate = new Gtk.Grid ();
            spacerrate.set_size_request (50, -1);
            spacerrate.hexpand = true;

            tags_entry = new Gtk.Entry ();
            if (tags != null)
                tags_entry.text = tags;
            tags_entry.changed.connect (tags_entry_changed);
            tags_entry.activate.connect (tags_entry_activate);
            add_entry_line (_("Tags, separated by commas"), tags_entry);
        }
    }

    private void title_entry_changed () {
        title = title_entry.get_text ();
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
            if (title != null && title != media_source.get_name ())
                AppWindow.get_command_manager ().execute (new EditTitleCommand (media_source, title));
            if (comment != null && comment != media_source.get_comment ())
                AppWindow.get_command_manager ().execute (new EditCommentCommand (media_source, comment));
            Gee.ArrayList<Tag>? new_tags = tag_entry_to_array ();
            if (new_tags != null && tags != get_initial_tag_text (media_source))
                AppWindow.get_command_manager ().execute (new ModifyTagsCommand (media_source, new_tags));
        }
    }

    private void add_entry_line (string label_text, Gtk.Widget entry) {
        Gtk.Entry text_entry = entry as Gtk.Entry;
        if (text_entry != null)
            text_entry.placeholder_text = label_text;
        entry.tooltip_text = label_text;

        attach (entry, 0, (int) line_count, 1, 1);
        line_count++;

        var spacer = new Gtk.Grid ();
        spacer.set_size_request (100, 15);
        attach (spacer, 0, (int) line_count, 1, 1);
        line_count++;
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
            if (text == null)
                text = "";
            else
                text += ", ";

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
