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

private abstract class BackgroundImportJob : BackgroundJob {
    public ImportResult abort_flag = ImportResult.SUCCESS;
    public Gee.List<BatchImportResult> failed = new Gee.ArrayList<BatchImportResult> ();

    protected BackgroundImportJob (BatchImport owner, CompletionCallback callback,
                                   Cancellable cancellable, CancellationCallback? cancellation) {
        base (owner, callback, cancellable, cancellation);
    }

    // Subclasses should call this every iteration, and if the result is not SUCCESS, consider the
    // operation (and therefore all after) aborted
    protected ImportResult abort_check () {
        if (abort_flag == ImportResult.SUCCESS && is_cancelled ())
            abort_flag = ImportResult.USER_ABORT;

        return abort_flag;
    }

    protected void abort (ImportResult result) {
        // only update the abort flag if not already set
        if (abort_flag == ImportResult.SUCCESS)
            abort_flag = result;
    }

    protected void report_failure (BatchImportJob job, File? file, string src_identifier,
                                   string dest_identifier, ImportResult result) {
        assert (result != ImportResult.SUCCESS);

        // if fatal but the flag is not set, set it now
        if (result.is_abort ())
            abort (result);
        else
            warning ("Import failure %s: %s", src_identifier, result.to_string ());

        failed.add (new BatchImportResult (job, file, src_identifier, dest_identifier, null,
                                           result));
    }

    protected void report_error (BatchImportJob job, File? file, string src_identifier,
                                 string dest_identifier, Error err, ImportResult default_result) {
        ImportResult result = ImportResult.convert_error (err, default_result);

        warning ("Import error %s: %s (%s)", src_identifier, err.message, result.to_string ());

        if (result.is_abort ())
            abort (result);

        failed.add (new BatchImportResult.from_error (job, file, src_identifier, dest_identifier,
                    err, default_result));
    }
}
