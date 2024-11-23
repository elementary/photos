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

private class ThumbnailWriterJob : BackgroundImportJob {
    public CompletedImportObject completed_import_source;

    public ThumbnailWriterJob (BatchImport owner, CompletedImportObject completed_import_source,
                               CompletionCallback callback, Cancellable cancellable, CancellationCallback cancel_callback) {
        base (owner, callback, cancellable, cancel_callback);

        assert (completed_import_source.thumbnails != null);
        this.completed_import_source = completed_import_source;

        set_completion_priority (Priority.LOW);
    }

    public override void execute () {
        try {
            ThumbnailCache.import_thumbnails (completed_import_source.source,
                                              completed_import_source.thumbnails, true);
            completed_import_source.batch_result.result = ImportResult.SUCCESS;
        } catch (Error err) {
            completed_import_source.batch_result.result = ImportResult.convert_error (err,
                    ImportResult.FILE_ERROR);
        }

        // destroy the thumbnails (but not the user preview) to free up memory
        completed_import_source.thumbnails = null;
    }
}
