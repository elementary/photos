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

public const string TRANSLATABLE = "translatable";

namespace InternationalSupport {
const string SYSTEM_LOCALE = "";
const string LANGUAGE_SUPPORT_DIRECTORY = _LANG_SUPPORT_DIR;

void init (string package_name, string[] args, string locale = SYSTEM_LOCALE) {
    Intl.setlocale (LocaleCategory.ALL, locale);

    Intl.bindtextdomain (package_name, get_langpack_dir_path (args));
    Intl.bind_textdomain_codeset (package_name, "UTF-8");
    Intl.textdomain (package_name);
}

private string get_langpack_dir_path (string[] args) {
    File local_langpack_dir =
        File.new_for_path (Environment.find_program_in_path (args[0])).get_parent ().get_child (
            "locale-langpack");

    return (local_langpack_dir.query_exists (null)) ? local_langpack_dir.get_path () :
           LANGUAGE_SUPPORT_DIRECTORY;
}
}

