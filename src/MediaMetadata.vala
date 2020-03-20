/*
* Copyright (c) 2010-2013 Yorba Foundation
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

public abstract class MediaMetadata {
    protected MediaMetadata () {
    }

    public abstract void read_from_file (File file) throws Error;

    public abstract MetadataDateTime? get_creation_date_time ();

    public abstract string? get_title ();

    public abstract string? get_comment ();
}

public struct MetadataRational {
    public int numerator;
    public int denominator;

    public MetadataRational (int numerator, int denominator) {
        this.numerator = numerator;
        this.denominator = denominator;
    }

    private bool is_component_valid (int component) {
        return (component >= 0) && (component <= 1000000);
    }

    public bool is_valid () {
        return (is_component_valid (numerator) && is_component_valid (denominator));
    }

    public string to_string () {
        return (is_valid ()) ? ("%d/%d".printf (numerator, denominator)) : "";
    }
}

public errordomain MetadataDateTimeError {
    INVALID_FORMAT,
    UNSUPPORTED_FORMAT
}

public class MetadataDateTime {

    private time_t timestamp;

    public MetadataDateTime (time_t timestamp) {
        this.timestamp = timestamp;
    }

    public MetadataDateTime.from_exif (string label) throws MetadataDateTimeError {
        if (!from_exif_date_time (label, out timestamp))
            throw new MetadataDateTimeError.INVALID_FORMAT ("%s is not EXIF format date/time", label);
    }

    public MetadataDateTime.from_iptc (string date, string time) throws MetadataDateTimeError {
        // TODO: Support IPTC date/time format
        throw new MetadataDateTimeError.UNSUPPORTED_FORMAT ("IPTC date/time format not currently supported");
    }

    public MetadataDateTime.from_xmp (string label) throws MetadataDateTimeError {
        TimeVal time_val = TimeVal ();
        if (!time_val.from_iso8601 (label))
            throw new MetadataDateTimeError.INVALID_FORMAT ("%s is not XMP format date/time", label);

        timestamp = time_val.tv_sec;
    }

    public time_t get_timestamp () {
        return timestamp;
    }

    public string get_exif_label () {
        return to_exif_date_time (timestamp);
    }

    // TODO: get_iptc_date () and get_iptc_time ()

    public string get_xmp_label () {
        TimeVal time_val = TimeVal ();
        time_val.tv_sec = timestamp;
        time_val.tv_usec = 0;

        return time_val.to_iso8601 ();
    }

    public static bool from_exif_date_time (string date_time, out time_t timestamp) {
        timestamp = 0;

        Time tm = Time ();

        // Check standard EXIF format
        if (date_time.scanf ("%d:%d:%d %d:%d:%d",
                             &tm.year, &tm.month, &tm.day, &tm.hour, &tm.minute, &tm.second) != 6) {
            // Fallback in a more generic format
            string tmp = date_time.dup ();
            tmp.canon ("0123456789", ' ');
            if (tmp.scanf ("%4d%2d%2d%2d%2d%2d",
                           &tm.year, &tm.month, &tm.day, &tm.hour, &tm.minute, &tm.second) != 6)
                return false;
        }

        // watch for bogosity
        if (tm.year <= 1900 || tm.month <= 0 || tm.day < 0 || tm.hour < 0 || tm.minute < 0 || tm.second < 0)
            return false;

        tm.year -= 1900;
        tm.month--;
        tm.isdst = -1;

        timestamp = tm.mktime ();

        return true;
    }

    public static string to_exif_date_time (time_t timestamp) {
        return Time.local (timestamp).format ("%Y:%m:%d %H:%M:%S");
    }

    public string to_string () {
        return to_exif_date_time (timestamp);
    }
}
