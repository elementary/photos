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

private class PreparedFile {
    public BatchImportJob job;
    public ImportResult result;
    public File file;
    public File? associated_file = null;
    public string source_id;
    public string dest_id;
    public bool copy_to_library;
    public string? exif_md5;
    public string? thumbnail_md5;
    public string? full_md5;
    public PhotoFileFormat file_format;
    public uint64 filesize;
    public bool is_video;

    public PreparedFile (BatchImportJob job, File file, File? associated_file, string source_id, string dest_id,
                         bool copy_to_library, string? exif_md5, string? thumbnail_md5, string? full_md5,
                         PhotoFileFormat file_format, uint64 filesize, bool is_video = false) {
        this.job = job;
        this.result = ImportResult.SUCCESS;
        this.file = file;
        this.associated_file = associated_file;
        this.source_id = source_id;
        this.dest_id = dest_id;
        this.copy_to_library = copy_to_library;
        this.exif_md5 = exif_md5;
        this.thumbnail_md5 = thumbnail_md5;
        this.full_md5 = full_md5;
        this.file_format = file_format;
        this.filesize = filesize;
        this.is_video = is_video;
    }
}
