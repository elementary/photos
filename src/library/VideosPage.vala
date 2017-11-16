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

public class Library.VideosEntry :  Library.HideablePageEntry {
    protected Icon icon = new ThemedIcon (Resources.ICON_VIDEOS_PAGE);

    public VideosEntry () {
        Video.global.items_added.connect (on_item_altered);
        Video.global.items_removed.connect (on_item_altered);

        visible = has_video ();
    }

    ~VideosEntry () {
        Video.global.items_added.disconnect (on_item_altered);
        Video.global.items_removed.disconnect (on_item_altered);
    }

    public override string get_sidebar_name () {
        return _ ("Videos");
    }

    public override Icon? get_sidebar_icon () {
        return icon;
    }

    protected override Page create_page () {
        return new Library.VideosPage ();
    }

    private bool has_video () {
        return Video.global.get_count () > 0;
    }

    private void on_item_altered (Gee.Iterable<DataObject> items) {
        visible = has_video ();
    }
}

public class Library.VideosPage : CollectionPage {
    public const string NAME = _ ("Videos");

    private class VideosViewManager : CollectionViewManager {
        public VideosViewManager (Library.VideosPage owner) {
            base (owner);
        }

        public override bool include_in_view (DataSource source) {
            return source is Video;
        }
    }

    public VideosPage (ProgressMonitor? monitor = null) {
        base (NAME);

        view_manager = new VideosViewManager (this);

        foreach (MediaSourceCollection sources in MediaCollectionRegistry.get_instance ().get_all ())
            get_view ().monitor_source_collection (sources, view_manager, null, null, monitor);
    }

    private class VideosSearchViewFilter : CollectionPage.CollectionSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.MEDIA;
        }
    }

    private ViewManager view_manager;
    private VideosSearchViewFilter search_filter = new VideosSearchViewFilter ();

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}
