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
    private int64 timestamp;

    public MetadataDateTime (int64 timestamp) {
        this.timestamp = timestamp;
    }

    public MetadataDateTime.from_exif (string label) throws MetadataDateTimeError {
        if (!from_exif_date_time (label, out timestamp))
            throw new MetadataDateTimeError.INVALID_FORMAT ("%s is not EXIF format date/time", label);
    }

    public MetadataDateTime.from_xmp (string label) throws MetadataDateTimeError {
        DateTime? date_time = new DateTime.from_iso8601 (label, null);
        if (date_time == null)
            throw new MetadataDateTimeError.INVALID_FORMAT ("%s is not XMP format date/time", label);

        timestamp = date_time.to_unix ();
    }

    public int64 get_timestamp () {
        return timestamp;
    }

    public string get_exif_label () {
        return (new DateTime.from_unix_utc (timestamp)).format ("%Y:%m:%d %H:%M:%S");
    }

    public string get_xmp_label () {
        var date_time = new DateTime.from_unix_utc (timestamp);
        return date_time.format_iso8601 ();
    }

    private static bool from_exif_date_time (string date_time_s, out int64 timestamp) {
        timestamp = 0;

        // Check standard EXIF format
        int year = 0;
        int month = 0;
        int day = 0;
        int hour = 0;
        int minute = 0;
        int second = 0;

        if (date_time_s.scanf ("%d:%d:%d %d:%d:%d",
                             &year, &month, &day, &hour, &minute, &second) != 6) {
            // Fallback in a more generic format
            string tmp = date_time_s.dup ();
            tmp.canon ("0123456789", ' ');
            if (tmp.scanf ("%4d%2d%2d%2d%2d%2d",
                           year, month, day, hour, minute, second) != 6) {
                return false;
            }
        }

        // watch for bogosity
        if (year <= 0 || month <= 0 || day < 0 || hour < 0 || minute < 0 || second < 0) {
            return false;
        }

        if (month > 12 || hour >= 24 || minute >= 60 || second >= 60) {
            return false;
        }

        switch (month) {
            case 4:
            case 6:
            case 9:
            case 11:
                if (day > 30) {
                    return false;
                }
                break;
            case 2:
                // Oops, no leap check, this will cause errors if metadata claims to be from February 29th on a non-leap-year
                // It may be safer to just forbid parsing dates for any feburary 29th
                if (day > 29) {
                    return false;
                }
                break;
            default:
                if (day > 31) {
                    return false;
                }
                break;
        }

        var date_time = new DateTime.local (year, month, day, hour, minute, (double) second);
        timestamp = date_time.to_unix ();

        return true;
    }
}
