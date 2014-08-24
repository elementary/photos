/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class LibraryProperties : Properties {
    private Rating rating = Rating.UNRATED;
    private MediaSource? media_source;
    private string comment;
    private Gtk.Entry title_entry;
    private Gtk.Entry tags_entry;
    private PlaceHolderTextView comment_entry;
    private bool is_media;
    private string title;
    private string tags;
    private bool is_flagged = false;
    private Gtk.ToggleButton toolbtn_flag = null;

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
        rating = Rating.UNRATED;
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
            rating = media_source.get_rating ();
            if (flaggable != null)
                is_flagged = flaggable.is_flagged ();
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
            add_entry_line ("Title", title_entry);

            comment_entry = new PlaceHolderTextView (comment, "Comment");
            comment_entry.set_wrap_mode (Gtk.WrapMode.WORD);
            comment_entry.set_size_request (-1, 50);
            // textview in sidebar css class for non entry we make an exception
            comment_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_ENTRY);
            add_entry_line ("Comment", comment_entry);

            var rating_widget = new PhotoRatingWidget (true, 15);
            rating_widget.rating = Resources.rating_int (rating);
            rating_widget.rating_changed.connect (rating_widget_changed);

            var spacerrate = new Gtk.Grid ();
            spacerrate.set_size_request (50, -1);
            spacerrate.hexpand = true;

            toolbtn_flag = new Gtk.ToggleButton ();
            toolbtn_flag.image = new Gtk.Image.from_icon_name (Resources.EDIT_FLAG, Gtk.IconSize.MENU);
            toolbtn_flag.halign = Gtk.Align.END;
            toolbtn_flag.valign = Gtk.Align.END;
            toolbtn_flag.set_active (is_flagged);
            toolbtn_flag.clicked.connect (flag_btn_clicked);
            update_flag_action ();

            var rate_grid = new Gtk.Grid ();
            rate_grid.hexpand = true;
            rate_grid.set_size_request (125, 15);

            rate_grid.attach (rating_widget, 0, 0, 1, 1);
            rate_grid.attach (spacerrate, 1, 0, 1, 1);
            rate_grid.attach (toolbtn_flag , 2, 0, 1, 1);
            attach (rate_grid, 0, (int) line_count, 1, 1);
            line_count++;

            var spacer = new Gtk.Grid ();
            spacer.set_size_request (100, 15);
            attach (spacer, 0, (int) line_count, 1, 1);
            line_count++;

            tags_entry = new Gtk.Entry ();
            if (tags != null)
                tags_entry.text = tags;
            tags_entry.changed.connect (tags_entry_changed);
            add_entry_line ("Tags, seperated by commas", tags_entry);
        }
    }

    private void rating_widget_changed (int rating) {
        save_changes_to_source ();
        if (media_source != null) {
            SetRatingSingleCommand command = new SetRatingSingleCommand (
                media_source, Resources.int_to_rating (rating));

            AppWindow.get_command_manager ().execute (command);
        }
    }

    private void flag_btn_clicked () {
        save_changes_to_source ();
        Flaggable? flaggable = media_source as Flaggable;

        if (flaggable != null) {
            if (flaggable.is_flagged ())
                flaggable.mark_unflagged ();
            else
                flaggable.mark_flagged ();
        }
        update_flag_action ();
    }

    private void update_flag_action () {
        if (toolbtn_flag.active)
            toolbtn_flag.tooltip_text = Resources.UNFLAG_LABEL;
        else
            toolbtn_flag.tooltip_text = Resources.FLAG_LABEL;
    }

    private void title_entry_changed () {
        title = title_entry.get_text ();
    }

    private void tags_entry_changed () {
        tags = tags_entry.get_text ();
    }

    public override void save_changes_to_source () {
        if (media_source != null && is_media) {
            comment = comment_entry.get_text ();
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