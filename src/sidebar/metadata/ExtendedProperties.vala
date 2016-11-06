/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class ExtendedProperties : Properties {
    private const string NO_VALUE = "";
    // Photo stuff
    private string file_path;
    private string flash;
    private double gps_lat;
    private string gps_lat_ref;
    private double gps_long;
    private string gps_long_ref;
    private double gps_alt;
    private string artist;
    private string copyright;
    private string exposure_bias;
    private string exposure_date;
    private string exposure_time;
    private bool is_raw;
    private string? development_path;

    // Event stuff
    // nothing here which is not already shown in the BasicProperties but
    // comments, which are common, see below

    // common stuff
    private string comment;

    public override string get_header_title () {
        return Resources.EXTENDED_PROPERTIES_LABEL;
    }

    protected override void clear_properties () {
        base.clear_properties ();

        file_path = "";
        development_path = "";
        is_raw = false;
        flash = "";
        gps_lat = -1;
        gps_lat_ref = "";
        gps_long = -1;
        gps_long_ref = "";
        artist = "";
        copyright = "";
        exposure_bias = "";
        exposure_date = "";
        exposure_time = "";
        comment = "";
    }

    protected override void get_single_properties (DataView view) {
        base.get_single_properties (view);

        DataSource source = view.get_source ();
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
            flash = metadata.get_flash_string ();
            metadata.get_gps (out gps_long, out gps_long_ref, out gps_lat, out gps_lat_ref, out gps_alt);
            artist = metadata.get_artist ();
            copyright = metadata.get_copyright ();
            exposure_bias = metadata.get_exposure_bias ();
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

            add_line (_ ("Flash:"), (flash != "" && flash != null) ? flash : NO_VALUE);

            add_line (_ ("Exposure date:"), (exposure_date != "" && exposure_date != null) ?
                      exposure_date : NO_VALUE);

            add_line (_ ("Exposure time:"), (exposure_time != "" && exposure_time != null) ?
                      exposure_time : NO_VALUE);

            add_line (_ ("Exposure bias:"), (exposure_bias != "" && exposure_bias != null) ? exposure_bias : NO_VALUE);

            add_line (_ ("GPS latitude:"), (gps_lat != -1 && gps_lat_ref != "" &&
                                            gps_lat_ref != null) ? "%f °%s".printf (gps_lat, gps_lat_ref) : NO_VALUE);

            add_line (_ ("GPS longitude:"), (gps_long != -1 && gps_long_ref != "" &&
                                             gps_long_ref != null) ? "%f °%s".printf (gps_long, gps_long_ref) : NO_VALUE);

            add_line (_ ("Artist:"), (artist != "" && artist != null) ? artist : NO_VALUE);

            add_line (_ ("Copyright:"), (copyright != "" && copyright != null) ? copyright : NO_VALUE);
        }
    }
}
