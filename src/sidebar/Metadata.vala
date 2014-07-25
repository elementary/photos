/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class MetadataView : Gtk.ScrolledWindow {
    private List<Properties> properties_collection = new List<Properties> ();
    private Gtk.Notebook notebook = new Gtk.Notebook();
	private Gtk.Grid grid = new Gtk.Grid ();
	private int line_count = 0;
	private BasicProperties colletion_page_properties = new BasicProperties ();

	public MetadataView () {
		set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);

        properties_collection.append (new LibraryProperties ());
        properties_collection.append (new BasicProperties ());
        properties_collection.append (new ExtendedProperties ());

        foreach(var properties in properties_collection)
            add_expander (properties);
		grid.set_row_spacing (16);
		grid.margin = 5;
        this.add(notebook);
		notebook.append_page(grid);
        notebook.append_page(colletion_page_properties);	
        notebook.set_show_tabs(false);
        grid.hexpand = true;
	}
	
	private void add_expander (Properties properties) {
		var expander = new Gtk.Expander ("<b>" + properties.get_header_title () + "</b>");
		expander.use_markup = true;
		expander.add (properties);
		expander.set_spacing (10);
		grid.attach (expander, 0, line_count, 1, 1);	
		line_count++;
        expander.set_expanded (true);
	} 
	
	public void update_properties (Page page) {
        //figure out if we have a single image selected
        ViewCollection view = page.get_view();
        bool display_single = false;

        if (view == null)
            return;

        int count = view.get_selected_count();
        Gee.Iterable<DataView> iter = null;
        if (count != 0) {
            iter = view.get_selected();
        } else {
            count = view.get_count();
            iter = (Gee.Iterable<DataView>) view.get_all();
        }
        
        if (iter == null || count == 0)
            return;

        if (count == 1) {
            foreach (DataView item in iter) {
                var source = item.get_source() as MediaSource;
                if(source == null)
                    display_single = true;
                break;
            }
        }
        else {
            display_single = true;
        }
        int page_num = 0;

        if (display_single)
        {
            colletion_page_properties.update_properties(page);
            page_num = notebook.page_num(colletion_page_properties);
        }
        else {
            foreach(var properties in properties_collection)
            properties.update_properties (page);    
            page_num = notebook.page_num(grid);
        }
        notebook.set_current_page(page_num);
    }
}

public class LibraryProperties : Properties {
	private Rating rating = Rating.UNRATED;
	private MediaSource? media_source;
	private string comment;
    private Gtk.Entry title_entry;
	private Gtk.Entry tags_entry;
    Gtk.TextView comment_entry;
    private bool is_media;
    private string title;
    private string tags;
    private bool is_flagged = false;
	public LibraryProperties () {	
        set_column_homogeneous(true);
	}

    public override string get_header_title() {
        return Resources.LIBRARY_PROPERTIES_LABEL;
    } 

	protected override void clear_properties () {
		save_changes_to_source ();
        base.clear_properties ();
        rating = Rating.UNRATED;
        comment = "";
        title = "";
        is_media = false;
    }

