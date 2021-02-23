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

//
// Media sources
//

public abstract class ThumbnailSource : DataSource {
    public virtual signal void thumbnail_altered () {
    }

    protected ThumbnailSource (int64 object_id = INVALID_OBJECT_ID) {
        base (object_id);
    }

    public virtual void notify_thumbnail_altered () {
        // fire signal on self
        thumbnail_altered ();

        // signal reflection to DataViews
        contact_subscribers (subscriber_thumbnail_altered);
    }

    private void subscriber_thumbnail_altered (DataView view) {
        ((ThumbnailView) view).notify_thumbnail_altered ();
    }

    public abstract Gdk.Pixbuf? get_thumbnail (int scale) throws Error;

    // get_thumbnail( ) may return a cached pixbuf; create_thumbnail( ) is guaranteed to create
    // a new pixbuf (e.g., by the source loading, decoding, and scaling image data)
    public abstract Gdk.Pixbuf? create_thumbnail (int scale) throws Error;

    // A ThumbnailSource may use another ThumbnailSource as its representative.  It's up to the
    // subclass to forward on the appropriate methods to this ThumbnailSource.  But, since multiple
    // ThumbnailSources may be referring to a single ThumbnailSource, this allows for that to be
    // detected and optimized (in caching).
    //
    // Note that it's the responsibility of this ThumbnailSource to fire "thumbnail-altered" if its
    // representative does the same.
    //
    // Default behavior is to return the ID of this.
    public virtual string get_representative_id () {
        return get_source_id ();
    }

    public abstract PhotoFileFormat get_preferred_thumbnail_format ();
}

public abstract class PhotoSource : MediaSource {
    protected PhotoSource (int64 object_id = INVALID_OBJECT_ID) {
        base (object_id);
    }

    public abstract PhotoMetadata? get_metadata ();

    public abstract Gdk.Pixbuf get_pixbuf (Scaling scaling) throws Error;
}

public abstract class VideoSource : MediaSource {
}

//
// EventSource
//

public abstract class EventSource : ThumbnailSource {
    protected EventSource (int64 object_id = INVALID_OBJECT_ID) {
        base (object_id);
    }

    public abstract int64 get_start_time ();

    public abstract int64 get_end_time ();

    public abstract uint64 get_total_filesize ();

    public abstract int get_media_count ();

    public abstract Gee.Collection<MediaSource> get_media ();

    public abstract string? get_comment ();

    public abstract bool set_comment (string? comment);
}

//
// ContainerSource
//

public interface ContainerSource : DataSource {
    public abstract bool has_links ();

    public abstract SourceBacklink get_backlink ();

    public abstract void break_link (DataSource source);

    public abstract void break_link_many (Gee.Collection<DataSource> sources);

    public abstract void establish_link (DataSource source);

    public abstract void establish_link_many (Gee.Collection<DataSource> sources);
}
