/* Copyright 2014 Pantheon Photos Developer (http://launchpad.net/pantheon-photos)
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
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

    protected override void get_config_photos_sort (out bool sort_order, out int sort_by) {
        Config.Facade.get_instance ().get_library_photos_sort (out sort_order, out sort_by);
    }

    protected override void set_config_photos_sort (bool sort_order, int sort_by) {
        Config.Facade.get_instance ().set_library_photos_sort (sort_order, sort_by);
    }
    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}
