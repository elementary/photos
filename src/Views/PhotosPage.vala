/*
* Copyright (c) 2014-2017 elementary LLC. (https://github.com/elementary/photos)
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

public class Library.PhotosEntry : Sidebar.SimplePageEntry {
    protected Icon icon = new ThemedIcon (Resources.ICON_PHOTOS_PAGE);

    public override string get_sidebar_name () {
        return _ ("Photos");
    }

    public override Icon? get_sidebar_icon () {
        return icon;
    }

    protected override Page create_page () {
        return new Library.PhotosPage ();
    }
}

public class Library.PhotosPage : CollectionPage {
    public const string NAME = _ ("Photos");

    private class PhotosViewManager : CollectionViewManager {
        public PhotosViewManager (Library.PhotosPage owner) {
            base (owner);
        }

        public override bool include_in_view (DataSource source) {
            Photo photo = (Photo) source;
            return source is Photo && photo != null && photo.get_master_file_format () != PhotoFileFormat.RAW;
        }
    }

    public PhotosPage (ProgressMonitor? monitor = null) {
        base (NAME);

        view_manager = new PhotosViewManager (this);

        foreach (MediaSourceCollection sources in MediaCollectionRegistry.get_instance ().get_all ())
            get_view ().monitor_source_collection (sources, view_manager, null, null, monitor);
    }

    protected override string get_view_empty_message () {
        var window = AppWindow.get_instance () as LibraryWindow;
        warn_if_fail (window != null);

        if (window != null) {
            window.toggle_welcome_page (true, _("Add Some Photos"), _("No Photos were found in your library."), true);
        }

        return _("No photos/videos");
    }

    private class PhotosSearchViewFilter : CollectionPage.CollectionSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.MEDIA;
        }
    }

    private ViewManager view_manager;
    private PhotosSearchViewFilter search_filter = new PhotosSearchViewFilter ();

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}
