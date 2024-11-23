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

public class DuplicatedFile : Object {
    private VideoID? video_id;
    private PhotoID? photo_id;
    private File? file;

    private DuplicatedFile () {
        this.video_id = null;
        this.photo_id = null;
        this.file = null;
    }

    public static DuplicatedFile create_from_photo_id (PhotoID photo_id) requires (photo_id.is_valid ()) {
        // assert (photo_id.is_valid ());

        DuplicatedFile result = new DuplicatedFile ();
        result.photo_id = photo_id;
        return result;
    }

    public static DuplicatedFile create_from_video_id (VideoID video_id) requires (video_id.is_valid ()) {
        // assert (video_id.is_valid ());

        DuplicatedFile result = new DuplicatedFile ();
        result.video_id = video_id;
        return result;
    }

    public static DuplicatedFile create_from_file (File file) {
        DuplicatedFile result = new DuplicatedFile ();

        result.file = file;

        return result;
    }

    public File get_file () {
        if (file != null) {
            return file;
        } else if (photo_id != null) {
            Photo photo_object = (Photo) LibraryPhoto.global.fetch (photo_id);
            file = photo_object.get_master_file ();
            return file;
        } else if (video_id != null) {
            Video video_object = (Video) Video.global.fetch (video_id);
            file = video_object.get_master_file ();
            return file;
        } else {
            // Should not reach here because public constructors should always set file non-null
            error ("Duplicated file used with null file");
        }
    }
}
