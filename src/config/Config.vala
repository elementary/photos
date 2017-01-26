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
    public const double SLIDESHOW_DELAY_MAX = 30.0;
    public const double SLIDESHOW_DELAY_MIN = 1.0;
    public const double SLIDESHOW_DELAY_DEFAULT = 3.0;
    public const double SLIDESHOW_TRANSITION_DELAY_MAX = 1.0;
    public const double SLIDESHOW_TRANSITION_DELAY_MIN = 0.1;
    public const double SLIDESHOW_TRANSITION_DELAY_DEFAULT = 0.3;
    public const int WIDTH_DEFAULT = 1024;
    public const int HEIGHT_DEFAULT = 768;
    public const int SIDEBAR_MIN_POSITION = 180;
    public const int SIDEBAR_MAX_POSITION = 1000;
    public const string DEFAULT_BG_COLOR = "#444";
    public const int NO_VIDEO_INTERPRETER_STATE = -1;

    private const double BLACK_THRESHOLD = 0.61;
    private const string DARK_SELECTED_COLOR = "#08c";
    private const string LIGHT_SELECTED_COLOR = "#08c";
    private const string DARK_UNSELECTED_COLOR = "#000";
    private const string LIGHT_UNSELECTED_COLOR = "#FFF";
    private const string DARK_BORDER_COLOR = "#999";
    private const string LIGHT_BORDER_COLOR = "#AAA";
    private const string DARK_UNFOCUSED_SELECTED_COLOR = "#888";
    private const string LIGHT_UNFOCUSED_SELECTED_COLOR = "#888";

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

// preconfigure may be deleted if not used.
public void preconfigure () {
}

public void init () throws Error {
}

public void terminate () {
}

}
