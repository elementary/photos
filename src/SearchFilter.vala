/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU LGPL (version 2.1 or later).
 * See the COPYING file in this distribution.
 */

// Bitfield values used to specify which search bar features we want.
[Flags]
public enum SearchFilterCriteria {
    NONE = 0,
    RECURSIVE,
    TEXT,
    FLAG,
    MEDIA,
    RATING,
    ALL = 0xFFFFFFFF
}

public enum RatingFilter {
    NO_FILTER = 0,
    REJECTED_OR_HIGHER = 1,
    UNRATED_OR_HIGHER = 2,
    ONE_OR_HIGHER = 3,
    TWO_OR_HIGHER = 4,
    THREE_OR_HIGHER = 5,
    FOUR_OR_HIGHER = 6,
    FIVE_OR_HIGHER = 7,
    REJECTED_ONLY = 8,
    UNRATED_ONLY = 9,
    ONE_ONLY = 10,
    TWO_ONLY = 11,
    THREE_ONLY = 12,
    FOUR_ONLY = 13,
    FIVE_ONLY = 14
}

// Handles filtering via rating and text.
public abstract class SearchViewFilter : ViewFilter {
    // If this is true, allow the current rating or higher.
    private bool rating_allow_higher = true;

    // Rating to filter by.
    private Rating rating = Rating.UNRATED;
    private RatingFilter rating_filter = RatingFilter.UNRATED_OR_HIGHER;

    // Show flagged only if set to true.
    public bool flagged {
        get;
        set;
        default = false;
    }

    // Media types.
    public bool show_media_video {
        get;
        set;
        default = true;
    }
    public bool show_media_photos {
        get;
        set;
        default = true;
    }
    public bool show_media_raw {
        get;
        set;
        default = true;
    }

    // Search text filter.  Should only be set to lower-case.
    private string? search_filter = null;
    private string[]? search_filter_words = null;

    // Returns a bitmask of SearchFilterCriteria.
    // IMPORTANT: There is no signal on this, changing this value after the
    // view filter is installed will NOT update the GUI.
    public abstract uint get_criteria ();

    public void set_rating_filter (RatingFilter rf) {
        rating_filter = rf;
        switch (rating_filter) {
        case RatingFilter.REJECTED_ONLY:
            rating = Rating.REJECTED;
            rating_allow_higher = false;
            break;

        case RatingFilter.REJECTED_OR_HIGHER:
            rating = Rating.REJECTED;
            rating_allow_higher = true;
            break;

        case RatingFilter.ONE_OR_HIGHER:
            rating = Rating.ONE;
            rating_allow_higher = true;
            break;

        case RatingFilter.ONE_ONLY:
            rating = Rating.ONE;
            rating_allow_higher = false;
            break;

        case RatingFilter.TWO_OR_HIGHER:
            rating = Rating.TWO;
            rating_allow_higher = true;
            break;

        case RatingFilter.TWO_ONLY:
            rating = Rating.TWO;
            rating_allow_higher = false;
            break;

        case RatingFilter.THREE_OR_HIGHER:
            rating = Rating.THREE;
            rating_allow_higher = true;
            break;

        case RatingFilter.THREE_ONLY:
            rating = Rating.THREE;
            rating_allow_higher = false;
            break;

        case RatingFilter.FOUR_OR_HIGHER:
            rating = Rating.FOUR;
            rating_allow_higher = true;
            break;

        case RatingFilter.FOUR_ONLY:
            rating = Rating.FOUR;
            rating_allow_higher = false;
            break;

        case RatingFilter.FIVE_OR_HIGHER:
            rating = Rating.FIVE;
            rating_allow_higher = true;
            break;

        case RatingFilter.FIVE_ONLY:
            rating = Rating.FIVE;
            rating_allow_higher = false;
            break;

        case RatingFilter.UNRATED_OR_HIGHER:
        default:
            rating = Rating.UNRATED;
            rating_allow_higher = true;
            break;
        }
    }

    public bool has_search_filter () {
        return !is_string_empty (search_filter);
    }

    public unowned string? get_search_filter () {
        return search_filter;
    }

    public unowned string[]? get_search_filter_words () {
        return search_filter_words;
    }

    public void set_search_filter (string? text) {
        search_filter = !is_string_empty (text) ? text.down () : null;
        search_filter_words = search_filter != null ? search_filter.split (" ") : null;
    }

    public void clear_search_filter () {
        search_filter = null;
        search_filter_words = null;
    }

    public bool get_rating_allow_higher () {
        return rating_allow_higher;
    }

    public Rating get_rating () {
        return rating;
    }

    public bool filter_by_media_type () {
        return ((show_media_video || show_media_photos || show_media_raw) &&
                ! (show_media_video && show_media_photos && show_media_raw));
    }
}

