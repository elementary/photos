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

public class SearchRowMediaType : SearchRow {
    private Gtk.ComboBoxText media_context;
    private Gtk.ComboBoxText media_type;

    public SearchRowMediaType (SearchRowContainer parent) {
        Object (parent: parent);

        // Ordering must correspond with SearchConditionMediaType.Context
        media_context = new Gtk.ComboBoxText ();
        media_context.append_text (_ ("is"));
        media_context.append_text (_ ("is not"));
        media_context.set_active (0);
        media_context.changed.connect (on_changed);

        // Ordering must correspond with SearchConditionMediaType.MediaType
        media_type = new Gtk.ComboBoxText ();
        media_type.append_text (_ ("any photo"));
        media_type.append_text (_ ("a raw photo"));
        media_type.append_text (_ ("a video"));
        media_type.set_active (0);
        media_type.changed.connect (on_changed);

        add (media_context);
        add (media_type);
        show_all ();
    }

    ~SearchRowMediaType () {
        media_context.changed.disconnect (on_changed);
        media_type.changed.disconnect (on_changed);
    }

    public override SearchCondition get_search_condition () {
        SearchCondition.SearchType search_type = parent.get_search_type ();
        SearchConditionMediaType.Context context = (SearchConditionMediaType.Context) media_context.get_active ();
        SearchConditionMediaType.MediaType type = (SearchConditionMediaType.MediaType) media_type.get_active ();
        SearchConditionMediaType c = new SearchConditionMediaType (search_type, context, type);
        return c;
    }

    public override void populate (SearchCondition sc) {
        SearchConditionMediaType? media = sc as SearchConditionMediaType;
        assert (media != null);
        media_context.set_active (media.context);
        media_type.set_active (media.media_type);
    }

    public override bool is_complete () {
        return true;
    }

    private void on_changed () {
        parent.changed (parent);
    }
}
