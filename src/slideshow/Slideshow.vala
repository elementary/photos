/*
* Copyright (c) 2011-2013 Yorba Foundation
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

namespace Slideshow {

public void init () throws Error {
    string[] core_ids = new string[0];
    core_ids += "io.elementary.photos.transitions.crumble";
    core_ids += "io.elementary.photos.transitions.fade";
    core_ids += "io.elementary.photos.transitions.slide";
    core_ids += "io.elementary.photos.transitions.blinds";
    core_ids += "io.elementary.photos.transitions.circle";
    core_ids += "io.elementary.photos.transitions.circles";
    core_ids += "io.elementary.photos.transitions.clock";
    core_ids += "io.elementary.photos.transitions.stripes";
    core_ids += "io.elementary.photos.transitions.squares";
    core_ids += "io.elementary.photos.transitions.chess";

    Plugins.register_extension_point (typeof (Spit.Transitions.Descriptor), _ ("Slideshow Transitions"),
    Resources.ICON_SLIDESHOW_EXTENSION_POINT, core_ids);
    TransitionEffectsManager.init ();
}

public void terminate () {
    TransitionEffectsManager.terminate ();
}

}