// This class provides a default predicate implementation used for CollectionPage
// as well as Trash and Offline.
public abstract class DefaultSearchViewFilter : SearchViewFilter {
    public override bool predicate (DataView view) {
        MediaSource source = ((Thumbnail) view).get_media_source ();
        uint criteria = get_criteria ();

        // Ratings filter
        if ((SearchFilterCriteria.RATING & criteria) != 0) {
            if (get_rating_allow_higher () && source.get_rating () < get_rating ())
                return false;
            else if (!get_rating_allow_higher () && source.get_rating () != get_rating ())
                return false;
        }

        // Flag state.
        if ((SearchFilterCriteria.FLAG & criteria) != 0) {
            if (flagged && source is Flaggable && ! ((Flaggable) source).is_flagged ())
                return false;
        }

        // Media type.
        if (((SearchFilterCriteria.MEDIA & criteria) != 0) && filter_by_media_type ()) {
            if (source is VideoSource) {
                if (!show_media_video)
                    return false;
            } else if (source is Photo) {
                Photo photo = source as Photo;
                if (photo.get_master_file_format () == PhotoFileFormat.RAW) {
                    if (photo.is_raw_developer_available (RawDeveloper.CAMERA)) {
                        if (!show_media_photos && !show_media_raw)
                            return false;
                    } else if (!show_media_raw) {
                        return false;
                    }
                } else if (!show_media_photos)
                    return false;
            }
        }

        if (((SearchFilterCriteria.TEXT & criteria) != 0) && has_search_filter ()) {
            unowned string? media_keywords = source.get_indexable_keywords ();

            unowned string? event_keywords = null;
            Event? event = source.get_event ();
            if (event != null)
                event_keywords = event.get_indexable_keywords ();

            Gee.List<Tag>? tags = Tag.global.fetch_for_source (source);
            int tags_size = (tags != null) ? tags.size : 0;

            foreach (unowned string word in get_search_filter_words ()) {
                if (media_keywords != null && media_keywords.contains (word))
                    continue;

                if (event_keywords != null && event_keywords.contains (word))
                    continue;

                if (tags_size > 0) {
                    bool found = false;
                    for (int ctr = 0; ctr < tags_size; ctr++) {
                        unowned string? tag_keywords = tags[ctr].get_indexable_keywords ();
                        if (tag_keywords != null && tag_keywords.contains (word)) {
                            found = true;

                            break;
                        }
                    }

                    if (found)
                        continue;
                }

                // failed all tests (this even works if none of the Indexables have strings,
                // as they fail the implicit AND test)
                return false;
            }
        }

        return true;
    }
}

public class DisabledViewFilter : SearchViewFilter {
    public override bool predicate (DataView view) {
        return true;
    }

    public override uint get_criteria () {
        return SearchFilterCriteria.RATING;
    }
}

public class TextAction {
    public string? value {
        get {
            return text;
        }
    }

    private string? text = null;
    private bool sensitive = true;
    private bool visible = true;

    public signal void text_changed (string? text);

    public signal void sensitivity_changed (bool sensitive);

    public signal void visibility_changed (bool visible);

    public TextAction (string? init = null) {
        text = init;
    }

    public void set_text (string? text) {
        if (this.text != text) {
            this.text = text;
            text_changed (text);
        }
    }

    public void clear () {
        set_text (null);
    }

    public bool is_sensitive () {
        return sensitive;
    }

    public void set_sensitive (bool sensitive) {
        if (this.sensitive != sensitive) {
            this.sensitive = sensitive;
            sensitivity_changed (sensitive);
        }
    }

    public bool is_visible () {
        return visible;
    }

    public void set_visible (bool visible) {
        if (this.visible != visible) {
            this.visible = visible;
            visibility_changed (visible);
        }
    }
}

public class SearchFilterToolbar : Gtk.Revealer {
    public signal void close ();

    // Ticket #3260 - Add a 'close' context menu to
    // the searchbar.
    // The close menu. Populated below in the constructor.
    private Gtk.Menu close_menu = new Gtk.Menu ();
    private Gtk.MenuItem close_item = new Gtk.MenuItem.with_label (_("Close"));

    private SearchFilterCriteria criteria = SearchFilterCriteria.ALL;
    private RatingFilter filter = RatingFilter.UNRATED_OR_HIGHER;
    private Gtk.SearchEntry search_entry;
    private Gtk.ComboBoxText rating_button;
    private SearchViewFilter? search_filter = null;
    private Gtk.Toolbar toolbar;