	protected override void get_single_properties (DataView view) {

        base.get_single_properties (view);
        DataSource source = view.get_source ();

        media_source = source as MediaSource;
        Flaggable? flaggable = media_source as Flaggable;
        if (media_source !=null && flaggable != null) {
            tags = get_initial_tag_text(media_source);
			title = source.get_name ();
            comment = media_source.get_comment ();
            rating = media_source.get_rating ();

            
            if(flaggable != null)
                is_flagged = flaggable.is_flagged();

            is_media = true;
		}
	}
    protected override void internal_update_properties (Page page) {
            base.internal_update_properties (page);   
                 
            if (is_media) {
			    title_entry = new Gtk.Entry ();
			    title_entry.set_text (title);
			    title_entry.changed.connect (title_entry_changed);
			    add_entry_line ("Title",title_entry);

			    
			    comment_entry = new Gtk.TextView();
				comment_entry.set_wrap_mode (Gtk.WrapMode.WORD);
				comment_entry.set_size_request (-1, 50);
                // textview in sidebar css class for non entry we make an exception
                comment_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_ENTRY);
				comment_entry.buffer.text = comment;
			    comment_entry.buffer.changed.connect(comment_entry_changed);
			    add_entry_line ("Comment",comment_entry);
			    
			    
			    var rate_grid = new Gtk.Grid ();
			    
			    //replace with granite star rating widget when it is completed
                string rating_str = Resources.get_stars (rating);
                if (rating_str == "")
                    rating_str = Resources.RATE_UNRATED_DISPLAY_LABEL;
                var rating_label = new Gtk.Label (rating_str);
			    rate_grid.attach (rating_label, 0, 0, 1, 1);
			    rating_label.set_size_request (65,-1);
			    rate_grid.hexpand = true;
			    Gtk.Button increase_rating_button = new Gtk.Button.with_label ("+");
			    increase_rating_button.clicked.connect (increase_rating_click);
                

			    Gtk.Button decrease_rating_button = new Gtk.Button.with_label ("-");
                
			    decrease_rating_button.clicked.connect (decrease_rating_click);
			    rate_grid.attach (decrease_rating_button, 1, 0, 1, 1);
			    rate_grid.attach (increase_rating_button, 2, 0, 1, 1);

		        decrease_rating_button.set_size_request (15,5);
                increase_rating_button.set_size_request (15,5);
                var spacerrate = new Gtk.Grid();
                spacerrate.set_size_request(50,-1);
                spacerrate.hexpand = true;

                rate_grid.attach(spacerrate,3,0,1,1);

                var toolbtn_flag = new Gtk.ToggleToolButton ();
                toolbtn_flag.icon_name = Resources.ICON_FILTER_FLAGGED;
                toolbtn_flag.tooltip_text = _ ("Flagged");
                toolbtn_flag.halign = Gtk.Align.END;
                toolbtn_flag.valign = Gtk.Align.END;
                toolbtn_flag.set_active(is_flagged);
                toolbtn_flag.clicked.connect(flag_btn_clicked);
                
            	rate_grid.attach (toolbtn_flag , 4, 0, 1, 1);
            	attach (rate_grid, 0, (int) line_count, 1, 1);
			    line_count++;

			    rate_grid.set_size_request(125,15);
			    var spacer = new Gtk.Grid();
				spacer.set_size_request(100,15);
				attach (spacer, 0, (int) line_count, 1, 1);
				line_count++;

                tags_entry = new Gtk.Entry ();
                tags_entry.text = tags;
                tags_entry.changed.connect(tags_entry_changed);
             //   EntryMultiCompletion completion = new EntryMultiCompletion(completion_list,
             //   completion_delimiter);
             //   tags_entry.set_completion(completion);

			    add_entry_line ("Tags, seperated by commas",tags_entry);
            }
	}
    private void flag_btn_clicked() {
        Flaggable? flaggable = media_source as Flaggable;

        if (flaggable != null) {
            if (flaggable.is_flagged ())
                flaggable.mark_unflagged ();
            else
                flaggable.mark_flagged ();
        }
    }
    private void title_entry_changed () {
        title = title_entry.get_text ();
    }   
    private void tags_entry_changed () {
        tags = tags_entry.get_text ();
    }	

    private void comment_entry_changed () {
		comment = comment_entry.buffer.text;
	}

	private void increase_rating_click ()
	{
		if (media_source!=null) {
            SetRatingSingleCommand command = new SetRatingSingleCommand.inc_dec(media_source, true);
            AppWindow.get_command_manager().execute(command);
		}

	}

	private void decrease_rating_click ()
	{
        // don't decrase if already unrated, rejecting from button 
        // jarring as removes from collection by default
		if (media_source!=null && media_source.get_rating() != Rating.UNRATED) {
		    SetRatingSingleCommand command = new SetRatingSingleCommand.inc_dec(media_source, false);
            AppWindow.get_command_manager().execute(command);
		}

	}

	private void save_changes_to_source ()
	{
		if (media_source!=null)
		{
            media_source.set_title (MediaSource.prep_title (title));
			media_source.set_comment (MediaSource.prep_title (comment));
            Gee.ArrayList<Tag>? new_tags = tag_entry_to_array();
            if (new_tags != null)
                AppWindow.get_command_manager().execute(new ModifyTagsCommand(media_source, new_tags));
		}
	}

	private void add_entry_line (string label_text, Gtk.Widget entry) {
        Gtk.Label label = new Gtk.Label (label_text);

		label.halign = Gtk.Align.START;
        label.set_justify (Gtk.Justification.LEFT);
        label.set_markup (GLib.Markup.printf_escaped ("<span font_weight=\"bold\">%s</span>", label_text));

        attach (label, 0, (int) line_count, 1, 1);
        line_count++;
		attach (entry, 0, (int) line_count, 1, 1);
        line_count++;
        
        var spacer = new Gtk.Grid();
        spacer.set_size_request(100,15);
        attach (spacer, 0, (int) line_count, 1, 1);
        line_count++;
    }

    private static string? get_initial_tag_text(MediaSource source) {
        Gee.Collection<Tag>? source_tags = Tag.global.fetch_for_source(source);
        if (source_tags == null)
            return null;

        Gee.Collection<Tag> terminal_tags = Tag.get_terminal_tags(source_tags);
        
        Gee.SortedSet<string> tag_basenames = new Gee.TreeSet<string>();
        foreach (Tag tag in terminal_tags)
            tag_basenames.add(HierarchicalTagUtilities.get_basename(tag.get_path()));
        
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
    
    private Gee.ArrayList<Tag>? tag_entry_to_array() {
        string? text = tags;
        if (text == null)
            return null;
        
        Gee.ArrayList<Tag> new_tags = new Gee.ArrayList<Tag>();
        
        // return empty list if no tags specified
        if (is_string_empty(text))
            return new_tags;
        
        // break up by comma-delimiter, prep for use, and separate into list
        string[] tag_names = Tag.prep_tag_names(text.split(","));
        
        tag_names = HierarchicalTagIndex.get_global_index().get_paths_for_names_array(tag_names);

        foreach (string name in tag_names)
            new_tags.add(Tag.for_path(name));
        
        return new_tags;
    }
    
    protected bool on_modify_tag_validate(string text) {
        return (!text.contains(Tag.PATH_SEPARATOR_STRING));
    }
}


