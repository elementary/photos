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

int number_of_processors () {
    int n = (int) Posix.sysconf (Linux._SC_NPROCESSORS_ONLN);
    return n <= 0 ? 1 : n;
}

// Return the directory in which Photos is installed, or null if uninstalled.
File? get_sys_install_dir (File exec_dir) {
    // guard against exec_dir being a symlink
    File exec_dir1 = exec_dir;
    try {
        exec_dir1 = File.new_for_path (
                        FileUtils.read_link ("/" + FileUtils.read_link (exec_dir.get_path ())));
    } catch (FileError e) {
        // exec_dir is not a symlink
    }
    File prefix_dir = File.new_for_path (Resources.PREFIX);
    return exec_dir1.has_prefix (prefix_dir) ? prefix_dir : null;
}

int posix_wexitstatus (int status) {
    return ((status & 0xff00) >> 8);
}
