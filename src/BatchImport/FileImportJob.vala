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

public class FileImportJob : BatchImportJob {
    private File file_or_dir;
    private bool copy_to_library;
    private FileImportJob? associated = null;

    public FileImportJob (File file_or_dir, bool copy_to_library) {
        this.file_or_dir = file_or_dir;
        this.copy_to_library = copy_to_library;
    }

    public override string get_dest_identifier () {
        return file_or_dir.get_path ();
    }

    public override string get_source_identifier () {
        return file_or_dir.get_path ();
    }

    public override bool is_directory () {
        return query_is_directory (file_or_dir);
    }

    public override string get_basename () {
        return file_or_dir.get_basename ();
    }

    public override string get_path () {
        return is_directory () ? file_or_dir.get_path () : file_or_dir.get_parent ().get_path ();
    }

    public override void set_associated (BatchImportJob associated) {
        this.associated = associated as FileImportJob;
    }

    public override bool determine_file_size (out uint64 filesize, out File file) {
        filesize = 0;
        file = file_or_dir;

        return false;
    }

    public override bool prepare (out File file_to_import, out bool copy) {
        file_to_import = file_or_dir;
        copy = copy_to_library;

        return true;
    }

    public File get_file () {
        return file_or_dir;
    }
}
