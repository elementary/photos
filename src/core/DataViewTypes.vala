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

public class ThumbnailView : DataView {
    public virtual signal void thumbnail_altered () {
    }

    public ThumbnailView (ThumbnailSource source) {
        Object (source: source);
    }

    public virtual void notify_thumbnail_altered () {
        // fire signal on self
        thumbnail_altered ();
    }
}

public class PhotoView : ThumbnailView {
    public PhotoView (PhotoSource source) {
        Object (source: source);
    }

    public PhotoSource get_photo_source () {
        return (PhotoSource) source;
    }
}

public class VideoView : ThumbnailView {
    public VideoView (VideoSource source) {
        Object (source: source);
    }

    public VideoSource get_video_source () {
        return (VideoSource) source;
    }
}

public class EventView : ThumbnailView {
    public EventView (EventSource source) {
        Object (source: source);
    }

    public EventSource get_event_source () {
        return (EventSource) source;
    }
}

