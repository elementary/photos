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


private class FileToPrepare : Object {
    public BatchImportJob job { get; construct; }
    public File? file { get; construct; }
    public bool copy_to_library { get; construct; }
    public FileToPrepare? associated = null;

    public FileToPrepare (BatchImportJob _job, File? _file = null, bool _copy_to_library = true) {
        Object (
            job: job,
            file: file,
            copy_to_library: copy_to_library
        );
    }

    public void set_associated (FileToPrepare? a) {
        associated = a;
    }

    public string get_parent_path () {
        return file != null ? file.get_parent ().get_path () : job.get_path ();
    }

    public string get_path () {
        return file != null ? file.get_path () : (File.new_for_path (job.get_path ()).get_child (
                    job.get_basename ())).get_path ();
    }

    public string get_basename () {
        return file != null ? file.get_basename () : job.get_basename ();
    }

    public bool is_directory () {
        return file != null ? (file.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) :
               job.is_directory ();
    }
}
