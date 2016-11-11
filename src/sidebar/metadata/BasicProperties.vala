/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class BasicProperties : Properties {
    private time_t start_time = time_t ();
    private time_t end_time = time_t ();
    private Dimensions dimensions;
    private EditableTitle title_entry;
    private MediaSource? source;
    private Gtk.Label place_label;
    private int photo_count;
    private int event_count;
    private int video_count;
    private string camera_make;
    private string camera_model;
    private string exposure;
    private string exposure_bias;
    private string flash;
    private string focal_length;
    private double gps_lat;
    private string gps_lat_ref;
    private double gps_long;
    private string gps_long_ref;
    private double gps_alt;
    private string title;
    private string aperture;
    private string iso;
    private double clip_duration;
    private string raw_developer;
    private string raw_assoc;
    private uint64 filesize;

    public BasicProperties () {
    }

    public override string get_header_title () {
        return Resources.BASIC_PROPERTIES_LABEL;
    }

    protected override void clear_properties () {
        base.clear_properties ();
        camera_make = "";
        camera_model = "";
        title = "";
        start_time = 0;
        end_time = 0;
        dimensions = Dimensions (0, 0);
        flash = "";
        filesize = 0;
        focal_length = "";
        gps_lat = -1;
        gps_lat_ref = "";
        gps_long = -1;
        gps_long_ref = "";
        photo_count = -1;
        event_count = -1;
        video_count = -1;
        exposure = "";
        exposure_bias = "";
        aperture = "";
        iso = "";
        clip_duration = 0.0;
        raw_developer = "";
        raw_assoc = "";
    }

    protected override void get_single_properties (DataView view) {
        base.get_single_properties (view);

        source = view.get_source () as MediaSource;

        filesize = source.get_master_filesize ();
        title = source.get_name ();

        if (source is PhotoSource || source is PhotoImportSource) {
            start_time = (source is PhotoSource) ? ((PhotoSource) source).get_exposure_time () :
                         ((PhotoImportSource) source).get_exposure_time ();
            end_time = start_time;

            PhotoMetadata ? metadata = (source is PhotoSource) ? ((PhotoSource) source).get_metadata () :
                                       ((PhotoImportSource) source).get_metadata ();

            if (metadata != null) {
                camera_make = metadata.get_camera_make ();
                camera_model = metadata.get_camera_model ();

                exposure = metadata.get_exposure_string ();
                if (exposure == null)
                    exposure = "";

                exposure_bias = metadata.get_exposure_bias ();

                flash = metadata.get_flash_string ();

                aperture = metadata.get_aperture_string (true);
                if (aperture == null)
                    aperture = "";

                iso = metadata.get_iso_string ();
                if (iso == null)
                    iso = "";

                dimensions = (metadata.get_pixel_dimensions () != null) ?
                             metadata.get_orientation ().rotate_dimensions (metadata.get_pixel_dimensions ()) :
                             Dimensions (0, 0);

                focal_length = metadata.get_focal_length_string ();

                metadata.get_gps (out gps_long, out gps_long_ref, out gps_lat, out gps_lat_ref, out gps_alt);
            }

            if (source is PhotoSource)
                dimensions = ((PhotoSource) source).get_dimensions ();

            if (source is Photo && ((Photo) source).get_master_file_format () == PhotoFileFormat.RAW) {
                Photo photo = source as Photo;
                raw_developer = photo.get_raw_developer ().get_label ();
                raw_assoc = photo.is_raw_developer_available (RawDeveloper.CAMERA) ? _ ("RAW+JPEG") : "";
            }
        } else if (source is EventSource) {
            EventSource event_source = (EventSource) source;

            start_time = event_source.get_start_time ();
            end_time = event_source.get_end_time ();

            int event_photo_count;
            int event_video_count;
            MediaSourceCollection.count_media (event_source.get_media (), out event_photo_count,
                                               out event_video_count);

            photo_count = event_photo_count;
            video_count = event_video_count;
        } else if (source is VideoSource || source is VideoImportSource) {
            if (source is VideoSource) {
                Video video = (Video) source;
                clip_duration = video.get_clip_duration ();

                if (video.get_is_interpretable ())
                    dimensions = video.get_frame_dimensions ();

                start_time = video.get_exposure_time ();
            } else {
                start_time = ((VideoImportSource) source).get_exposure_time ();
            }
            end_time = start_time;
        }
    }

    protected override void get_multiple_properties (Gee.Iterable<DataView>? iter) {
        base.get_multiple_properties (iter);

        photo_count = 0;
        video_count = 0;
        foreach (DataView view in iter) {
            DataSource source = view.get_source ();

            if (source is PhotoSource || source is PhotoImportSource) {
                time_t exposure_time = (source is PhotoSource) ?
                                       ((PhotoSource) source).get_exposure_time () :
                                       ((PhotoImportSource) source).get_exposure_time ();

                if (exposure_time != 0) {
                    if (start_time == 0 || exposure_time < start_time)
                        start_time = exposure_time;

                    if (end_time == 0 || exposure_time > end_time)
                        end_time = exposure_time;
                }

                photo_count++;
            } else if (source is EventSource) {
                EventSource event_source = (EventSource) source;

                if (event_count == -1)
                    event_count = 0;

                if ((start_time == 0 || event_source.get_start_time () < start_time) &&
                        event_source.get_start_time () != 0 ) {
                    start_time = event_source.get_start_time ();
                }
                if ((end_time == 0 || event_source.get_end_time () > end_time) &&
                        event_source.get_end_time () != 0 ) {
                    end_time = event_source.get_end_time ();
                } else if (end_time == 0 || event_source.get_start_time () > end_time) {
                    end_time = event_source.get_start_time ();
                }

                int event_photo_count;
                int event_video_count;
                MediaSourceCollection.count_media (event_source.get_media (), out event_photo_count,
                                                   out event_video_count);

                photo_count += event_photo_count;
                video_count += event_video_count;
                event_count++;
            } else if (source is VideoSource || source is VideoImportSource) {
                time_t exposure_time = (source is VideoSource) ?
                                       ((VideoSource) source).get_exposure_time () :
                                       ((VideoImportSource) source).get_exposure_time ();

                if (exposure_time != 0) {
                    if (start_time == 0 || exposure_time < start_time)
                        start_time = exposure_time;

                    if (end_time == 0 || exposure_time > end_time)
                        end_time = exposure_time;
                }

                video_count++;
            }
        }
    }

    protected override void get_properties (Page current_page) {
        base.get_properties (current_page);

        if (end_time == 0)
            end_time = start_time;
        if (start_time == 0)
            start_time = end_time;
    }

    protected override void internal_update_properties (Page page) {
        base.internal_update_properties (page);

        if (title != "") {
            title_entry = new EditableTitle (null);
            title_entry.tooltip_text = _("Title");

            if (title != null) {
                title_entry.text = title;
            }

            title_entry.changed.connect (title_entry_changed);
            attach (title_entry, 0, 0, 2, 1);

            line_count++;
        }

        if (photo_count >= 0 || video_count >= 0) {
            string label = _ ("Items:");

            if (event_count >= 0) {
                string event_num_string = (ngettext ("%d Event", "%d Events", event_count)).printf (
                                              event_count);

                add_line (label, event_num_string);
                label = "";
            }

            string photo_num_string = (ngettext ("%d Photo", "%d Photos", photo_count)).printf (
                                          photo_count);
            string video_num_string = (ngettext ("%d Video", "%d Videos", video_count)).printf (
                                          video_count);

            if (photo_count == 0 && video_count > 0) {
                add_line (label, video_num_string);
                return;
            }

            add_line (label, photo_num_string);

            if (video_count > 0)
                add_line ("", video_num_string);
        }

        if (start_time != 0) {
            string start_date = get_prettyprint_date (Time.local (start_time));
            string start_time = get_prettyprint_time (Time.local (start_time));
            string end_date = get_prettyprint_date (Time.local (end_time));
            string end_time = get_prettyprint_time (Time.local (end_time));

            if (start_date == end_date) {
                if (start_time == end_time) {
                    var datetime_label = new Gtk.Label ("%s at %s".printf (start_date, start_time));
                    datetime_label.xalign = 0;
                    attach (datetime_label, 0, (int) line_count, 2, 1);
                    line_count++;
                } else {
                    add_line (_ ("Date:"), start_date);
                    // display time range
                    add_line (_ ("From:"), start_time);
                    add_line (_ ("To:"), end_time);
                }
            } else {
                // display date range
                add_line (_ ("From:"), start_date);
                add_line (_ ("To:"), end_date);
            }
        }

        if (gps_lat != -1 && gps_long != -1) {
            place_label = new Gtk.Label ("");
            place_label.no_show_all = true;
            place_label.visible = false;
            place_label.xalign = 0;

            create_place_label (gps_lat, gps_long);

            attach (place_label, 0, (int) line_count, 2, 1);

            line_count++;
        }

        if (dimensions.has_area ()) {
            var size_label = new Gtk.Label ("%s — %d &#215; %d".printf (format_size ((int64) filesize), dimensions.width, dimensions.height));
            size_label.use_markup = true;
            size_label.xalign = 0;
            attach (size_label, 0, (int) line_count, 2, 1);

            line_count++;
        }

        if (clip_duration > 0.0) {
            add_line (_ ("Duration:"), _ ("%.1f seconds").printf (clip_duration));
        }

        if (raw_developer != "") {
            add_line (_ ("Developer:"), raw_developer);
        }

        // RAW+JPEG flag.
        if (raw_assoc != "") {
            add_line ("", raw_assoc);
        }

        if (camera_make != "" && camera_model != "") {
            string camera_string;

            if (camera_make in camera_model) {
                camera_string = camera_model;
            } else {
                camera_string = camera_make + " " + camera_model;
            }

            var camera_label = new Gtk.Label (camera_string);
            camera_label.margin_top = 12;
            camera_label.xalign = 0;

            attach (camera_label, 0, 8, 2, 1);
        }

        var flowbox = new Gtk.FlowBox ();
        flowbox.column_spacing = 12;
        flowbox.row_spacing = 12;
        flowbox.hexpand = true;
        flowbox.margin_top = 12;
        flowbox.selection_mode = Gtk.SelectionMode.NONE;
        attach (flowbox, 0, 9, 2, 1);

        if (aperture != "") {
            var aperture_item = new ExifItem ("aperture-symbolic", _("Aperture"), aperture);
            flowbox.add (aperture_item);
        }

        if (focal_length != "") {
            var focal_length_item = new ExifItem ("focal-length-symbolic", _("Focal length"), focal_length);
            flowbox.add (focal_length_item);
        }

        if (exposure != "") {
            var exposure_item = new ExifItem ("exposure-symbolic", _("Exposure"), exposure);
            flowbox.add (exposure_item);
        }

        if (iso != "") {
            var iso_item = new ExifItem ("iso-symbolic", _("ISO"), iso);
            flowbox.add (iso_item);
        }

        if (exposure_bias != "") {
            var exposure_bias_item = new ExifItem ("exposure-bias-symbolic", _("Exposure bias"), exposure_bias);
            flowbox.add (exposure_bias_item);
        }

        if (flash != "") {
            var flash_item = new ExifItem ("flash-symbolic", _("Flash"), flash);
            flowbox.add (flash_item);
        }
    }

    public override void save_changes_to_source () {
        if (source != null && title != null && title != source.get_name ()) {
            AppWindow.get_command_manager ().execute (new EditTitleCommand (source, title));
        }
    }

    private async void create_place_label (double lat, double long) {
        var location = new Geocode.Location (lat, long);
        var reverse = new Geocode.Reverse.for_location (location);

        try {
            Geocode.Place place = yield reverse.resolve_async ();
            place_label.label = place.get_town () + ", " + place.get_state ();
            place_label.no_show_all = false;
            place_label.visible = true;
        } catch (Error e) {
            warning ("Failed to obtain place: %s", e.message);
        }
    }

    private void title_entry_changed () {
        title = title_entry.text;
    }

    private class ExifItem : Gtk.FlowBoxChild {
        public ExifItem (string icon_name, string tooltip_text, string data) {
            can_focus = false;

            var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.MENU);

            var label = new Gtk.Label (data);
            label.selectable = true;
            label.use_markup = true;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 6;
            grid.tooltip_text = _(tooltip_text);
            grid.add (icon);
            grid.add (label);

            add (grid);
            show_all ();
        }
    }
}
