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

#if UNITY_SUPPORT
public class UnityProgressBar : Object {

    private static Unity.LauncherEntry l = Unity.LauncherEntry.get_for_desktop_id ("io.elementary.photos.desktop");
    private static UnityProgressBar? visible_uniprobar;

    private double progress;
    private bool visible;

    public static UnityProgressBar get_instance () {
        if (visible_uniprobar == null) {
            visible_uniprobar = new UnityProgressBar ();
        }

        return visible_uniprobar;
    }

    private UnityProgressBar () {
        progress = 0.0;
        visible = false;
    }

    ~UnityProgressBar () {
        reset_progress_bar ();
    }

    public double get_progress () {
        return progress;
    }

    public void set_progress (double percent) {
        progress = percent;
        update_visibility ();
    }

    private void update_visibility () {
        set_progress_bar (this, progress);
    }

    public bool get_visible () {
        return visible;
    }

    public void set_visible (bool visible) {
        this.visible = visible;

        if (!visible) {
            //if not visible and currently displayed, remove Unity progress bar
            reset_progress_bar ();
        } else {
            //update_visibility if this progress bar wants to be drawn
            update_visibility ();
        }
    }

    public void reset () {
        set_visible (false);
        progress = 0.0;
    }

    private static void set_progress_bar (UnityProgressBar uniprobar, double percent) {
        //set new visible ProgressBar
        visible_uniprobar = uniprobar;
        if (!l.progress_visible)
            l.progress_visible = true;
        l.progress = percent;
    }

    private static void reset_progress_bar () {
        //reset to default values
        visible_uniprobar = null;
        l.progress = 0.0;
        l.progress_visible = false;
    }
}

#endif
