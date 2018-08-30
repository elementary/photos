/*
* Copyright (c) 2011-2013 Yorba Foundation
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

public class MediaViewTracker : Core.ViewTracker {
    public MediaAccumulator all = new MediaAccumulator ();
    public MediaAccumulator visible = new MediaAccumulator ();
    public MediaAccumulator selected = new MediaAccumulator ();

    public MediaViewTracker (ViewCollection collection) {
        base (collection);

        start (all, visible, selected);
    }
}

public class MediaAccumulator : Object, Core.TrackerAccumulator {
    public int total = 0;
    public int photos = 0;
    public int videos = 0;
    public int raw = 0;
    public int flagged = 0;

    public bool include (DataObject object) {
        DataSource source = ((DataView) object).source;

        total++;

        Photo? photo = source as Photo;
        if (photo != null) {
            if (photo.get_master_file_format () == PhotoFileFormat.RAW) {
                raw++;
            }

            if (photo.get_master_file_format () != PhotoFileFormat.RAW ||
                    photo.is_raw_developer_available (RawDeveloper.CAMERA)) {
                photos++;
            }
        } else if (source is VideoSource) {
            videos++;
        }

        Flaggable? flaggable = source as Flaggable;
        if (flaggable != null && flaggable.is_flagged ())
            flagged++;

        // because of total, always fire "updated"
        return true;
    }

    public bool uninclude (DataObject object) {
        DataSource source = ((DataView) object).source;

        if (total < 1) {
            warning ("Tried to remove DataObject %s from empty %s (%s)".printf (object.to_string (),
                     get_type ().name (), to_string ()));
            return false;
        }
        total--;

        Photo? photo = source as Photo;
        if (photo != null) {
            if (photo.get_master_file_format () == PhotoFileFormat.RAW) {
                assert (raw > 0);
                raw--;
            }

            if (photo.get_master_file_format () != PhotoFileFormat.RAW ||
                    photo.is_raw_developer_available (RawDeveloper.CAMERA)) {
                assert (photos > 0);
                photos--;
            }
        } else if (source is Video) {
            assert (videos > 0);
            videos--;
        }

        Flaggable? flaggable = source as Flaggable;
        if (flaggable != null && flaggable.is_flagged ()) {
            assert (flagged > 0);
            flagged--;
        }

        // because of total, always fire "updated"
        return true;
    }

    public bool altered (DataObject object, Alteration alteration) {
        // the only alteration that can happen to MediaSources this accumulator is concerned with is
        // flagging; typeness and raw-ness don't change at runtime
        if (!alteration.has_detail ("metadata", "flagged"))
            return false;

        Flaggable? flaggable = ((DataView) object).source as Flaggable;
        if (flaggable == null)
            return false;

        if (flaggable.is_flagged ()) {
            flagged++;
        } else {
            assert (flagged > 0);
            flagged--;
        }

        return true;
    }

    public string to_string () {
        return "%d photos/%d videos/%d raw/%d flagged".printf (photos, videos, raw, flagged);
    }
}

