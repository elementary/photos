/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace Library {

public void app_init () throws Error {
    Util.init ();
    Threads.init ();
    Db.init ();
    Plugins.init ();
    Slideshow.init ();
    Photos.init ();
    Publishing.init ();
    Core.init ();
    Sidebar.init ();
    Events.init ();
    Tags.init ();
    Camera.init ();
    Searches.init ();
    Library.TrashSidebarEntry.init ();
    Photo.develop_raw_photos_to_files = true;
}

public void app_terminate () {
    Library.TrashSidebarEntry.terminate ();
}

}

