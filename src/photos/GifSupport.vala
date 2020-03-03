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

class GifFileFormatProperties : PhotoFileFormatProperties {
    private static string[] known_extensions = { "gif" };
    private static string[] known_mime_types = { "image/gif" };

    private static GifFileFormatProperties instance = null;

    public static void init () {
        instance = new GifFileFormatProperties ();
    }

    public static GifFileFormatProperties get_instance () {
        return instance;
    }

    public override PhotoFileFormat get_file_format () {
        return PhotoFileFormat.GIF;
    }

    public override PhotoFileFormatFlags get_flags () {
        return PhotoFileFormatFlags.NONE;
    }

    public override string get_user_visible_name () {
        return _ ("GIF");
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

public class GifSniffer : GdkSniffer {
    private const uint8[] MAGIC_SEQUENCE_GIF87 = { 71, 73, 70, 56, 55, 97 };
    private const uint8[] MAGIC_SEQUENCE_GIF89 = { 71, 73, 70, 56, 57, 97 };

    public GifSniffer (File file, PhotoFileSniffer.Options options) {
        base (file, options);
    }

    private static bool is_gif_file (File file) throws Error {
        FileInputStream instream = file.read (null);

        uint8[] file_lead_sequence = new uint8[MAGIC_SEQUENCE_GIF87.length];

        instream.read (file_lead_sequence, null);

        bool is_gif_87 = true;

        for (int i = 0; i < MAGIC_SEQUENCE_GIF87.length; i++) {
            if (file_lead_sequence[i] != MAGIC_SEQUENCE_GIF87[i]) {
                is_gif_87 = false;
            }
        }

        if (is_gif_87) {
            return true;
        } else {
            instream.seek (0, SeekType.SET);

            file_lead_sequence = new uint8[MAGIC_SEQUENCE_GIF89.length];

            instream.read (file_lead_sequence, null);

            bool is_gif_89 = true;

            for (int i = 0; i < MAGIC_SEQUENCE_GIF89.length; i++) {
                if (file_lead_sequence[i] != MAGIC_SEQUENCE_GIF89[i]) {
                    is_gif_89 = false;
                }
            }

            return is_gif_89;
        }
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        if (!is_gif_file (file))
            return null;

        DetectedPhotoInformation? detected = base.sniff ();

        if (detected == null) {
            return null;
        }

        return (detected.file_format == PhotoFileFormat.GIF) ? detected : null;
    }
}

public class GifReader : GdkReader {
    public GifReader (string filepath) {
        base (filepath, PhotoFileFormat.GIF);
    }

    public override Gdk.Pixbuf scaled_read (Dimensions full, Dimensions scaled) throws Error {
        Gdk.Pixbuf result = null;
        /* if we encounter a situation where there are two orders of magnitude or more of
           difference between the full image size and the scaled size, and if the full image
           size has five or more decimal digits of precision, Gdk.Pixbuf.from_file_at_scale( ) can
           fail due to what appear to be floating-point round-off issues. This isn't surprising,
           since 32-bit floats only have 6-7 decimal digits of precision in their mantissa. In
           this case, we prefetch the image at a larger scale and then downsample it to the
           desired scale as a post-process step. This short-circuits Gdk.Pixbuf's buggy
           scaling code. */
        if (((full.width > 9999) || (full.height > 9999)) && ((scaled.width < 100) ||
        (scaled.height < 100))) {
            Dimensions prefetch_dimensions = full.get_scaled_by_constraint (1000,
            ScaleConstraint.DIMENSIONS);

            result = new Gdk.Pixbuf.from_file_at_scale (get_filepath (), prefetch_dimensions.width,
            prefetch_dimensions.height, false);

            result = result.scale_simple (scaled.width, scaled.height, Gdk.InterpType.HYPER);
        } else {
            result = new Gdk.Pixbuf.from_file_at_scale (get_filepath (), scaled.width,
            scaled.height, false);
        }

        return result;
    }
}

public class GifFileFormatDriver : PhotoFileFormatDriver {
    private static GifFileFormatDriver instance = null;

    public static void init () {
        instance = new GifFileFormatDriver ();
        GifFileFormatProperties.init ();
    }

    public static GifFileFormatDriver get_instance () {
        return instance;
    }

    public override PhotoFileFormatProperties get_properties () {
        return GifFileFormatProperties.get_instance ();
    }

    public override PhotoFileReader create_reader (string filepath) {
        return new GifReader (filepath);
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
        return new GifSniffer (file, options);
    }

    public override PhotoMetadata create_metadata () {
        return new PhotoMetadata ();
    }
}
