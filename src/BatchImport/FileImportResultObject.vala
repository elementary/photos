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

// A FileImportResult associates a particular job with a File that an import was performed on
// and the import result.  A BatchImportJob can specify multiple files, so there is not necessarily
// a one-to-one relationship beteen it and this object.
//
// Note that job may be null (in the case of a pre-failed job that must be reported) and file may
// be null (for similar reasons).
public class BatchImportResult {
    public BatchImportJob? job;
    public File? file;
    public string src_identifier;   // Source path
    public string dest_identifier;  // Destination path
    public ImportResult result;
    public string? errmsg = null;
    public DuplicatedFile? duplicate_of;

    public BatchImportResult (BatchImportJob? job, File? file, string src_identifier,
                              string dest_identifier, DuplicatedFile? duplicate_of, ImportResult result) {
        this.job = job;
        this.file = file;
        this.src_identifier = src_identifier;
        this.dest_identifier = dest_identifier;
        this.duplicate_of = duplicate_of;
        this.result = result;
    }

    public BatchImportResult.from_error (BatchImportJob? job, File? file, string src_identifier,
                                         string dest_identifier, Error err, ImportResult default_result) {
        this.job = job;
        this.file = file;
        this.src_identifier = src_identifier;
        this.dest_identifier = dest_identifier;
        this.result = ImportResult.convert_error (err, default_result);
        this.errmsg = err.message;
    }
}
