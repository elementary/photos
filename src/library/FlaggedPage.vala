/*
* Copyright (c) 2010-2013 Yorba Foundation
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

public class FlaggedPage : CollectionPage {
    public const string NAME = _ ("Flagged");

    private class FlaggedViewManager : CollectionViewManager {
        public FlaggedViewManager (FlaggedPage owner) {
            base (owner);
        }

        public override bool include_in_view (DataSource source) {
            Flaggable? flaggable = source as Flaggable;

            return (flaggable != null) && flaggable.is_flagged ();
        }
    }

    private class FlaggedSearchViewFilter : CollectionPage.CollectionSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.MEDIA;
        }
    }

    private ViewManager view_manager;
    private Alteration prereq = new Alteration ("metadata", "flagged");
    private FlaggedSearchViewFilter search_filter = new FlaggedSearchViewFilter ();

    public FlaggedPage () {
        base (NAME);

        view_manager = new FlaggedViewManager (this);

        foreach (MediaSourceCollection sources in MediaCollectionRegistry.get_instance ().get_all ())
            view.monitor_source_collection (sources, view_manager, prereq);
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }
}

