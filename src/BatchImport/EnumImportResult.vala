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


public enum ImportResult {
    SUCCESS,
    FILE_ERROR,
    DECODE_ERROR,
    DATABASE_ERROR,
    USER_ABORT,
    NOT_A_FILE,
    PHOTO_EXISTS,
    UNSUPPORTED_FORMAT,
    NOT_AN_IMAGE,
    DISK_FAILURE,
    DISK_FULL,
    CAMERA_ERROR,
    FILE_WRITE_ERROR,
    PIXBUF_CORRUPT_IMAGE;

    public string to_string () {
        switch (this) {
        case SUCCESS:
            return _ ("Success");

        case FILE_ERROR:
            return _ ("File error");

        case DECODE_ERROR:
            return _ ("Unable to decode file");

        case DATABASE_ERROR:
            return _ ("Database error");

        case USER_ABORT:
            return _ ("User aborted import");

        case NOT_A_FILE:
            return _ ("Not a file");

        case PHOTO_EXISTS:
            return _ ("File already exists in database");

        case UNSUPPORTED_FORMAT:
            return _ ("Unsupported file format");

        case NOT_AN_IMAGE:
            return _ ("Not an image file");

        case DISK_FAILURE:
            return _ ("Disk failure");

        case DISK_FULL:
            return _ ("Disk full");

        case CAMERA_ERROR:
            return _ ("Camera error");

        case FILE_WRITE_ERROR:
            return _ ("File write error");

        case PIXBUF_CORRUPT_IMAGE:
            return _ ("Corrupt image file");

        default:
            return _ ("Imported failed (%d)").printf ((int) this);
        }
    }

    public bool is_abort () {
        switch (this) {
        case ImportResult.DISK_FULL:
        case ImportResult.DISK_FAILURE:
        case ImportResult.USER_ABORT:
            return true;

        default:
            return false;
        }
    }

    public bool is_nonuser_abort () {
        switch (this) {
        case ImportResult.DISK_FULL:
        case ImportResult.DISK_FAILURE:
            return true;

        default:
            return false;
        }
    }

    public static ImportResult convert_error (Error err, ImportResult default_result) {
        if (err is FileError) {
            FileError ferr = (FileError) err;

            if (ferr is FileError.NOSPC)
                return ImportResult.DISK_FULL;
            else if (ferr is FileError.IO)
                return ImportResult.DISK_FAILURE;
            else if (ferr is FileError.ISDIR)
                return ImportResult.NOT_A_FILE;
            else if (ferr is FileError.ACCES)
                return ImportResult.FILE_WRITE_ERROR;
            else if (ferr is FileError.PERM)
                return ImportResult.FILE_WRITE_ERROR;
            else
                return ImportResult.FILE_ERROR;
        } else if (err is IOError) {
            IOError ioerr = (IOError) err;

            if (ioerr is IOError.NO_SPACE)
                return ImportResult.DISK_FULL;
            else if (ioerr is IOError.FAILED)
                return ImportResult.DISK_FAILURE;
            else if (ioerr is IOError.IS_DIRECTORY)
                return ImportResult.NOT_A_FILE;
            else if (ioerr is IOError.CANCELLED)
                return ImportResult.USER_ABORT;
            else if (ioerr is IOError.READ_ONLY)
                return ImportResult.FILE_WRITE_ERROR;
            else if (ioerr is IOError.PERMISSION_DENIED)
                return ImportResult.FILE_WRITE_ERROR;
            else
                return ImportResult.FILE_ERROR;
        } else if (err is GPhotoError) {
            return ImportResult.CAMERA_ERROR;
        } else if (err is Gdk.PixbufError) {
            Gdk.PixbufError pixbuferr = (Gdk.PixbufError) err;

            if (pixbuferr is Gdk.PixbufError.CORRUPT_IMAGE)
                return ImportResult.PIXBUF_CORRUPT_IMAGE;
            else if (pixbuferr is Gdk.PixbufError.INSUFFICIENT_MEMORY)
                return default_result;
            else if (pixbuferr is Gdk.PixbufError.BAD_OPTION)
                return default_result;
            else if (pixbuferr is Gdk.PixbufError.UNKNOWN_TYPE)
                return ImportResult.UNSUPPORTED_FORMAT;
            else if (pixbuferr is Gdk.PixbufError.UNSUPPORTED_OPERATION)
                return default_result;
            else if (pixbuferr is Gdk.PixbufError.FAILED)
                return default_result;
            else
                return default_result;
        }

        return default_result;
    }
}
