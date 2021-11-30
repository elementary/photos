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

namespace Resources {

public const string WEBSITE_NAME = _ ("Visit the Yorba web site");
public const string WEBSITE_URL = "http://www.yorba.org";

public const string LICENSE = """
                              Photos is free software; you can redistribute it and/or modify it under the
                              terms of the GNU Lesser General Public License as published by the Free
                              Software Foundation; either version 2.1 of the License, or (at your option)
                              any later version.

                              Photos is distributed in the hope that it will be useful, but WITHOUT
                              ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
                              FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for
                              more details.

                              You should have received a copy of the GNU Lesser General Public License
                              along with Photos; if not, write to the Free Software Foundation, Inc.,
                              51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
                              """;

public const string TRANSLATORS = _ ("translator-credits");

// TODO: modify to load multiple icons
//
// provided all the icons in the set follow a known naming convention (such as iconName_nn.png,
// where 'nn' is a size value in pixels, for example plugins_16.png -- this convention seems
// pretty common in the GNOME world), then this function can be modified to load an entire icon
// set without its interface needing to change, since given one icon filename, we can
// determine the others.
public Gdk.Pixbuf[]? load_icon_set (GLib.File? icon_file) {
    Gdk.Pixbuf? icon = null;
    try {
        icon = new Gdk.Pixbuf.from_file (icon_file.get_path ());
    } catch (Error err) {
        warning ("couldn't load icon set from %s.", icon_file.get_path ());
    }

    if (icon_file != null) {
        Gdk.Pixbuf[] icon_pixbuf_set = new Gdk.Pixbuf[0];
        icon_pixbuf_set += icon;
        return icon_pixbuf_set;
    }

    return null;
}

}
