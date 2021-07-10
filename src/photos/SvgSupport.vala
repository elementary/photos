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

class SvgFileFormatProperties : PhotoFileFormatProperties {
    private static string[] KNOWN_EXTENSIONS = { "svg" };
    private static string[] KNOWN_MIME_TYPES = { "image/svg+xml" };

    private static SvgFileFormatProperties instance = null;

    public static void init () {
        instance = new SvgFileFormatProperties ();
    }

    public static SvgFileFormatProperties get_instance () {
        return instance;
    }

    public override PhotoFileFormat get_file_format () {
        return PhotoFileFormat.SVG;
    }

    public override PhotoFileFormatFlags get_flags () {
        return PhotoFileFormatFlags.NONE;
    }

    public override string get_user_visible_name () {
        return _ ("SVG");
    }

    public override string get_default_extension () {
        return KNOWN_EXTENSIONS[0];
    }

    public override string[] get_known_extensions () {
        return KNOWN_EXTENSIONS;
    }

    public override string get_default_mime_type () {
        return KNOWN_MIME_TYPES[0];
    }

    public override string[] get_mime_types () {
        return KNOWN_MIME_TYPES;
    }
}

public class SvgSniffer : GdkSniffer {


    public SvgSniffer (File file, PhotoFileSniffer.Options options) {
        base (file, options);
    }

    private static bool is_svg_file (File file) throws Error {
        Xml.Doc* doc = Xml.Parser.parse_file (file.get_parse_name ());

        if (doc == null)
            return false;

        Xml.Node* root = doc->get_root_element ();
        if (root == null) {
            delete doc;
            return false;
        }

        if (root->name != "svg") {
            delete doc;
            return false;
        }

        delete doc;
        return true;
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        if (!is_svg_file (file))
            return null;

        DetectedPhotoInformation? detected = base.sniff ();
        if (detected == null)
            return null;

        return (detected.file_format == PhotoFileFormat.SVG) ? detected : null;
    }
}

public class SvgReader : GdkReader {
    public SvgReader (string filepath) {
        base (filepath, PhotoFileFormat.SVG);
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

public class SvgWriter : PhotoFileWriter {
    public SvgWriter (string filepath) {
        base (filepath, PhotoFileFormat.SVG);
    }

    public override void write (Gdk.Pixbuf pixbuf, Jpeg.Quality quality) throws Error {
        pixbuf.save (get_filepath (), "png", null);
    }
}

public class SvgMetadataWriter : PhotoFileMetadataWriter {
    public SvgMetadataWriter (string filepath) {
        base (filepath, PhotoFileFormat.SVG);
    }

    public override void write_metadata (PhotoMetadata metadata) throws Error {
        metadata.write_to_file (get_file ());
    }
}

public class SvgFileFormatDriver : PhotoFileFormatDriver {
    private static SvgFileFormatDriver instance = null;

    public static void init () {
        instance = new SvgFileFormatDriver ();
        SvgFileFormatProperties.init ();
    }

    public static SvgFileFormatDriver get_instance () {
        return instance;
    }

    public override PhotoFileFormatProperties get_properties () {
        return SvgFileFormatProperties.get_instance ();
    }

    public override PhotoFileReader create_reader (string filepath) {
        return new SvgReader (filepath);
    }

    public override bool can_write_image () {
        return true;
    }

    public override bool can_write_metadata () {
        return true;
    }

    public override PhotoFileWriter? create_writer (string filepath) {
        return new SvgWriter (filepath);
    }

    public override PhotoFileMetadataWriter? create_metadata_writer (string filepath) {
        return new SvgMetadataWriter (filepath);
    }

    public override PhotoFileSniffer create_sniffer (File file, PhotoFileSniffer.Options options) {
        return new SvgSniffer (file, options);
    }

    public override PhotoMetadata create_metadata () {
        return new PhotoMetadata ();
    }
}

