/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
*               2009-2013 Yorba Foundation
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

namespace Resources {
// TRANSLATORS: This is the application name, not a category or mimetype name
public const string APP_TITLE = N_("Photos");
public const string APP_LIBRARY_ROLE = _("Photo Manager");
public const string APP_DIRECT_ROLE = _("Photo Viewer");
public const string APP_VERSION = _VERSION;

#if _GITVERSION
public const string? GIT_VERSION = _GIT_VERSION;
#else
public const string? GIT_VERSION = null;
#endif

public const string APP_GETTEXT_PACKAGE = GETTEXT_PACKAGE;

public const string WIKI_URL = "https://wiki.gnome.org/Apps/Shotwell";

private const string LIB = _LIB;
private const string LIBEXECDIR = _LIBEXECDIR;

public const string PREFIX = _PREFIX;

public const int DEFAULT_ICON_SCALE = 24;

public const string CLOCKWISE = "object-rotate-right";
public const string COUNTERCLOCKWISE = "object-rotate-left";
public const string HFLIP = "object-flip-horizontal";
public const string VFLIP = "object-flip-vertical";
public const string IMPORT = "shotwell-import";
public const string IMPORT_ALL = "shotwell-import-all";
public const string ENHANCE = "image-auto-adjust";
public const string HIDE_PANE = "pane-hide-symbolic";
public const string SHOW_PANE = "pane-show-symbolic";
public const string CROP_PIVOT_RETICLE = "object-rotate-right";
public const string PUBLISH = "applications-internet";
public const string MERGE = "object-merge";

public const string ICON_GENERIC_PLUGIN = "extension";
public const string ICON_SLIDESHOW_EXTENSION_POINT = "media-playback-start";

public const string ICON_ZOOM_IN = "zoom-in-symbolic";
public const string ICON_ZOOM_OUT = "zoom-out-symbolic";

public const string ICON_SELECTION_ADD = "selection-add";
public const string ICON_SELECTION_REMOVE = "selection-remove";

public const string ICON_CAMERAS = "camera-photo";
public const string ICON_EVENTS = "office-calendar";
public const string ICON_ONE_EVENT = "office-calendar";
public const string ICON_NO_EVENT = "office-calendar";
public const string ICON_ONE_TAG = "folder-tag";
public const string ICON_TAGS = "folder-tag";
public const string ICON_FOLDER_CLOSED = "folder";
public const string ICON_FOLDER_OPEN = "folder-open";
public const string ICON_IMPORTING = "go-down";
public const string ICON_LAST_IMPORT = "document-open-recent";
public const string ICON_MISSING_FILES = "process-stop";
public const string ICON_PHOTOS_PAGE = "folder-pictures";
public const string ICON_TRASH_EMPTY = "user-trash";
public const string ICON_TRASH_FULL = "user-trash-full";
public const string ICON_VIDEOS_PAGE = "folder-videos";
public const string ICON_RAW_PAGE = "accessories-camera";
public const string ICON_FLAGGED_PAGE = "edit-flag";

public const string ROTATE_CW_MENU = _("Rotate _Right");
public const string ROTATE_CW_FULL_LABEL = _("Rotate Right");
public const string ROTATE_CW_TOOLTIP = _("Rotate the photos right (press Ctrl to rotate left)");

public const string ROTATE_CCW_MENU = _("Rotate _Left");
public const string ROTATE_CCW_FULL_LABEL = _("Rotate Left");
public const string ROTATE_CCW_TOOLTIP = _("Rotate the photos left");

public const string HFLIP_MENU = _("Flip Hori_zontally");
public const string HFLIP_LABEL = _("Flip Horizontally");
public const string HFLIP_TOOLTIP = _("Flip the image horizontally (press Ctrl to flip vertically)");

public const string VFLIP_MENU = _("Flip Verti_cally");
public const string VFLIP_LABEL = _("Flip Vertically");
public const string VFLIP_TOOLTIP = _("Flip the image vertically");

public const string ENHANCE_MENU = _("_Enhance");
public const string ENHANCE_LABEL = _("Enhance");
public const string ENHANCE_TOOLTIP = _("Automatically improve the photo's appearance \n(Overwrites previous color adjustments)");

public const string UNENHANCE_MENU = _("Revert _Enhancement");
public const string UNENHANCE_LABEL = _("Revert Enhancement");

public const string COPY_ADJUSTMENTS_MENU = _("_Copy Color Adjustments");

public const string PASTE_ADJUSTMENTS_MENU = _("_Paste Color Adjustments");
public const string PASTE_ADJUSTMENTS_LABEL = _("Paste Color Adjustments");
public const string PASTE_ADJUSTMENTS_TOOLTIP = _("Apply copied color adjustments to the selected photos");

public const string CROP_LABEL = _("Crop");
public const string CROP_TOOLTIP = _("Crop the photo's size");

public const string STRAIGHTEN_LABEL = _("Straighten");
public const string STRAIGHTEN_TOOLTIP = _("Straighten the photo");

public const string RED_EYE_LABEL = _("Red-eye");
public const string RED_EYE_TOOLTIP = _("Reduce or eliminate any red-eye effects in the photo");

public const string ADJUST_LABEL = _("Adjust");
public const string ADJUST_TOOLTIP = _("Adjust the photo's color and tone");

public const string REVERT_MENU = _("Re_vert to Original");
public const string REVERT_LABEL = _("Revert to Original");

public const string RENAME_EVENT_MENU = _("Re_name Event…");
public const string RENAME_EVENT_LABEL = _("Rename Event");

public const string MAKE_KEY_PHOTO_MENU = _("Make _Key Photo for Event");
public const string MAKE_KEY_PHOTO_LABEL = _("Make Key Photo for Event");

public const string NEW_EVENT_MENU = _("_New Event");
public const string NEW_EVENT_LABEL = _("New Event");

public const string SET_PHOTO_EVENT_LABEL = _("Move Photos");
public const string SET_PHOTO_EVENT_TOOLTIP = _("Move photos to an event");

public const string MERGE_MENU = _("_Merge Events");
public const string MERGE_LABEL = _("Merge");
public const string MERGE_TOOLTIP = _("Combine events into a single event");

public const string FILTER_PHOTOS_MENU = _("_Filter Photos");

public const string DUPLICATE_PHOTO_MENU = _("_Duplicate");
public const string DUPLICATE_PHOTO_LABEL = _("Duplicate");
public const string DUPLICATE_PHOTO_TOOLTIP = _("Make a duplicate of the photo");

public const string EXPORT_MENU = _("_Export…");

public const string TOGGLE_METAPANE_TOOLTIP = _("Show info panel");

public const string UNTOGGLE_METAPANE_TOOLTIP = _("Hide info panel");

public const string PRINT_MENU = _("_Print…");

public const string PUBLISH_MENU = _("Pu_blish…");
public const string PUBLISH_TOOLTIP = _("Publish to various websites");

public const string EDIT_TITLE_LABEL = _("Edit Title");

public const string EDIT_COMMENT_LABEL = _("Edit Comment");

public const string ADJUST_DATE_TIME_MENU = _("_Adjust Date and Time…");
public const string ADJUST_DATE_TIME_LABEL = _("Adjust Date and Time");

public const string OPEN_WITH_MENU = _("_Open In");

public const string OPEN_WITH_RAW_MENU = _("_Open With RAW Editor…");

public const string FIND_LABEL = _("Find");

public const string FLAG_MENU = _("_Flag");
public const string UNFLAG_MENU = _("Un_flag");

public string launch_editor_failed (Error err) {
    return _("Unable to launch editor: %s").printf (err.message);
}

public string add_tags_label (string[] names) {
    if (names.length == 1)
        return _("Add Tag \"%s\"").printf (HierarchicalTagUtilities.get_basename (names[0]));
    else if (names.length == 2)
        return _("Add Tags \"%s\" and \"%s\"").printf (
                   HierarchicalTagUtilities.get_basename (names[0]),
                   HierarchicalTagUtilities.get_basename (names[1]));
    else
        return _("Add Tags");
}

public string delete_tag_menu (string name) {
    return _("_Delete Tag \"%s\"").printf (name);
}

public string delete_tag_label (string name) {
    return _("Delete Tag \"%s\"").printf (name);
}

public const string DELETE_TAG_TITLE = _("Delete Tag");
public const string DELETE_TAG_SIDEBAR_MENU = _("_Delete");

public const string NEW_CHILD_TAG_SIDEBAR_MENU = _("_New");

public string rename_tag_menu (string name) {
    return _("Re_name Tag \"%s\"…").printf (name);
}

public string rename_tag_label (string old_name, string new_name) {
    return _("Rename Tag \"%s\" to \"%s\"").printf (old_name, new_name);
}

public const string RENAME_TAG_SIDEBAR_MENU = _("_Rename…");

public const string MODIFY_TAGS_MENU = _("Modif_y Tags…");
public const string MODIFY_TAGS_LABEL = _("Modify Tags");

public string tag_photos_label (string name, int count) {
    return (ngettext ("Tag Photo as \"%s\"", "Tag Photos as \"%s\"", count)).printf (name);
}

public string untag_photos_menu (string name, int count) {
    return (ngettext ("Remove Tag \"%s\" From _Photo", "Remove Tag \"%s\" From _Photos", count)).printf (name);
}

public string untag_photos_label (string name, int count) {
    return (ngettext ("Remove Tag \"%s\" From Photo", "Remove Tag \"%s\" From Photos", count)).printf (name);
}

public static string rename_tag_exists_message (string name) {
    return _("Unable to rename tag to \"%s\" because the tag already exists.").printf (name);
}

public static string rename_search_exists_message (string name) {
    return _("Unable to rename search to \"%s\" because the search already exists.").printf (name);
}

public const string DEFAULT_SAVED_SEARCH_NAME = _("Smart Album");

public const string DELETE_SAVED_SEARCH_DIALOG_TITLE = _("Delete Album");

public const string DELETE_SEARCH_MENU = _("_Delete");
public const string EDIT_SEARCH_MENU = _("_Edit…");
public const string RENAME_SEARCH_MENU = _("Re_name…");

public string rename_search_label (string old_name, string new_name) {
    return _("Rename Search \"%s\" to \"%s\"").printf (old_name, new_name);
}

public string delete_search_label (string name) {
    return _("Delete Search \"%s\"").printf (name);
}

private static Gdk.Pixbuf? flag_trinket_cache;
private const int FLAG_PADDING = 2;

public Gdk.Pixbuf? get_flag_trinket () {
    if (flag_trinket_cache != null)
      return flag_trinket_cache;

    int size = 16;
    int padded_size = size + FLAG_PADDING * 2;
    Granite.Drawing.BufferSurface surface = new Granite.Drawing.BufferSurface (padded_size, padded_size);
    Cairo.Context cr = surface.context;

    cr.set_source_rgba (0, 0, 0, 0.35);
    cr.rectangle (0, 0, padded_size, padded_size);
    cr.paint ();

    Gdk.Pixbuf flag;
    try {
        flag = Gtk.IconTheme.get_default ().load_icon (ICON_FLAGGED_PAGE, size, Gtk.IconLookupFlags.FORCE_SIZE);
    } catch (Error e) {
        return null;
    }

    Gdk.cairo_set_source_pixbuf (cr, flag, FLAG_PADDING, FLAG_PADDING);
    cr.paint ();
    flag_trinket_cache = surface.load_to_pixbuf ();
    return flag_trinket_cache;
}

public const string DELETE_PHOTOS_MENU = _("_Delete Selection");
public const string DELETE_FROM_TRASH_TOOLTIP = _("Remove the selected photos from the trash");
public const string DELETE_FROM_LIBRARY_TOOLTIP = _("Remove the selected photos from the library");

public const string RESTORE_PHOTOS_MENU = _("_Restore Selection");
public const string RESTORE_PHOTOS_TOOLTIP = _("Move the selected photos back into the library");

public const string JUMP_TO_FILE_MENU = _("File Mana_ger");

public string jump_to_file_failed (Error err) {
    return _("Unable to open in file manager: %s").printf (err.message);
}

public const string REMOVE_FROM_LIBRARY_MENU = _("R_emove From Library");

public const string MOVE_TO_TRASH_MENU = _("_Move to Trash");

public const string SELECT_ALL_MENU = _("Select _All");
public const string SELECT_ALL_TOOLTIP = _("Select all items");

private string hh_mm_format_string = null;
private string hh_mm_ss_format_string = null;
private string long_date_format_string = null;
private string start_multiday_date_format_string = null;
private string end_multiday_date_format_string = null;
private string start_multimonth_date_format_string = null;

/**
 * Helper for getting a format string that matches the
 * user's LC_TIME settings from the system.  This is intended
 * to help support the use case where a user wants the text
 * from one locale, but the timestamp format of another.
 *
 * Stolen wholesale from code written for Geary by Jim Nelson
 * and from Marcel Stimberg's original patch to Photos to
 * try to fix this; both are graciously thanked for their help.
 */
private void fetch_lc_time_format () {
    // temporarily unset LANGUAGE, as it interferes with LC_TIME
    // and friends.
    string? old_language = Environment.get_variable ("LANGUAGE");
    if (old_language != null) {
        Environment.unset_variable ("LANGUAGE");
    }

    // switch LC_MESSAGES to LC_TIME...
    string? old_messages = Intl.setlocale (LocaleCategory.MESSAGES, null);
    string? lc_time = Intl.setlocale (LocaleCategory.TIME, null);

    if (lc_time != null) {
        Intl.setlocale (LocaleCategory.MESSAGES, lc_time);
    }

    // ...precache the timestamp string...
    /// Locale-specific time format for 12-hour time, i.e. 8:31 PM
    /// Precede modifier with a dash ("-") to pad with spaces, otherwise will pad with zeroes
    /// See http://developer.gnome.org/glib/2.32/glib-GDateTime.html#g-date-time-format
    hh_mm_format_string = _("%-I:%M %p");

    /// Locale-specific time format for 12-hour time with seconds, i.e. 8:31:42 PM
    /// Precede modifier with a dash ("-") to pad with spaces, otherwise will pad with zeroes
    /// See http://developer.gnome.org/glib/2.32/glib-GDateTime.html#g-date-time-format
    hh_mm_ss_format_string = _("%-I:%M:%S %p");

    /// Locale-specific calendar date format, i.e. "Tue Mar 08, 2006"
    /// See http://developer.gnome.org/glib/2.32/glib-GDateTime.html#g-date-time-format
    long_date_format_string = _("%a %b %d, %Y");

    /// Locale-specific starting date format for multi-date strings,
    /// i.e. the "Tue Mar 08" in "Tue Mar 08 - 10, 2006"
    /// See http://developer.gnome.org/glib/2.32/glib-GDateTime.html#g-date-time-format
    start_multiday_date_format_string = _("%a %b %d");

    /// Locale-specific ending date format for multi-date strings,
    /// i.e. the "10, 2006" in "Tue Mar 08 - 10, 2006"
    /// See http://developer.gnome.org/glib/2.32/glib-GDateTime.html#g-date-time-format
    end_multiday_date_format_string = _("%d, %Y");

    /// Locale-specific calendar date format for multi-month strings,
    /// i.e. the "Tue Mar 08" in "Tue Mar 08 to Mon Apr 06, 2006"
    /// See http://developer.gnome.org/glib/2.32/glib-GDateTime.html#g-date-time-format
    start_multimonth_date_format_string = _("%a %b %d");

    // ...put everything back like we found it.
    if (old_messages != null) {
        Intl.setlocale (LocaleCategory.MESSAGES, old_messages);
    }

    if (old_language != null) {
        Environment.set_variable ("LANGUAGE", old_language, true);
    }
}

/**
 * Returns a precached format string that matches the
 * user's LC_TIME settings.
 */
public string get_hh_mm_format_string () {
    if (hh_mm_format_string == null) {
        fetch_lc_time_format ();
    }

    return hh_mm_format_string;
}

public string get_hh_mm_ss_format_string () {
    if (hh_mm_ss_format_string == null) {
        fetch_lc_time_format ();
    }

    return hh_mm_ss_format_string;
}

public string get_long_date_format_string () {
    if (long_date_format_string == null) {
        fetch_lc_time_format ();
    }

    return long_date_format_string;
}

public string get_start_multiday_span_format_string () {
    if (start_multiday_date_format_string == null) {
        fetch_lc_time_format ();
    }

    return start_multiday_date_format_string;
}

public string get_end_multiday_span_format_string () {
    if (end_multiday_date_format_string == null) {
        fetch_lc_time_format ();
    }

    return end_multiday_date_format_string;
}

public string get_start_multimonth_span_format_string () {
    if (start_multimonth_date_format_string == null) {
        fetch_lc_time_format ();
    }

    return start_multimonth_date_format_string ;
}

public string get_end_multimonth_span_format_string () {
    return get_long_date_format_string ();
}

private Gdk.Pixbuf? noninterpretable_badge_pixbuf = null;

public Gdk.Pixbuf? get_noninterpretable_badge_pixbuf () {
    if (noninterpretable_badge_pixbuf == null) {
        try {
            noninterpretable_badge_pixbuf = new Gdk.Pixbuf.from_resource ("/io/elementary/photos/backgrounds/noninterpretable-video.svg");
        } catch (Error err) {
            error ("VideoReader can't load noninterpretable badge image: %s", err.message);
        }
    }

    return noninterpretable_badge_pixbuf;
}

public const int ALL_DATA = -1;

public const string ONIMAGE_FONT_COLOR = "#000000";
public const string ONIMAGE_FONT_BACKGROUND = "rgba(255,255,255,0.5)";
}
