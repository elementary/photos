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

public abstract class GdkReader : PhotoFileReader {
    protected GdkReader (string filepath, PhotoFileFormat file_format) {
        base (filepath, file_format);
    }

    public override PhotoMetadata read_metadata () throws Error {
        PhotoMetadata metadata = new PhotoMetadata ();
        metadata.read_from_file (get_file ());

        return metadata;
    }

    public override Gdk.Pixbuf unscaled_read () throws Error {
        return new Gdk.Pixbuf.from_file (get_filepath ());
    }

    public override Gdk.Pixbuf scaled_read (Dimensions full, Dimensions scaled) throws Error {
        return new Gdk.Pixbuf.from_file_at_scale (get_filepath (), scaled.width, scaled.height, false);
    }
}

public abstract class GdkSniffer : PhotoFileSniffer {
    private DetectedPhotoInformation detected = null;
    private bool size_ready = false;
    private bool area_prepared = false;

    protected GdkSniffer (File file, PhotoFileSniffer.Options options) {
        base (file, options);
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        detected = new DetectedPhotoInformation ();

        Gdk.PixbufLoader pixbuf_loader = new Gdk.PixbufLoader ();
        pixbuf_loader.size_prepared.connect (on_size_prepared);
        pixbuf_loader.area_prepared.connect (on_area_prepared);

        // valac chokes on the ternary operator here
        Checksum? md5_checksum = null;
        if (calc_md5)
            md5_checksum = new Checksum (ChecksumType.MD5);

        detected.metadata = new PhotoMetadata ();
        try {
            detected.metadata.read_from_file (file);
        } catch (Error err) {
            // no metadata detected
            detected.metadata = null;
        }

        if (calc_md5 && detected.metadata != null) {
            uint8[]? flattened_sans_thumbnail = detected.metadata.flatten_exif (false);
            if (flattened_sans_thumbnail != null && flattened_sans_thumbnail.length > 0)
                detected.exif_md5 = md5_binary (flattened_sans_thumbnail, flattened_sans_thumbnail.length);

            uint8[]? flattened_thumbnail = detected.metadata.flatten_exif_preview ();
            if (flattened_thumbnail != null && flattened_thumbnail.length > 0)
                detected.thumbnail_md5 = md5_binary (flattened_thumbnail, flattened_thumbnail.length);
        }

        // if no MD5, don't read as much, as the needed info will probably be gleaned
        // in the first 8K to 16K
        uint8[] buffer = calc_md5 ? new uint8[64 * 1024] : new uint8[8 * 1024];
        size_t count = 0;

        // loop through until all conditions we're searching for are met
        FileInputStream fins = file.read (null);
        for (;;) {
            size_t bytes_read = fins.read (buffer, null);
            if (bytes_read <= 0)
                break;

            count += bytes_read;

            if (calc_md5)
                md5_checksum.update (buffer, bytes_read);

            // keep parsing the image until the size is discovered
            if (!size_ready || !area_prepared)
                pixbuf_loader.write (buffer[0:bytes_read]);

            // if not searching for anything else, exit
            if (!calc_md5 && size_ready && area_prepared)
                break;
        }

        // PixbufLoader throws an error if you close it with an incomplete image, so trap this
        try {
            pixbuf_loader.close ();
        } catch (Error err) {
        }

        if (fins != null)
            fins.close (null);

        if (calc_md5)
            detected.md5 = md5_checksum.get_string ();

        return detected;
    }

    private void on_size_prepared (Gdk.PixbufLoader loader, int width, int height) {
        detected.image_dim = Dimensions (width, height);
        size_ready = true;
    }

    private void on_area_prepared (Gdk.PixbufLoader pixbuf_loader) {
        Gdk.Pixbuf? pixbuf = pixbuf_loader.get_pixbuf ();
        if (pixbuf == null)
            return;

        detected.colorspace = pixbuf.get_colorspace ();
        detected.channels = pixbuf.get_n_channels ();
        detected.bits_per_channel = pixbuf.get_bits_per_sample ();

        unowned Gdk.PixbufFormat format = pixbuf_loader.get_format ();
        detected.format_name = format.get_name ();
        detected.file_format = PhotoFileFormat.from_pixbuf_name (detected.format_name);

        area_prepared = true;
    }
}
