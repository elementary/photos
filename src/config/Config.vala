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

/* This file is the master unit file for the Config unit.  It should be edited to include
 * whatever code is deemed necessary.
 *
 * The init () and terminate () methods are mandatory.
 *
 * If the unit needs to be configured prior to initialization, add the proper parameters to
 * the preconfigure () method, implement it, and ensure in init () that it's been called.
 */

namespace Config {

public class Facade : ConfigurationFacade {
    public const int NO_VIDEO_INTERPRETER_STATE = -1;

    private static Facade instance = null;

    private Facade () {
        base (new GSettingsConfigurationEngine ());
    }

    public static Facade get_instance () {
        if (instance == null)
            instance = new Facade ();

        return instance;
    }
}

}
