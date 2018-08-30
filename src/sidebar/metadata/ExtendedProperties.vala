/*
* Copyright (c) 2011-2014 Yorba Foundation
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

private class ExtendedProperties : Properties {
    private const string NO_VALUE = "";
    // Photo stuff
    private string file_path;
    private string artist;
    private string copyright;
    private string exposure_date;
    private string exposure_time;
    private bool is_raw;
    private string? development_path;

    // Event stuff
    // nothing here which is not already shown in the BasicProperties but
    // comments, which are common, see below

    // common stuff
    private string comment;

    protected override void clear_properties () {
        base.clear_properties ();

        file_path = "";
        development_path = "";
        is_raw = false;
        artist = "";
        copyright = "";
        exposure_date = "";
        exposure_time = "";
        comment = "";
    }

    protected override void get_single_properties (DataView view) {
        base.get_single_properties (view);

        var source = view.source;
        if (source == null)
            return;

        if (source is MediaSource) {
            MediaSource media = (MediaSource) source;
            file_path = media.get_master_file ().get_path ();
            development_path = media.get_file ().get_path ();

            // as of right now, all extended properties other than filesize, filepath & comment aren't
            // applicable to non-photo media types, so if the current media source isn't a photo,
            // just do a short-circuit return
            Photo photo = media as Photo;
            if (photo == null)
                return;

            PhotoMetadata? metadata;

            try {
                // For some raw files, the developments may not contain metadata (please
                // see the comment about cameras generating 'crazy' exif segments in
                // Photo.develop_photo () for why), and so we'll want to display what was
                // in the original raw file instead.
                metadata = photo.get_master_metadata ();
            } catch (Error e) {
                metadata = photo.get_metadata ();
            }

            if (metadata == null)
                return;

            // Fix up any timestamp weirdness.
            //
            // If the exposure date wasn't properly set (the most likely cause of this
            // is a raw with a metadataless development), use the one from the photo
            // row.
            if (metadata.get_exposure_date_time () == null)
                metadata.set_exposure_date_time (new MetadataDateTime (photo.get_timestamp ()));

            is_raw = (photo.get_master_file_format () == PhotoFileFormat.RAW);
            artist = metadata.get_artist ();
            copyright = metadata.get_copyright ();
            time_t exposure_time_obj = metadata.get_exposure_date_time ().get_timestamp ();
            exposure_date = get_prettyprint_date (Time.local (exposure_time_obj));
            exposure_time = get_prettyprint_time_with_seconds (Time.local (exposure_time_obj));
            comment = media.get_comment ();
        } else if (source is EventSource) {
            Event event = (Event) source;
            comment = event.get_comment ();
        }
    }

    public override void internal_update_properties (Page page) {
        base.internal_update_properties (page);

        if (page is EventsDirectoryPage) {
            // nothing special to be done for now for Events
        } else {
            add_line (_("Location:"), (file_path != "" && file_path != null) ? file_path.replace ("&", "&amp;") : NO_VALUE);

            if (is_raw)
                add_line (_ ("Developer:"), development_path);

            add_line (_ ("Exposure date:"), (exposure_date != "" && exposure_date != null) ?
                      exposure_date : NO_VALUE);

            add_line (_ ("Exposure time:"), (exposure_time != "" && exposure_time != null) ?
                      exposure_time : NO_VALUE);

            add_line (_ ("Artist:"), (artist != "" && artist != null) ? artist : NO_VALUE);

            add_line (_ ("Copyright:"), (copyright != "" && copyright != null) ? copyright : NO_VALUE);
        }
    }
}
