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

// A BatchImportJob describes a unit of work the BatchImport object should perform.  It returns
// a file to be imported.  If the file is a directory, it is automatically recursed by BatchImport
// to find all files that need to be imported into the library.
//
// NOTE: All methods may be called from the context of a background thread or the main GTK thread.
// Implementations should be able to handle either situation.  The prepare method will always be
// called by the same thread context.
public abstract class BatchImportJob {
    public abstract string get_dest_identifier ();

    public abstract string get_source_identifier ();

    public abstract bool is_directory ();

    public abstract string get_basename ();

    public abstract string get_path ();

    public virtual DuplicatedFile? get_duplicated_file () {
        return null;
    }

    // Attaches a sibling job (for RAW+JPEG)
    public abstract void set_associated (BatchImportJob associated);

    // Returns the file size of the BatchImportJob or returns a file/directory which can be queried
    // by BatchImportJob to determine it.  Returns true if the size is return, false if the File is
    // specified.
    //
    // filesize should only be returned if BatchImportJob represents a single file.
    public abstract bool determine_file_size (out uint64 filesize, out File file_or_dir);

    // NOTE: prepare( ) is called from a background thread in the worker pool
    public abstract bool prepare (out File file_to_import, out bool copy_to_library) throws Error;

    // Completes the import for the new library photo once it's been imported.
    // If the job is directory based, this method will be called for each photo
    // discovered in the directory. This method is only called for photographs
    // that have been successfully imported.
    //
    // Returns true if any action was taken, false otherwise.
    //
    // NOTE: complete( )is called from the foreground thread
    public virtual bool complete (MediaSource source, BatchImportRoll import_roll) throws Error {
        return false;
    }

    // returns a non-zero int64 value if this has a valid exposure time override, returns zero
    // otherwise
    public virtual int64 get_exposure_time_override () {
        return 0;
    }
}