    public SearchFilterToolbar () {
        toolbar = new Gtk.Toolbar ();
        toolbar.get_style_context ().add_class ("secondary-toolbar");

        // Ticket #3260 - Add a 'close' context menu to
        // the searchbar.
        // Prepare the close menu for use, but don't
        // display it yet; we'll connect it to secondary
        // click later on.
        ((Gtk.MenuItem) close_item).show ();
        close_item.activate.connect ( () => close ());
        close_menu.append (close_item);

        // Rating button
        rating_button = new Gtk.ComboBoxText ();
        rating_button.append_text (Resources.DISPLAY_REJECTED_ONLY_MENU);
        rating_button.append_text (Resources.DISPLAY_REJECTED_OR_HIGHER_MENU);
        rating_button.append_text (Resources.DISPLAY_UNRATED_OR_HIGHER_MENU);
        rating_button.append_text (Resources.DISPLAY_ONE_OR_HIGHER_MENU);
        rating_button.append_text (Resources.DISPLAY_TWO_OR_HIGHER_MENU);
        rating_button.append_text (Resources.DISPLAY_THREE_OR_HIGHER_MENU);
        rating_button.append_text (Resources.DISPLAY_FOUR_OR_HIGHER_MENU);
        rating_button.append_text (Resources.DISPLAY_FIVE_OR_HIGHER_MENU);
        rating_button.tooltip_text = Resources.get_rating_filter_tooltip (filter);
        rating_button.active = 2;
        rating_button.changed.connect ( () => on_rating_changed ());

        Gtk.ToolItem rating_item = new Gtk.ToolItem ();
        rating_item.add (rating_button);
        toolbar.insert (rating_item, -1);

        // Separator to right-align the text box
        Gtk.SeparatorToolItem separator_align = new Gtk.SeparatorToolItem ();
        separator_align.set_expand (true);
        separator_align.set_draw (false);
        toolbar.insert (separator_align, -1);

        // Search box.
        search_entry = new Gtk.SearchEntry ();
        search_entry.search_changed.connect ( () => on_search_text_changed ());
        search_entry.placeholder_text = _ ("Search Photos");
        search_entry.key_press_event.connect (on_escape_key);
        Gtk.ToolItem search_item = new Gtk.ToolItem ();
        search_item.add (search_entry);
        toolbar.insert (search_item, -1);

        add (toolbar);
        show_all ();

        // #3260 part II Hook up close menu.
        toolbar.popup_context_menu.connect (on_context_menu_requested);
        
        grab_focus.connect ( () => { search_entry.grab_focus (); });
    }

    ~SearchFilterToolbar () {
        toolbar.popup_context_menu.disconnect (on_context_menu_requested);
    }

    // Ticket #3124 - user should be able to clear
    // the search textbox by typing 'Esc'.
    private bool on_escape_key (Gdk.EventKey e) {
        if (Gdk.keyval_name (e.keyval) == "Escape")
            search_entry.text = "";

        // Continue processing this event, since the
        // text entry functionality needs to see it too.
        return false;
    }

    // Ticket #3260 part IV - display the context menu on secondary click
    private bool on_context_menu_requested (int x, int y, int button) {
        close_menu.popup (null, null, null, button, Gtk.get_current_event_time ());
        return false;
    }

    private void on_search_text_changed () {
        update ();
    }

    private void on_rating_changed () {
        switch (rating_button.active) {
        case 0:
            filter = RatingFilter.REJECTED_ONLY;
            break;
        case 1:
            filter = RatingFilter.REJECTED_OR_HIGHER;
            break;
        case 2:
            filter = RatingFilter.UNRATED_OR_HIGHER;
            break;
        case 3:
            filter = RatingFilter.ONE_OR_HIGHER;
            break;
        case 4:
            filter = RatingFilter.TWO_OR_HIGHER;
            break;
        case 5:
            filter = RatingFilter.THREE_OR_HIGHER;
            break;
        case 6:
            filter = RatingFilter.FOUR_OR_HIGHER;
            break;
        case 7:
            filter = RatingFilter.FIVE_OR_HIGHER;
            break;
        }
        update ();
    }

    public void set_view_filter (SearchViewFilter search_filter) {
        if (search_filter == this.search_filter)
            return;

        this.search_filter = search_filter;

        // Enable/disable toolbar features depending on what the filter offers.
        rating_button.sensitive = (SearchFilterCriteria.RATING & search_filter.get_criteria ()) != 0;

        update ();
    }

    public void unset_view_filter () {
        set_view_filter (new DisabledViewFilter ());
    }

    // Forces an update of the search filter.
    public void update () {
        if (null == search_filter) {
            // Search bar isn't being shown, need to toggle it.
            LibraryWindow.get_app ().show_search_bar (true);
        }

        assert (null != search_filter);

        search_filter.set_search_filter (search_entry.text);

        search_filter.set_rating_filter (filter);
        rating_button.tooltip_text = Resources.get_rating_filter_tooltip (filter);

        // Ticket #3290, part III - check the current criteria
        // and show or hide widgets as needed.
        search_entry.visible = ((criteria & SearchFilterCriteria.TEXT) != 0);

        rating_button.visible = ((criteria & SearchFilterCriteria.RATING) != 0);

        // Send update to view collection.
        search_filter.refresh ();
    }
}
