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

namespace DesktopIntegration {

public AppInfo? get_default_app_for_mime_types (string[] mime_types,
        Gee.ArrayList<string> preferred_apps) {
    SortedList<AppInfo> external_apps = get_apps_for_mime_types (mime_types);

    foreach (string preferred_app in preferred_apps) {
        foreach (AppInfo external_app in external_apps) {
            if (external_app.get_name ().contains (preferred_app))
                return external_app;
        }
    }

    return null;
}

// compare the app names, case insensitive
public static int64 app_info_comparator (void *a, void *b) {
    return ((AppInfo) a).get_name ().down ().collate (((AppInfo) b).get_name ().down ());
}

public SortedList<AppInfo> get_apps_for_mime_types (string[] mime_types) {
    SortedList<AppInfo> external_apps = new SortedList<AppInfo> (app_info_comparator);

    if (mime_types.length == 0)
        return external_apps;

    // 3 loops because SortedList.contains () wasn't paying nicely with AppInfo,
    // probably because it has a special equality function
    foreach (string mime_type in mime_types) {
        string content_type = ContentType.from_mime_type (mime_type);
        if (content_type == null)
            break;

        foreach (AppInfo external_app in
                 AppInfo.get_all_for_type (content_type)) {
            bool already_contains = false;

            foreach (AppInfo app in external_apps) {
                if (app.get_name () == external_app.get_name ()) {
                    already_contains = true;
                    break;
                }
            }

            // dont add Photos to app list
            if (!already_contains && !external_app.get_name ().contains (_(Resources.APP_DIRECT_ROLE)))
                external_apps.add (external_app);
        }
    }

    return external_apps;
}

public string? get_app_open_command (AppInfo app_info) {
    string? str = app_info.get_commandline ();

    return str != null ? str : app_info.get_executable ();
}

}
