/* Copyright 2014 Pantheon Photos Developer (http://launchpad.net/pantheon-photos)
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Library.RawsEntry : Sidebar.SimplePageEntry {
    protected Icon icon = new ThemedIcon (Resources.ICON_RAW_PAGE);

    public override string get_sidebar_name () {
        return _ ("RAW Photos");
    }

    public override Icon? get_sidebar_icon () {
        return icon;
    }

    protected override Page create_page () {
        return new Library.RawsPage ();
    }
}

public class Library.RawsPage : CollectionPage {
    public const string NAME = _ ("Raws");

    private class RawsViewManager : CollectionViewManager {
        public RawsViewManager (Library.RawsPage owner) {
            base (owner);
        }

        public override bool include_in_view (DataSource source) {
            Photo photo = (Photo) source;
            return photo != null && photo.get_master_file_format () == PhotoFileFormat.RAW;
        }
    }

    public RawsPage (ProgressMonitor? monitor = null) {
        base (NAME);

        view_manager = new RawsViewManager (this);

        foreach (MediaSourceCollection sources in MediaCollectionRegistry.get_instance ().get_all ())
            get_view ().monitor_source_collection (sources, view_manager, null, null, monitor);
    }

    protected override string get_view_empty_message () {
        var library = get_container () as LibraryWindow;
        return_if_fail (library != null);
        library.toggle_welcome_page (true, _ ("Add Some Photos"),_("No Photos were found in your library."), true);
        return "";
    }

    private class RawsSearchViewFilter : CollectionPage.CollectionSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.MEDIA |
                   SearchFilterCriteria.RATING;
        }
    }

    private ViewManager view_manager;
    private RawsSearchViewFilter search_filter = new RawsSearchViewFilter ();

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