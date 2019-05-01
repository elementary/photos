/*
* Copyright (c) 2009-2013 Yorba Foundation
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

// namespace for future migration of AppWindow alert and other question dialogs into single
// place: http://trac.yorba.org/ticket/3452
namespace Dialogs {

private static bool negate_affirm_question (string message, string title) {
    var dialog = new Granite.MessageDialog.with_image_from_icon_name (
        title,
        message,
        "dialog-question",
        Gtk.ButtonsType.NONE
    );
    dialog.transient_for = AppWindow.get_instance ();
    dialog.set_urgency_hint (true);
    dialog.add_button (_("_Cancel"), Gtk.ResponseType.NO);

    var delete_button = (Gtk.Button) dialog.add_button (_("_Delete"), Gtk.ResponseType.YES);
    delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

    bool response = (dialog.run () == Gtk.ResponseType.YES);

    dialog.destroy ();

    return response;
}

public bool confirm_delete_tag (Tag tag) {
    int count = tag.get_sources_count ();
    if (count == 0)
        return true;
    string msg = ngettext (
                     "This will remove the tag \"%s\" from one photo.  Continue?",
                     "This will remove the tag \"%s\" from %d photos.  Continue?",
                     count).printf (tag.get_user_visible_name (), count);

    return negate_affirm_question (msg, Resources.DELETE_TAG_TITLE);
}

public bool confirm_delete_saved_search (SavedSearch search) {
    string msg = _ ("This will remove the smart album \"%s\".  Continue?")
                 .printf (search.get_name ());

    return negate_affirm_question (msg, Resources.DELETE_SAVED_SEARCH_DIALOG_TITLE);
}

public bool confirm_warn_developer_changed (int number) {
    string secondary_text = ngettext (
        "Switching developers will undo all changes you have made to this photo in Photos",
        "Switching developers will undo all changes you have made to these photos in Photos",
        number
    );

    var dialog = new Granite.MessageDialog (
        _("Are You Sure You Want to Switch Developers?"),
        secondary_text,
        new ThemedIcon ("dialog-question"),
        Gtk.ButtonsType.CANCEL
    );
    dialog.transient_for = AppWindow.get_instance ();

    var switch_button = (Gtk.Button) dialog.add_button (_("_Switch Developer"), Gtk.ResponseType.YES);
    switch_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

    int response = dialog.run ();
    dialog.destroy ();

    return response == Gtk.ResponseType.YES;
}

}

namespace ExportUI {
private static File current_export_dir = null;

public File? choose_file (string current_file_basename) {
    if (current_export_dir == null)
        current_export_dir = File.new_for_path (Environment.get_home_dir ());

    var chooser = new Gtk.FileChooserNative (
        VideoReader.is_supported_video_filename (current_file_basename) ? _("Export Video") : _("Export Photo"),
        AppWindow.get_instance (),
        Gtk.FileChooserAction.SAVE,
        _("_Save"),
        _("_Cancel")
    );
    chooser.set_do_overwrite_confirmation (true);
    chooser.set_current_folder (current_export_dir.get_path ());
    chooser.set_current_name (current_file_basename);
    chooser.set_local_only (false);

    File file = null;
    if (chooser.run () == Gtk.ResponseType.ACCEPT) {
        file = File.new_for_path (chooser.get_filename ());
        current_export_dir = file.get_parent ();
    }

    chooser.destroy ();

    return file;
}

public File? choose_dir (string? user_title = null) {
    if (current_export_dir == null)
        current_export_dir = File.new_for_path (Environment.get_home_dir ());

    if (user_title == null)
        user_title = _("Export Photos");

    var chooser = new Gtk.FileChooserNative (
        user_title,
        AppWindow.get_instance (),
        Gtk.FileChooserAction.SELECT_FOLDER,
        _("_Select"),
        _("_Cancel")
    );
    chooser.set_current_folder (current_export_dir.get_path ());
    chooser.set_local_only (false);

    File dir = null;
    if (chooser.run () == Gtk.ResponseType.ACCEPT) {
        dir = File.new_for_path (chooser.get_filename ());
        current_export_dir = dir;
    }

    chooser.destroy ();

    return dir;
}
}

// Ticket #3023
// Attempt to replace the system error with something friendlier
// if we can't copy an image over for editing in an external tool.
public void open_external_editor_error_dialog (Error err, Photo photo) {
    // Did we fail because we can't write to this directory?
    if (err is IOError.PERMISSION_DENIED || err is FileError.PERM) {
        // Yes - display an alternate error message here.
        AppWindow.error_message (
            _ ("Photos couldn't create a file for editing this photo because you do not have permission to write to %s.").printf (photo.get_master_file ().get_parent ().get_path ()));
    } else {
        // No - something else is wrong, display the error message
        // the system gave us.
        AppWindow.error_message (Resources.launch_editor_failed (err));
    }
}

public Gtk.ResponseType export_error_dialog (File dest, bool photos_remaining) {
    string message = _ ("Unable to export the following photo due to a file error.\n\n") +
                     dest.get_path ();

    Gtk.ResponseType response = Gtk.ResponseType.NONE;

    if (photos_remaining) {
        message += _ ("\n\nWould you like to continue exporting?");
        response = AppWindow.cancel_affirm_question (message, _ ("Con_tinue"));
    } else {
        AppWindow.error_message (message);
    }

    return response;
}

namespace ImportUI {
private const int REPORT_FAILURE_COUNT = 4;
internal const string SAVE_RESULTS_BUTTON_NAME = _ ("Save Details…");
internal const string SAVE_RESULTS_FILE_CHOOSER_TITLE = _ ("Save Details");
internal const int SAVE_RESULTS_RESPONSE_ID = 1024;

private string? generate_import_failure_list (Gee.List<BatchImportResult> failed, bool show_dest_id) {
    if (failed.size == 0)
        return null;

    string list = "";
    for (int ctr = 0; ctr < REPORT_FAILURE_COUNT && ctr < failed.size; ctr++) {
        list += "%s\n".printf (show_dest_id ? failed.get (ctr).dest_identifier :
                               failed.get (ctr).src_identifier);
    }

    int remaining = failed.size - REPORT_FAILURE_COUNT;
    if (remaining > 0)
        list += _ ("(and %d more)\n").printf (remaining);

    return list;
}

public class QuestionParams {
    public string question;
    public string yes_button;
    public string no_button;

    public QuestionParams (string question, string yes_button, string no_button) {
        this.question = question;
        this.yes_button = yes_button;
        this.no_button = no_button;
    }
}

public bool import_has_photos (Gee.Collection<BatchImportResult> import_collection) {
    foreach (BatchImportResult current_result in import_collection) {
        if (current_result.file != null
                && PhotoFileFormat.get_by_file_extension (current_result.file) != PhotoFileFormat.UNKNOWN) {
            return true;
        }
    }
    return false;
}

public bool import_has_videos (Gee.Collection<BatchImportResult> import_collection) {
    foreach (BatchImportResult current_result in import_collection) {
        if (current_result.file != null && VideoReader.is_supported_video_file (current_result.file))
            return true;
    }
    return false;
}

public string get_media_specific_string (Gee.Collection<BatchImportResult> import_collection,
        string photos_msg, string videos_msg, string both_msg, string neither_msg) {
    bool has_photos = import_has_photos (import_collection);
    bool has_videos = import_has_videos (import_collection);

    if (has_photos && has_videos)
        return both_msg;
    else if (has_photos)
        return photos_msg;
    else if (has_videos)
        return videos_msg;
    else
        return neither_msg;
}

public string create_result_report_from_manifest (ImportManifest manifest) {
    StringBuilder builder = new StringBuilder ();

    string header = _ ("Import Results Report") + " (Photos " + Resources.APP_VERSION + " @ " +
                    TimeVal ().to_iso8601 () + ")\n\n";
    builder.append (header);

    string subhead = (ngettext ("Attempted to import %d file.", "Attempted to import %d files.",
                                manifest.all.size)).printf (manifest.all.size);
    subhead += " ";
    subhead += (ngettext ("Of these, %d file was successfully imported.",
                          "Of these, %d files were successfully imported.", manifest.success.size)).printf (
                   manifest.success.size);
    subhead += "\n\n";
    builder.append (subhead);

    string current_file_summary = "";

    //
    // Duplicates
    //
    if (manifest.already_imported.size > 0) {
        builder.append (_ ("Duplicate Photos/Videos Not Imported:") + "\n\n");

        foreach (BatchImportResult result in manifest.already_imported) {
            current_file_summary = result.src_identifier + " " +
                                   _ ("duplicates existing media item") + "\n\t" +
                                   result.duplicate_of.get_file ().get_path () + "\n\n";

            builder.append (current_file_summary);
        }
    }

    //
    // Files Not Imported Due to Camera Errors
    //
    if (manifest.camera_failed.size > 0) {
        builder.append (_ ("Photos/Videos Not Imported Due to Camera Errors:") + "\n\n");

        foreach (BatchImportResult result in manifest.camera_failed) {
            current_file_summary = result.src_identifier + "\n\t" + _ ("error message:") + " " +
                                   result.errmsg + "\n\n";

            builder.append (current_file_summary);
        }
    }

    //
    // Files Not Imported Because They Weren't Recognized as Photos or Videos
    //
    if (manifest.skipped_files.size > 0) {
        builder.append (_ ("Files Not Imported Because They Weren't Recognized as Photos or Videos:")
                        + "\n\n");

        foreach (BatchImportResult result in manifest.skipped_files) {
            current_file_summary = result.src_identifier + "\n\t" + _ ("error message:") + " " +
                                   result.errmsg + "\n\n";

            builder.append (current_file_summary);
        }
    }

    //
    // Photos/Videos Not Imported Because They Weren't in a Format Photos Understands
    //
    if (manifest.skipped_photos.size > 0) {
        builder.append (_ ("Photos/Videos Not Imported Because They Weren't in a Format Photos Understands:")
                        + "\n\n");

        foreach (BatchImportResult result in manifest.skipped_photos) {
            current_file_summary = result.src_identifier + "\n\t" + _ ("error message:") + " " +
                                   result.errmsg + "\n\n";

            builder.append (current_file_summary);
        }
    }

    //
    // Photos/Videos Not Imported Because Photos Couldn't Copy Them into its Library
    //
    if (manifest.write_failed.size > 0) {
        builder.append (_ ("Photos/Videos Not Imported Because Photos Couldn't Copy Them into its Library:")
                        + "\n\n");

        foreach (BatchImportResult result in manifest.write_failed) {
            current_file_summary = (_ ("couldn't copy %s\n\tto %s")).printf (result.src_identifier,
                                   result.dest_identifier) + "\n\t" + _ ("error message:") + " " +
                                   result.errmsg + "\n\n";

            builder.append (current_file_summary);
        }
    }

    //
    // Photos/Videos Not Imported Because GDK Pixbuf Library Identified them as Corrupt
    //
    if (manifest.corrupt_files.size > 0) {
        builder.append (_ ("Photos/Videos Not Imported Because Files Are Corrupt:")
                        + "\n\n");

        foreach (BatchImportResult result in manifest.corrupt_files) {
            current_file_summary = result.src_identifier + "\n\t" + _ ("error message:") + " |" +
                                   result.errmsg + "|\n\n";

            builder.append (current_file_summary);
        }
    }

    //
    // Photos/Videos Not Imported for Other Reasons
    //
    if (manifest.failed.size > 0) {
        builder.append (_ ("Photos/Videos Not Imported for Other Reasons:") + "\n\n");

        foreach (BatchImportResult result in manifest.failed) {
            current_file_summary = result.src_identifier + "\n\t" + _ ("error message:") + " " +
                                   result.errmsg + "\n\n";

            builder.append (current_file_summary);
        }
    }

    return builder.str;
}

// Summarizes the contents of an import manifest in an on-screen message window. Returns
// true if the user selected the yes action, false otherwise.
public bool report_manifest (ImportManifest manifest, bool show_dest_id,
                             QuestionParams? question = null) {
    string message = "";

    if (manifest.already_imported.size > 0) {
        string photos_message = (ngettext ("1 duplicate photo was not imported:\n",
                                           "%d duplicate photos were not imported:\n",
                                           manifest.already_imported.size)).printf (manifest.already_imported.size);
        string videos_message = (ngettext ("1 duplicate video was not imported:\n",
                                           "%d duplicate videos were not imported:\n",
                                           manifest.already_imported.size)).printf (manifest.already_imported.size);
        string both_message = (ngettext ("1 duplicate photo/video was not imported:\n",
                                         "%d duplicate photos/videos were not imported:\n",
                                         manifest.already_imported.size)).printf (manifest.already_imported.size);

        message += get_media_specific_string (manifest.already_imported, photos_message,
                                              videos_message, both_message, both_message);

        message += generate_import_failure_list (manifest.already_imported, show_dest_id);
    }

    if (manifest.failed.size > 0) {
        if (message.length > 0)
            message += "\n";

        string photos_message = (ngettext ("1 photo failed to import due to a file or hardware error:\n",
                                           "%d photos failed to import due to a file or hardware error:\n",
                                           manifest.failed.size)).printf (manifest.failed.size);
        string videos_message = (ngettext ("1 video failed to import due to a file or hardware error:\n",
                                           "%d videos failed to import due to a file or hardware error:\n",
                                           manifest.failed.size)).printf (manifest.failed.size);
        string both_message = (ngettext ("1 photo/video failed to import due to a file or hardware error:\n",
                                         "%d photos/videos failed to import due to a file or hardware error:\n",
                                         manifest.failed.size)).printf (manifest.failed.size);
        string neither_message = (ngettext ("1 file failed to import due to a file or hardware error:\n",
                                            "%d files failed to import due to a file or hardware error:\n",
                                            manifest.failed.size)).printf (manifest.failed.size);

        message += get_media_specific_string (manifest.failed, photos_message, videos_message,
                                              both_message, neither_message);

        message += generate_import_failure_list (manifest.failed, show_dest_id);
    }

    if (manifest.write_failed.size > 0) {
        if (message.length > 0)
            message += "\n";

        string photos_message = (ngettext ("1 photo failed to import because the photo library folder was not writable:\n",
                                           "%d photos failed to import because the photo library folder was not writable:\n",
                                           manifest.write_failed.size)).printf (manifest.write_failed.size);
        string videos_message = (ngettext ("1 video failed to import because the photo library folder was not writable:\n",
                                           "%d videos failed to import because the photo library folder was not writable:\n",
                                           manifest.write_failed.size)).printf (manifest.write_failed.size);
        string both_message = (ngettext ("1 photo/video failed to import because the photo library folder was not writable:\n",
                                         "%d photos/videos failed to import because the photo library folder was not writable:\n",
                                         manifest.write_failed.size)).printf (manifest.write_failed.size);
        string neither_message = (ngettext ("1 file failed to import because the photo library folder was not writable:\n",
                                            "%d files failed to import because the photo library folder was not writable:\n",
                                            manifest.write_failed.size)).printf (manifest.write_failed.size);

        message += get_media_specific_string (manifest.write_failed, photos_message, videos_message,
                                              both_message, neither_message);

        message += generate_import_failure_list (manifest.write_failed, show_dest_id);
    }

    if (manifest.camera_failed.size > 0) {
        if (message.length > 0)
            message += "\n";

        string photos_message = (ngettext ("1 photo failed to import due to a camera error:\n",
                                           "%d photos failed to import due to a camera error:\n",
                                           manifest.camera_failed.size)).printf (manifest.camera_failed.size);
        string videos_message = (ngettext ("1 video failed to import due to a camera error:\n",
                                           "%d videos failed to import due to a camera error:\n",
                                           manifest.camera_failed.size)).printf (manifest.camera_failed.size);
        string both_message = (ngettext ("1 photo/video failed to import due to a camera error:\n",
                                         "%d photos/videos failed to import due to a camera error:\n",
                                         manifest.camera_failed.size)).printf (manifest.camera_failed.size);
        string neither_message = (ngettext ("1 file failed to import due to a camera error:\n",
                                            "%d files failed to import due to a camera error:\n",
                                            manifest.camera_failed.size)).printf (manifest.camera_failed.size);

        message += get_media_specific_string (manifest.camera_failed, photos_message, videos_message,
                                              both_message, neither_message);

        message += generate_import_failure_list (manifest.camera_failed, show_dest_id);
    }

    if (manifest.corrupt_files.size > 0) {
        if (message.length > 0)
            message += "\n";

        string photos_message = (ngettext ("1 photo failed to import because it was corrupt:\n",
                                           "%d photos failed to import because they were corrupt:\n",
                                           manifest.corrupt_files.size)).printf (manifest.corrupt_files.size);
        string videos_message = (ngettext ("1 video failed to import because it was corrupt:\n",
                                           "%d videos failed to import because they were corrupt:\n",
                                           manifest.corrupt_files.size)).printf (manifest.corrupt_files.size);
        string both_message = (ngettext ("1 photo/video failed to import because it was corrupt:\n",
                                         "%d photos/videos failed to import because they were corrupt:\n",
                                         manifest.corrupt_files.size)).printf (manifest.corrupt_files.size);
        string neither_message = (ngettext ("1 file failed to import because it was corrupt:\n",
                                            "%d files failed to import because it was corrupt:\n",
                                            manifest.corrupt_files.size)).printf (manifest.corrupt_files.size);

        message += get_media_specific_string (manifest.corrupt_files, photos_message, videos_message,
                                              both_message, neither_message);

        message += generate_import_failure_list (manifest.corrupt_files, show_dest_id);
    }

    if (manifest.skipped_photos.size > 0) {
        if (message.length > 0)
            message += "\n";
        // we have no notion of "unsupported" video files right now in Photos (all
        // standard container formats are supported, it's just that the streams in them
        // might or might not be interpretable), so this message does not need to be
        // media specific
        string skipped_photos_message = (ngettext ("1 unsupported photo skipped:\n",
                                         "%d unsupported photos skipped:\n", manifest.skipped_photos.size)).printf (
                                            manifest.skipped_photos.size);

        message += skipped_photos_message;

        message += generate_import_failure_list (manifest.skipped_photos, show_dest_id);
    }

    if (manifest.skipped_files.size > 0) {
        if (message.length > 0)
            message += "\n";

        // we have no notion of "non-video" video files right now in Photos, so this
        // message doesn't need to be media specific
        string skipped_files_message = (ngettext ("1 non-image file skipped.\n",
                                        "%d non-image files skipped.\n", manifest.skipped_files.size)).printf (
                                           manifest.skipped_files.size);

        message += skipped_files_message;
    }

    if (manifest.aborted.size > 0) {
        if (message.length > 0)
            message += "\n";

        string photos_message = (ngettext ("1 photo skipped due to user cancel:\n",
                                           "%d photos skipped due to user cancel:\n",
                                           manifest.aborted.size)).printf (manifest.aborted.size);
        string videos_message = (ngettext ("1 video skipped due to user cancel:\n",
                                           "%d videos skipped due to user cancel:\n",
                                           manifest.aborted.size)).printf (manifest.aborted.size);
        string both_message = (ngettext ("1 photo/video skipped due to user cancel:\n",
                                         "%d photos/videos skipped due to user cancel:\n",
                                         manifest.aborted.size)).printf (manifest.aborted.size);
        string neither_message = (ngettext ("1 file skipped due to user cancel:\n",
                                            "%d file skipped due to user cancel:\n",
                                            manifest.aborted.size)).printf (manifest.aborted.size);

        message += get_media_specific_string (manifest.aborted, photos_message, videos_message,
                                              both_message, neither_message);

        message += generate_import_failure_list (manifest.aborted, show_dest_id);
    }

    if (manifest.success.size > 0) {
        if (message.length > 0)
            message += "\n";

        string photos_message = (ngettext ("1 photo successfully imported.\n",
                                           "%d photos successfully imported.\n",
                                           manifest.success.size)).printf (manifest.success.size);
        string videos_message = (ngettext ("1 video successfully imported.\n",
                                           "%d videos successfully imported.\n",
                                           manifest.success.size)).printf (manifest.success.size);
        string both_message = (ngettext ("1 photo/video successfully imported.\n",
                                         "%d photos/videos successfully imported.\n",
                                         manifest.success.size)).printf (manifest.success.size);

        message += get_media_specific_string (manifest.success, photos_message, videos_message,
                                              both_message, "");
    }

    int total = manifest.success.size + manifest.failed.size + manifest.camera_failed.size
                + manifest.skipped_photos.size + manifest.skipped_files.size + manifest.corrupt_files.size
                + manifest.already_imported.size + manifest.aborted.size + manifest.write_failed.size;
    assert (total == manifest.all.size);

    // if no media items were imported at all (i.e. an empty directory attempted), need to at least
    // report that nothing was imported
    if (total == 0)
        message += _ ("No photos or videos imported.\n");

    Granite.MessageDialog dialog = null;
    int dialog_response = Gtk.ResponseType.NONE;
    if (question == null) {
        dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Import Complete"),
            message,
            "document-import",
            Gtk.ButtonsType.NONE
        );
        dialog.transient_for = AppWindow.get_instance ();

        var save_results_button = dialog.add_button (ImportUI.SAVE_RESULTS_BUTTON_NAME, ImportUI.SAVE_RESULTS_RESPONSE_ID);
        save_results_button.set_visible (manifest.success.size < manifest.all.size);

        var ok_button = dialog.add_button (_("_Done"), Gtk.ResponseType.OK);

        dialog.set_default (ok_button);
        dialog_response = dialog.run ();
        dialog.destroy ();

        var dialog_parent = (Gtk.Window) dialog.get_parent ();

        if (dialog_response == ImportUI.SAVE_RESULTS_RESPONSE_ID) {
            save_import_results (dialog_parent, create_result_report_from_manifest (manifest));
        }

    } else {
        message += ("\n" + question.question);

        dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Import Complete"),
            message,
            "dialog-question",
            Gtk.ButtonsType.NONE
        );
        dialog.transient_for = AppWindow.get_instance ();

        var save_results_button = dialog.add_button (ImportUI.SAVE_RESULTS_BUTTON_NAME, ImportUI.SAVE_RESULTS_RESPONSE_ID);
        save_results_button.set_visible (manifest.success.size < manifest.all.size);

        var no_button = dialog.add_button (question.no_button, Gtk.ResponseType.NO);

        dialog.add_button (question.yes_button, Gtk.ResponseType.YES);
        dialog.set_default (no_button);

        dialog_response = dialog.run ();
        while (dialog_response == ImportUI.SAVE_RESULTS_RESPONSE_ID) {
            save_import_results (dialog, create_result_report_from_manifest (manifest));
            dialog_response = dialog.run ();
        }

        dialog.hide ();
        dialog.destroy ();
    }

    return (dialog_response == Gtk.ResponseType.YES);
}

internal void save_import_results (Gtk.Window? chooser_dialog_parent, string results_log) {
    var chooser_dialog = new Gtk.FileChooserNative (
        ImportUI.SAVE_RESULTS_FILE_CHOOSER_TITLE,
        chooser_dialog_parent,
        Gtk.FileChooserAction.SAVE,
        _("_Save"),
        _("_Cancel")
    );
    chooser_dialog.set_do_overwrite_confirmation (true);
    chooser_dialog.set_current_folder (Environment.get_home_dir ());
    chooser_dialog.set_current_name ("Photos Import Log.txt");
    chooser_dialog.set_local_only (false);

    int dialog_result = chooser_dialog.run ();
    File? chosen_file = chooser_dialog.get_file ();
    chooser_dialog.hide ();
    chooser_dialog.destroy ();

    if (dialog_result == Gtk.ResponseType.ACCEPT && chosen_file != null) {
        try {
            FileOutputStream outstream = chosen_file.replace (null, false, FileCreateFlags.NONE);
            outstream.write (results_log.data);
            outstream.close ();
        } catch (Error err) {
            critical ("couldn't save import results to log file %s: %s", chosen_file.get_path (),
                      err.message);
        }
    }
}

}

public abstract class TextEntryDialogMediator {
    private TextEntryDialog dialog;

    protected TextEntryDialogMediator (string title, string label, string? initial_text = null,
                                       Gee.Collection<string>? completion_list = null, string? completion_delimiter = null) {
        dialog = new TextEntryDialog (on_modify_validate, title, label, initial_text, completion_list, completion_delimiter);
    }

    protected virtual bool on_modify_validate (string text) {
        return true;
    }

    protected string? _execute () {
        return dialog.execute ();
    }
}

// This method takes primary and secondary texts and returns ready-to-use pango markup
// for a HIG-compliant alert dialog. Please see
// http://library.gnome.org/devel/hig-book/2.32/windows-alert.html.en for details.
public string build_alert_body_text (string? primary_text, string? secondary_text, bool should_escape = true) {
    if (should_escape) {
        return "<span weight=\"Bold\" size=\"larger\">%s</span>\n%s".printf (
                   guarded_markup_escape_text (primary_text), guarded_markup_escape_text (secondary_text));
    }

    return "<span weight=\"Bold\" size=\"larger\">%s</span>\n%s".printf (
               guarded_markup_escape_text (primary_text), secondary_text);
}

// Entry completion for values separated by separators (e.g. comma in the case of tags)
// Partly inspired by the class of the same name in gtkmm-utils by Marko Anastasov
public class EntryMultiCompletion : Gtk.EntryCompletion {
    private string delimiter;

    public EntryMultiCompletion (Gee.Collection<string> completion_list, string? delimiter) {
        assert (delimiter == null || delimiter.length == 1);
        this.delimiter = delimiter;

        set_model (create_completion_store (completion_list));
        set_text_column (0);
        set_match_func (match_func);
    }

    private static Gtk.ListStore create_completion_store (Gee.Collection<string> completion_list) {
        Gtk.ListStore completion_store = new Gtk.ListStore (1, typeof (string));
        Gtk.TreeIter store_iter;
        Gee.Iterator<string> completion_iter = completion_list.iterator ();
        while (completion_iter.next ()) {
            completion_store.append (out store_iter);
            completion_store.set (store_iter, 0, completion_iter.get (), -1);
        }

        return completion_store;
    }

    private bool match_func (Gtk.EntryCompletion completion, string key, Gtk.TreeIter iter) {
        Gtk.TreeModel model = completion.get_model ();
        string possible_match;
        model.get (iter, 0, out possible_match);

        // Normalize key and possible matches to allow comparison of non-ASCII characters.
        // Use a "COMPOSE" normalization to allow comparison to the position value returned by
        // Gtk.Entry, i.e. one character=one position. Using the default normalization a character
        // like "é" or "ö" would have a length of two.
        possible_match = possible_match.casefold ().normalize (-1, NormalizeMode.ALL_COMPOSE);
        string normed_key = key.normalize (-1, NormalizeMode.ALL_COMPOSE);

        if (delimiter == null) {
            return possible_match.has_prefix (normed_key.strip ());
        } else {
            if (normed_key.contains (delimiter)) {
                // check whether cursor is before last delimiter
                int offset = normed_key.char_count (normed_key.last_index_of_char (delimiter[0]));
                int position = ((Gtk.Entry) get_entry ()).get_position ();
                if (position <= offset)
                    return false; // TODO: Autocompletion for tags not last in list
            }

            string last_part = get_last_part (normed_key.strip (), delimiter);

            if (last_part.length == 0)
                return false; // need at least one character to show matches

            return possible_match.has_prefix (last_part.strip ());
        }
    }

    public override bool match_selected (Gtk.TreeModel model, Gtk.TreeIter iter) {
        string match;
        model.get (iter, 0, out match);

        Gtk.Entry entry = (Gtk.Entry)get_entry ();

        string old_text = entry.get_text ().normalize (-1, NormalizeMode.ALL_COMPOSE);
        if (old_text.length > 0) {
            if (old_text.contains (delimiter)) {
                old_text = old_text.substring (0, old_text.last_index_of_char (delimiter[0]) + 1) + (delimiter != " " ? " " : "");
            } else
                old_text = "";
        }

        string new_text = old_text + match + delimiter + (delimiter != " " ? " " : "");
        entry.set_text (new_text);
        entry.set_position ((int) new_text.length);

        return true;
    }

    // Find last string after any delimiter
    private static string get_last_part (string s, string delimiter) {
        string[] split = s.split (delimiter);

        if ((split != null) && (split[0] != null)) {
            return split[split.length - 1];
        } else {
            return "";
        }
    }
}

public class EventRenameDialog : TextEntryDialogMediator {
    public EventRenameDialog (string? event_name) {
        base (_ ("Rename Event"), _ ("Name:"), event_name);
    }

    public virtual string? execute () {
        return Event.prep_event_name (_execute ());
    }
}

public bool revert_editable_dialog (Gtk.Window owner, Gee.Collection<Photo> photos) {
    int count = 0;
    foreach (Photo photo in photos) {
        if (photo.has_editable ())
            count++;
    }

    if (count == 0)
        return false;

    string headline = (count == 1) ? _ ("Revert External Edit?") : _ ("Revert External Edits?");
    string msg = ngettext (
                     "This will destroy all changes made to the external file.  Continue?",
                     "This will destroy all changes made to %d external files.  Continue?",
                     count).printf (count);

    string action = (count == 1) ? _ ("Re_vert External Edit") : _ ("Re_vert External Edits");

    Gtk.MessageDialog dialog = new Gtk.MessageDialog (owner, Gtk.DialogFlags.MODAL,
            Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE, "%s", msg);
    dialog.add_button (_ ("_Cancel"), Gtk.ResponseType.CANCEL);
    dialog.add_button (action, Gtk.ResponseType.YES);

    dialog.set_markup (build_alert_body_text (headline, msg));

    Gtk.ResponseType result = (Gtk.ResponseType) dialog.run ();

    dialog.destroy ();

    return result == Gtk.ResponseType.YES;
}

public bool remove_offline_dialog (Gtk.Window owner, int count) {
    if (count == 0) {
        return false;
    }

    string primary_text = ngettext (
        _("Remove Photo From Library"),
        _("Remove Photos From Library"),
        count
    );

    string secondary_text = ngettext (
        "This will remove the photo from the library.  Continue?",
        "This will remove %d photos from the library.  Continue?",
         count
    ).printf (count);

    var dialog = new Granite.MessageDialog.with_image_from_icon_name (
        primary_text,
        secondary_text,
        "dialog-warning",
        Gtk.ButtonsType.CANCEL
    );
    dialog.transient_for = owner;

    var remove_button = (Gtk.Button) dialog.add_button (_ ("_Remove"), Gtk.ResponseType.OK);
    remove_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

    var result = (Gtk.ResponseType) dialog.run ();

    dialog.destroy ();

    return result == Gtk.ResponseType.OK;
}

public const int MAX_OBJECTS_DISPLAYED = 3;
public void multiple_object_error_dialog (Gee.ArrayList<DataObject> objects, string message,
        string title) {
    string dialog_message = message + "\n";

    //add objects
    for (int i = 0; i < MAX_OBJECTS_DISPLAYED && objects.size > i; i++)
        dialog_message += "\n" + objects.get (i).to_string ();

    int remainder = objects.size - MAX_OBJECTS_DISPLAYED;
    if (remainder > 0) {
        dialog_message += ngettext ("\n\nAnd %d other.", "\n\nAnd %d others.",
                                    remainder).printf (remainder);
    }

    Gtk.MessageDialog dialog = new Gtk.MessageDialog (AppWindow.get_instance (),
            Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, "%s", dialog_message);

    dialog.title = title;

    dialog.run ();
    dialog.destroy ();
}

public interface WelcomeServiceEntry : GLib.Object {
    public abstract void execute ();
}

// This function is used to determine whether or not files should be copied or linked when imported.
// Returns ACCEPT for copy, REJECT for link, and CANCEL for (drum-roll) cancel.
public Gtk.ResponseType copy_files_dialog () {
    string msg = _ ("Photos can copy the photos into your library folder or it can import them without copying.");

    var dialog = new Granite.MessageDialog.with_image_from_icon_name (
        _("Import to Library"),
        msg,
        "dialog-question",
        Gtk.ButtonsType.CANCEL
    );
    dialog.transient_for = AppWindow.get_instance ();

    dialog.add_button (_("Co_py Photos"), Gtk.ResponseType.ACCEPT);
    dialog.add_button (_("_Import in Place"), Gtk.ResponseType.REJECT);

    var result = (Gtk.ResponseType) dialog.run ();

    dialog.destroy ();

    return result;
}

public void remove_photos_from_library (Gee.Collection<LibraryPhoto> photos) {
    remove_from_app (photos, _ ("Remove From Library"),
                     (photos.size == 1) ? _ ("Removing Photo From Library") : _ ("Removing Photos From Library"), false);
}

public void remove_from_app (Gee.Collection<MediaSource> sources, string dialog_title,
                             string progress_dialog_text, bool delete_files) {
    if (sources.size == 0)
        return;

    Gee.ArrayList<LibraryPhoto> photos = new Gee.ArrayList<LibraryPhoto> ();
    Gee.ArrayList<Video> videos = new Gee.ArrayList<Video> ();
    MediaSourceCollection.filter_media (sources, photos, videos);

    AppWindow.get_instance ().set_busy_cursor ();

    ProgressDialog progress = null;
    ProgressMonitor monitor = null;
    if (sources.size >= 20) {
        progress = new ProgressDialog (AppWindow.get_instance (), progress_dialog_text);
        monitor = progress.monitor;
    }

    // Remove and attempt to trash.
    LibraryPhoto.global.remove_from_app (photos, delete_files, monitor, null);
    Video.global.remove_from_app (videos, delete_files, monitor, null);

    if (delete_files) {
        // Attempt to delete the files.
        Gee.ArrayList<LibraryPhoto> not_deleted_photos = new Gee.ArrayList<LibraryPhoto> ();
        Gee.ArrayList<Video> not_deleted_videos = new Gee.ArrayList<Video> ();
        LibraryPhoto.global.delete_backing_files (photos, monitor, not_deleted_photos);
        Video.global.delete_backing_files (videos, monitor, not_deleted_videos);

        int num_not_deleted = not_deleted_photos.size + not_deleted_videos.size;
        if (num_not_deleted > 0) {
            // Alert the user that the files were not removed.
            string delete_failed_message =
                ngettext ("The photo or video cannot be deleted.",
                          "%d photos/videos cannot be deleted.",
                          num_not_deleted).printf (num_not_deleted);
            AppWindow.error_message (dialog_title, delete_failed_message);
        }
    }

    if (progress != null)
        progress.close ();

    AppWindow.get_instance ().set_normal_cursor ();
}
