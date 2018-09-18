/*
* Copyright (c) 2011-2013 Yorba Foundation
*               2018 elementary LLC. (https://elementary.io)
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

// This dialog displays a boolean search configuration.
public class SavedSearchDialog {
    private Gtk.Dialog dialog;
    private Gtk.Button add_criteria;
    private Gtk.ComboBoxText operator;
    private Gtk.Grid row_box;
    private Gtk.Entry search_title;
    private Gee.ArrayList<SearchRowContainer> row_list = new Gee.ArrayList<SearchRowContainer> ();
    private bool edit_mode = false;
    private SavedSearch? previous_search = null;
    private bool valid = false;

    public SavedSearchDialog () {
        setup_dialog ();

        // Default name.
        search_title.set_text (SavedSearchTable.get_instance ().generate_unique_name ());
        search_title.select_region (0, -1); // select all

        // Default is text search.
        add_text_search ();
        row_list.get (0).allow_removal (false);

        // Add buttons for new search.
        dialog.add_action_widget (new Gtk.Button.with_label (_ ("Cancel")), Gtk.ResponseType.CANCEL);
        Gtk.Button ok_button = new Gtk.Button.with_label (_ ("Add"));
        ok_button.can_default = true;
        dialog.add_action_widget (ok_button, Gtk.ResponseType.OK);
        dialog.set_default_response (Gtk.ResponseType.OK);

        dialog.show_all ();
        set_valid (false);
    }

    public SavedSearchDialog.edit_existing (SavedSearch saved_search) {
        previous_search = saved_search;
        edit_mode = true;
        setup_dialog ();

        // Add close button.
        Gtk.Button close_button = new Gtk.Button.with_label (_ ("Save"));
        close_button.can_default = true;
        dialog.add_action_widget (close_button, Gtk.ResponseType.OK);
        dialog.set_default_response (Gtk.ResponseType.OK);

        dialog.show_all ();

        // Load existing search into dialog.
        operator.set_active ((SearchOperator) saved_search.get_operator ());
        search_title.set_text (saved_search.get_name ());
        foreach (SearchCondition sc in saved_search.get_conditions ()) {
            add_row (new SearchRowContainer.edit_existing (sc));
        }

        if (row_list.size == 1)
            row_list.get (0).allow_removal (false);

        set_valid (true);
    }

    ~SavedSearchDialog () {
        search_title.changed.disconnect (on_title_changed);
    }

    // Builds the dialog UI.  Doesn't add buttons to the dialog or call dialog.show ().
    private void setup_dialog () {
        var search_label = new Gtk.Label (_("Name:"));

        search_title = new Gtk.Entry ();
        search_title.activates_default = true;
        search_title.hexpand = true;
        search_title.changed.connect (on_title_changed);

        var match_label = new Gtk.Label.with_mnemonic (_("_Match"));

        operator = new Gtk.ComboBoxText ();
        operator.append_text (_("any"));
        operator.append_text (_("all"));
        operator.append_text (_("none"));
        operator.active = 0;

        var match2_label = new Gtk.Label.with_mnemonic (_("of the following:"));
        match2_label.hexpand = true;
        match2_label.xalign = 0;

        add_criteria = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON);
        add_criteria.tooltip_text = _("Add rule");
        add_criteria.button_press_event.connect (on_add_criteria);

        row_box = new Gtk.Grid ();
        row_box.orientation = Gtk.Orientation.VERTICAL;
        row_box.row_spacing = 12;

        var search_grid = new Gtk.Grid ();
        search_grid.margin = 12;
        search_grid.column_spacing = 6;
        search_grid.row_spacing = 12;
        search_grid.attach (search_label, 0, 0, 1, 1);
        search_grid.attach (search_title, 1, 0, 3, 1);
        search_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 4, 1);
        search_grid.attach (match_label, 0, 2, 1, 1);
        search_grid.attach (operator, 1, 2, 1, 1);
        search_grid.attach (match2_label, 2, 2, 1, 1);
        search_grid.attach (add_criteria, 3, 2, 1, 1);
        search_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 3, 4, 1);
        search_grid.attach (row_box, 0, 4, 4, 1);

        dialog = new Gtk.Dialog ();
        dialog.title = _("Smart Album");
        dialog.modal = true;
        dialog.transient_for = AppWindow.get_instance ();
        dialog.response.connect (on_response);
        dialog.deletable = false;
        dialog.get_content_area ().add (search_grid);
    }

    // Displays the dialog.
    public void show () {
        dialog.run ();
        dialog.destroy ();
    }

    // Adds a row of search criteria.
    private bool on_add_criteria (Gdk.EventButton event) {
        add_text_search ();
        return false;
    }

    private void add_text_search () {
        SearchRowContainer text = new SearchRowContainer ();
        add_row (text);
    }

    // Appends a row of search criteria to the list and table.
    private void add_row (SearchRowContainer row) {
        if (row_list.size == 1)
            row_list.get (0).allow_removal (true);
        row_box.add (row.get_widget ());
        row_list.add (row);
        row.remove.connect (on_remove_row);
        row.changed.connect (on_row_changed);
        set_valid (row.is_complete ());
    }

    // Removes a row of search criteria.
    private void on_remove_row (SearchRowContainer row) {
        row.remove.disconnect (on_remove_row);
        row.changed.disconnect (on_row_changed);
        row_box.remove (row.get_widget ());
        row_list.remove (row);
        if (row_list.size == 1)
            row_list.get (0).allow_removal (false);
        set_valid (true); // try setting to "true" since we removed a row
    }

    private void on_response (int response_id) {
        if (response_id == Gtk.ResponseType.OK) {
            if (SavedSearchTable.get_instance ().exists (search_title.get_text ()) &&
                    ! (edit_mode && previous_search.get_name () == search_title.get_text ())) {
                AppWindow.error_message (Resources.rename_search_exists_message (search_title.get_text ()));
                return;
            }

            if (edit_mode) {
                // Remove previous search.
                SavedSearchTable.get_instance ().remove (previous_search);
            }

            // Build the condition list from the search rows, and add our new saved search to the table.
            Gee.ArrayList<SearchCondition> conditions = new Gee.ArrayList<SearchCondition> ();
            foreach (SearchRowContainer c in row_list) {
                conditions.add (c.get_search_condition ());
            }

            // Create the object.  It will be added to the DB and SearchTable automatically.
            SearchOperator search_operator = (SearchOperator)operator.get_active ();
            SavedSearchTable.get_instance ().create (search_title.get_text (), search_operator, conditions);
        }
    }

    private void on_row_changed (SearchRowContainer row) {
        set_valid (row.is_complete ());
    }

    private void on_title_changed () {
        set_valid (is_title_valid ());
    }

    private bool is_title_valid () {
        if (edit_mode && previous_search != null &&
                previous_search.get_name () == search_title.get_text ())
            return true; // Title hasn't changed.
        if (search_title.get_text ().chomp () == "")
            return false;
        if (SavedSearchTable.get_instance ().exists (search_title.get_text ()))
            return false;
        return true;
    }

    // Call this with your new value for validity whenever a row or the title changes.
    private void set_valid (bool v) {
        if (!v) {
            valid = false;
        } else if (v != valid) {
            if (is_title_valid ()) {
                // Go through rows to check validity.
                int valid_rows = 0;
                foreach (SearchRowContainer c in row_list) {
                    if (c.is_complete ())
                        valid_rows++;
                }
                valid = (valid_rows == row_list.size);
            } else {
                valid = false; // title was invalid
            }
        }

        dialog.set_response_sensitive (Gtk.ResponseType.OK, valid);
    }
}
