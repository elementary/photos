/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class BasicProperties : Properties {
    protected string title;
    private time_t start_time = time_t ();
    private time_t end_time = time_t ();
    private Dimensions dimensions;
    private int photo_count;
    private int event_count;
    private int video_count;
    private string exposure;
    private string focal_length;
    private string aperture;
    private string iso;
    private double clip_duration;
    private string raw_developer;
    private string raw_assoc;

    public BasicProperties () {
    }

    public override string get_header_title () {
        return Resources.BASIC_PROPERTIES_LABEL;
    }

    protected override void clear_properties () {
        base.clear_properties ();
        title = "";
        start_time = 0;
        end_time = 0;
        dimensions = Dimensions (0, 0);
        focal_length = "";
        photo_count = -1;
        event_count = -1;
        video_count = -1;
        exposure = "";
        aperture = "";
        iso = "";
        clip_duration = 0.0;
        raw_developer = "";
        raw_assoc = "";
    }

    protected override void get_single_properties (DataView view) {
        base.get_single_properties (view);

        DataSource source = view.get_source ();

        title = source.get_name ();

        if (source is PhotoSource || source is PhotoImportSource) {
            start_time = (source is PhotoSource) ? ((PhotoSource) source).get_exposure_time () :
                         ((PhotoImportSource) source).get_exposure_time ();
            end_time = start_time;

            PhotoMetadata ? metadata = (source is PhotoSource) ? ((PhotoSource) source).get_metadata () :
                                       ((PhotoImportSource) source).get_metadata ();

            if (metadata != null) {
                exposure = metadata.get_exposure_string ();
                if (exposure == null)
                    exposure = "";

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

        // display the title if a Tag page
        if (title == "" && page is TagPage)
            title = ((TagPage) page).get_tag ().get_user_visible_name ();

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
                // display only one date if start and end are the same
                add_line (_ ("Date:"), start_date);

                if (start_time == end_time) {
                    // display only one time if start and end are the same
                    add_line (_ ("Time:"), start_time);
                } else {
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

        if (dimensions.has_area ()) {
            string label = _ ("Size:");

            if (dimensions.has_area ()) {
                add_line (label, "%d &#215; %d".printf (dimensions.width, dimensions.height));
                label = "";
            }
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

        var flowbox = new Gtk.FlowBox ();
        flowbox.column_spacing = 12;
        flowbox.row_spacing = 12;
        flowbox.hexpand = true;
        flowbox.margin_top = 12;
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
    }

    private class ExifItem : Gtk.Grid {
        public ExifItem (string icon_name, string tooltip_text, string data) {
            var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.MENU);
            icon.tooltip_text = _(tooltip_text);

            var label = new Gtk.Label (data);
            label.selectable = true;
            label.use_markup = true;

            column_spacing = 6;
            add (icon);
            add (label);
        }
    }
}
