// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

class WebPFileFormatProperties : PhotoFileFormatProperties {
    private static string[] known_extensions = { "webp" };
    private static string[] known_mime_types = { "image/webp" };

    private static WebPFileFormatProperties instance = null;

    public static void init () {
        instance = new WebPFileFormatProperties ();
    }

    public static WebPFileFormatProperties get_instance () {
        return instance;
    }

    public override PhotoFileFormat get_file_format () {
        return PhotoFileFormat.WEBP;
    }

    public override PhotoFileFormatFlags get_flags () {
        return PhotoFileFormatFlags.NONE;
    }

    public override string get_user_visible_name () {
        return _ ("WebP");
    }

    public override string get_default_extension () {
        return known_extensions[0];
    }

    public override string[] get_known_extensions () {
        return known_extensions;
    }

    public override string get_default_mime_type () {
        return known_mime_types[0];
    }

    public override string[] get_mime_types () {
        return known_mime_types;
    }
}

public class WebPSniffer : PhotoFileSniffer {
    private const uint8[] MAGIC_SEQUENCE_RIFF = { 0x52, 0x49, 0x46, 0x46 };
    private const uint8[] MAGIC_SEQUENCE_WEBP = { 0x57, 0x45, 0x42, 0x50 };

    public WebPSniffer (File file, PhotoFileSniffer.Options options) {
        base (file, options);
    }

    private static bool is_webp_file (File file) throws Error {
        FileInputStream instream = file.read (null);

        uint8[] file_lead_sequence = new uint8[MAGIC_SEQUENCE_RIFF.length];

        instream.read (file_lead_sequence, null);

        for (int i = 0; i < MAGIC_SEQUENCE_RIFF.length; i++) {
            if (file_lead_sequence[i] != MAGIC_SEQUENCE_RIFF[i]) {
                return false;
            }
        }

        // skip 4 bytes
        instream.read (new uint8[4], null);

        file_lead_sequence = new uint8[MAGIC_SEQUENCE_WEBP.length];

        instream.read (file_lead_sequence, null);

        for (int i = 0; i < MAGIC_SEQUENCE_WEBP.length; i++) {
            if (file_lead_sequence[i] != MAGIC_SEQUENCE_WEBP[i]) {
                return false;
            }
        }

        return true;
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        if (!is_webp_file (file))
            return null;

        DetectedPhotoInformation detected = new DetectedPhotoInformation ();

        uint8[] contents;
        file.load_contents (null, out contents, null);

        WebP.BitstreamFeatures features;
        var status = WebP.get_features (contents, out features);
        if (status != WebP.StatusCode.OK) {
            warning ("Error opening WebP file %s: %s", file.get_path (), status.to_string ());
            return null;
        }

        detected.image_dim = Dimensions (features.width, features.height);
        detected.bits_per_channel = 8;
        detected.channels = features.has_alpha ? 4 : 3;


        if (calc_md5)
            detected.md5 = md5_file (file);

        detected.format_name = "webp";
        detected.file_format = PhotoFileFormat.WEBP;

        return detected;
    }
}

public class WebPReader : PhotoFileReader {
    public WebPReader (string filepath) {
        base (filepath, PhotoFileFormat.WEBP);
    }

    public override Gdk.Pixbuf scaled_read (Dimensions full, Dimensions scaled) throws Error {
        return unscaled_read ().scale_simple (scaled.width, scaled.height, Gdk.InterpType.BILINEAR);
    }

    public override Gdk.Pixbuf unscaled_read () throws Error {
        var file = get_file ();

        uint8[] contents;
        file.load_contents (null, out contents, null);

        WebP.BitstreamFeatures features;
        var status = WebP.get_features (contents, out features);
        if (status != WebP.StatusCode.OK) {
            throw new IOError.FAILED ("Error opening WebP file %s: %s", file.get_path (), status.to_string ());
        }

        uint8[] webp_data;
        int width, height;
        if (features.has_alpha) {
            webp_data = WebP.decode_rgba (contents, out width, out height);
        } else {
            webp_data = WebP.decode_rgb (contents, out width, out height);
        }

        int rowstride = (features.has_alpha ? 4 : 3) * width;
        var result = new Gdk.Pixbuf.with_unowned_data (webp_data, Gdk.Colorspace.RGB, features.has_alpha,
                                                       8, width, height, rowstride);

        uint8[] png_data;
        result.save_to_buffer (out png_data, "png");
        var loader = new Gdk.PixbufLoader ();
        loader.write (png_data);
        result = loader.get_pixbuf ();
        loader.close ();

        return result;
    }

    public override PhotoMetadata read_metadata () {
        return new PhotoMetadata ();
    }
}

public class WebPFileFormatDriver : PhotoFileFormatDriver {
    private static WebPFileFormatDriver instance = null;

    public static void init () {
        instance = new WebPFileFormatDriver ();
        WebPFileFormatProperties.init ();
    }

    public static WebPFileFormatDriver get_instance () {
        return instance;
    }

    public override PhotoFileFormatProperties get_properties () {
        return WebPFileFormatProperties.get_instance ();
    }

    public override PhotoFileReader create_reader (string filepath) {
        return new WebPReader (filepath);
    }

    public override bool can_write_image () {
        return false;
    }

    public override bool can_write_metadata () {
        return false;
    }

    public override PhotoFileWriter? create_writer (string filepath) {
        return null;
    }

    public override PhotoFileMetadataWriter? create_metadata_writer (string filepath) {
        return null;
    }

    public override PhotoFileSniffer create_sniffer (File file, PhotoFileSniffer.Options options) {
        return new WebPSniffer (file, options);
    }

    public override PhotoMetadata create_metadata () {
        return new PhotoMetadata ();
    }
}
