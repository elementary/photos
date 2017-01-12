/*
* Copyright (c) 2009-2013 Yorba Foundation
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

public class Screensaver {
    private uint32 cookie = 0;

    public Screensaver () {
    }

    public void inhibit (string reason) {
        if (cookie != 0)
            return;

        cookie = Application.get_instance ().app_inhibit (
                     Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND, _ ("Slideshow"));
    }

    public void uninhibit () {
        if (cookie == 0)
            return;

        Application.get_instance ().uninhibit (cookie);
        cookie = 0;
    }
}
