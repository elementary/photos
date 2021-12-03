/*
* Copyright (c) 2011-2013 Yorba Foundation
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

// Bitfield values used to specify which search bar features we want.
[Flags]
public enum SearchFilterCriteria {
    NONE = 0,
    RECURSIVE,
    TEXT,
    FLAG,
    MEDIA,
    ALL = 0xFFFFFFFF
}

// Handles filtering via rating and text.
public abstract class SearchViewFilter : ViewFilter {

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
                var photo = (Photo)source;
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
        return SearchFilterCriteria.NONE;
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

public class SearchFilterEntry : Gtk.SearchEntry {
    private SearchViewFilter? search_filter = null;

    public SearchFilterEntry () {
        placeholder_text = _("Search Photos");
        search_changed.connect ( () => on_search_text_changed ());
        key_press_event.connect (on_escape_key);
    }

    private bool on_escape_key (Gdk.EventKey e) {
        if (Gdk.keyval_name (e.keyval) == "Escape") {
            text = "";
        }

        return false;
    }

    private void on_search_text_changed () {
        update ();
    }

    public void set_view_filter (SearchViewFilter search_filter) {
        if (search_filter == this.search_filter)
            return;

        this.search_filter = search_filter;

        update ();
    }

    public void unset_view_filter () {
        set_view_filter (new DisabledViewFilter ());
    }

    // Forces an update of the search filter.
    public void update () {
        if (null == search_filter) {
            sensitive = false;
        } else {
            sensitive = true;
        }

        assert (null != search_filter);
        search_filter.set_search_filter (text);

        // Send update to view collection.
        search_filter.refresh ();
    }
}
