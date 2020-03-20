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

//
// PhotoFileAdapter
//
// PhotoFileAdapter (and its immediate children, PhotoFileReader and PhotoFileWriter) are drivers
// hiding details of reading and writing image files and their metadata.  They should keep
// minimal state beyond the filename, if any stat at all.  In particular, they should avoid caching
// values, especially the readers, as writers may be created at any time and invalidate that
// information, unless the readers monitor the file for these changes.
//
// PhotoFileAdapters should be entirely thread-safe.  They are not, however, responsible for
// atomicity on the filesystem.
//

public abstract class PhotoFileAdapter {
    private string filepath;
    private PhotoFileFormat file_format;
    private File file = null;

    protected PhotoFileAdapter (string filepath, PhotoFileFormat file_format) {
        this.filepath = filepath;
        this.file_format = file_format;
    }

    public bool file_exists () {
        return FileUtils.test (filepath, FileTest.IS_REGULAR);
    }

    public string get_filepath () {
        return filepath;
    }

    public File get_file () {
        File result;
        lock (file) {
            if (file == null)
                file = File.new_for_path (filepath);

            result = file;
        }

        return result;
    }

    public PhotoFileFormat get_file_format () {
        return file_format;
    }
}

//
// PhotoFileReader
//

public abstract class PhotoFileReader : PhotoFileAdapter {
    protected PhotoFileReader (string filepath, PhotoFileFormat file_format) {
        base (filepath, file_format);
    }

    public PhotoFileWriter create_writer () throws PhotoFormatError {
        return get_file_format ().create_writer (get_filepath ());
    }

    public PhotoFileMetadataWriter create_metadata_writer () throws PhotoFormatError {
        return get_file_format ().create_metadata_writer (get_filepath ());
    }

    public abstract PhotoMetadata read_metadata () throws Error;

    public abstract Gdk.Pixbuf unscaled_read () throws Error;

    public virtual Gdk.Pixbuf scaled_read (Dimensions full, Dimensions scaled) throws Error {
        return resize_pixbuf (unscaled_read (), scaled, Gdk.InterpType.BILINEAR);
    }
}

//
// PhotoFileWriter
//

public abstract class PhotoFileWriter : PhotoFileAdapter {
    protected PhotoFileWriter (string filepath, PhotoFileFormat file_format) {
        base (filepath, file_format);
    }

    public PhotoFileReader create_reader () {
        return get_file_format ().create_reader (get_filepath ());
    }

    public abstract void write (Gdk.Pixbuf pixbuf, Jpeg.Quality quality) throws Error;
}

//
// PhotoFileMetadataWriter
//

public abstract class PhotoFileMetadataWriter : PhotoFileAdapter {
    protected PhotoFileMetadataWriter (string filepath, PhotoFileFormat file_format) {
        base (filepath, file_format);
    }

    public PhotoFileReader create_reader () {
        return get_file_format ().create_reader (get_filepath ());
    }

    public abstract void write_metadata (PhotoMetadata metadata) throws Error;
}
