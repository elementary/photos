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

public class JfifFileFormatDriver : PhotoFileFormatDriver {
    private static JfifFileFormatDriver instance = null;

    public static void init () {
        instance = new JfifFileFormatDriver ();
        JfifFileFormatProperties.init ();
    }

    public static JfifFileFormatDriver get_instance () {
        return instance;
    }

    public override PhotoFileFormatProperties get_properties () {
        return JfifFileFormatProperties.get_instance ();
    }

    public override PhotoFileReader create_reader (string filepath) {
        return new JfifReader (filepath);
    }

    public override PhotoMetadata create_metadata () {
        return new PhotoMetadata ();
    }

    public override bool can_write_image () {
        return true;
    }

    public override bool can_write_metadata () {
        return true;
    }

    public override PhotoFileWriter? create_writer (string filepath) {
        return new JfifWriter (filepath);
    }

    public override PhotoFileMetadataWriter? create_metadata_writer (string filepath) {
        return new JfifMetadataWriter (filepath);
    }

    public override PhotoFileSniffer create_sniffer (File file, PhotoFileSniffer.Options options) {
        return new JfifSniffer (file, options);
    }
}

public class JfifFileFormatProperties : PhotoFileFormatProperties {
    private static string[] known_extensions = {
        "jpg", "jpeg", "jpe"
    };

    private static string[] known_mime_types = {
        "image/jpeg"
    };

    private static JfifFileFormatProperties instance = null;

    public static void init () {
        instance = new JfifFileFormatProperties ();
    }

    public static JfifFileFormatProperties get_instance () {
        return instance;
    }

    public override PhotoFileFormat get_file_format () {
        return PhotoFileFormat.JFIF;
    }

    public override PhotoFileFormatFlags get_flags () {
        return PhotoFileFormatFlags.NONE;
    }

    public override string get_default_extension () {
        return "jpg";
    }

    public override string get_user_visible_name () {
        return _ ("JPEG");
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

public class JfifSniffer : GdkSniffer {
    public JfifSniffer (File file, PhotoFileSniffer.Options options) {
        base (file, options);
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        if (!Jpeg.is_jpeg (file))
            return null;

        DetectedPhotoInformation? detected = base.sniff ();
        if (detected == null)
            return null;

        return (detected.file_format == PhotoFileFormat.JFIF) ? detected : null;
    }
}

public class JfifReader : GdkReader {
    public JfifReader (string filepath) {
        base (filepath, PhotoFileFormat.JFIF);
    }
}

public class JfifWriter : PhotoFileWriter {
    public JfifWriter (string filepath) {
        base (filepath, PhotoFileFormat.JFIF);
    }

    public override void write (Gdk.Pixbuf pixbuf, Jpeg.Quality quality) throws Error {
        pixbuf.save (get_filepath (), "jpeg", "quality", quality.get_pct_text ());
    }
}

public class JfifMetadataWriter : PhotoFileMetadataWriter {
    public JfifMetadataWriter (string filepath) {
        base (filepath, PhotoFileFormat.JFIF);
    }

    public override void write_metadata (PhotoMetadata metadata) throws Error {
        metadata.write_to_file (get_file ());
    }
}

namespace Jpeg {
public const uint8 MARKER_PREFIX = 0xFF;

public enum Marker {
    // Could also be 0xFF according to spec
    INVALID = 0x00,

    SOI = 0xD8,
    EOI = 0xD9,

    APP0 = 0xE0,
    APP1 = 0xE1;

    public uint8 get_byte () {
        return (uint8) this;
    }
}

public enum Quality {
    LOW = 50,
    MEDIUM = 75,
    HIGH = 90,
    MAXIMUM = 100;

    public int get_pct () {
        return (int) this;
    }

    public string get_pct_text () {
        return "%d".printf ((int) this);
    }

    public static Quality[] get_all () {
        return { LOW, MEDIUM, HIGH, MAXIMUM };
    }

    public string? to_string () {
        switch (this) {
        case LOW:
            return _ ("Low (%d%%)").printf ((int) this);

        case MEDIUM:
            return _ ("Medium (%d%%)").printf ((int) this);

        case HIGH:
            return _ ("High (%d%%)").printf ((int) this);

        case MAXIMUM:
            return _ ("Maximum (%d%%)").printf ((int) this);
        }

        warn_if_reached ();

        return null;
    }
}

public bool is_jpeg (File file) throws Error {
    FileInputStream fins = file.read (null);

    Marker marker;
    int segment_length = read_marker (fins, out marker);

    // for now, merely checking for SOI
    return (marker == Marker.SOI) && (segment_length == 0);
}

private int read_marker (FileInputStream fins, out Jpeg.Marker marker) throws Error {
    marker = Jpeg.Marker.INVALID;

    DataInputStream dins = new DataInputStream (fins);
    dins.set_byte_order (DataStreamByteOrder.BIG_ENDIAN);

    if (dins.read_byte () != Jpeg.MARKER_PREFIX)
        return -1;

    marker = (Jpeg.Marker) dins.read_byte ();
    if ((marker == Jpeg.Marker.SOI) || (marker == Jpeg.Marker.EOI)) {
        // no length
        return 0;
    }

    uint16 length = dins.read_uint16 ();
    if (length < 2) {
        debug ("Invalid length %Xh at ofs %" + int64.FORMAT + "Xh", length, fins.tell () - 2);

        return -1;
    }

    // account for two length bytes already read
    return length - 2;
}
}
