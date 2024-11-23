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

private class CompletedImportObject {
    public Thumbnails? thumbnails;
    public BatchImportResult batch_result;
    public MediaSource source;
    public BatchImportJob original_job;
    public Gdk.Pixbuf user_preview;

    public CompletedImportObject (MediaSource source, Thumbnails thumbnails,
                                  BatchImportJob original_job, BatchImportResult import_result) {
        this.thumbnails = thumbnails;
        this.batch_result = import_result;
        this.source = source;
        this.original_job = original_job;
        user_preview = thumbnails.get (ThumbnailCache.Size.LARGEST);
    }
}
