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

namespace Photos {

public class TiffFileFormatDriver : PhotoFileFormatDriver {
    private static TiffFileFormatDriver instance = null;

    public static void init () {
        instance = new TiffFileFormatDriver ();
        TiffFileFormatProperties.init ();
    }

    public static TiffFileFormatDriver get_instance () {
        return instance;
    }

    public override PhotoFileFormatProperties get_properties () {
        return TiffFileFormatProperties.get_instance ();
    }

    public override PhotoFileReader create_reader (string filepath) {
        return new TiffReader (filepath);
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
        return new TiffWriter (filepath);
    }

    public override PhotoFileMetadataWriter? create_metadata_writer (string filepath) {
        return new TiffMetadataWriter (filepath);
    }

    public override PhotoFileSniffer create_sniffer (File file, PhotoFileSniffer.Options options) {
        return new TiffSniffer (file, options);
    }
}

private class TiffFileFormatProperties : PhotoFileFormatProperties {
    private static string[] known_extensions = {
        "tif", "tiff"
    };

    private static string[] known_mime_types = {
        "image/tiff"
    };

    private static TiffFileFormatProperties instance = null;

    public static void init () {
        instance = new TiffFileFormatProperties ();
    }

    public static TiffFileFormatProperties get_instance () {
        return instance;
    }

    public override PhotoFileFormat get_file_format () {
        return PhotoFileFormat.TIFF;
    }

    public override PhotoFileFormatFlags get_flags () {
        return PhotoFileFormatFlags.NONE;
    }

    public override string get_default_extension () {
        return "tif";
    }

    public override string get_user_visible_name () {
        return _ ("TIFF");
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

private class TiffSniffer : GdkSniffer {
    public TiffSniffer (File file, PhotoFileSniffer.Options options) {
        base (file, options);
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        if (!is_tiff (file))
            return null;

        DetectedPhotoInformation? detected = base.sniff ();
        if (detected == null)
            return null;

        return (detected.file_format == PhotoFileFormat.TIFF) ? detected : null;
    }
}

private class TiffReader : GdkReader {
    public TiffReader (string filepath) {
        base (filepath, PhotoFileFormat.TIFF);
    }
}

private class TiffWriter : PhotoFileWriter {
    private const string COMPRESSION_NONE = "1";
    private const string COMPRESSION_HUFFMAN = "2";
    private const string COMPRESSION_LZW = "5";
    private const string COMPRESSION_JPEG = "7";
    private const string COMPRESSION_DEFLATE = "8";

    public TiffWriter (string filepath) {
        base (filepath, PhotoFileFormat.TIFF);
    }

    public override void write (Gdk.Pixbuf pixbuf, Jpeg.Quality quality) throws Error {
        pixbuf.save (get_filepath (), "tiff", "compression", COMPRESSION_LZW);
    }
}

private class TiffMetadataWriter : PhotoFileMetadataWriter {
    public TiffMetadataWriter (string filepath) {
        base (filepath, PhotoFileFormat.TIFF);
    }

    public override void write_metadata (PhotoMetadata metadata) throws Error {
        metadata.write_to_file (get_file ());
    }
}

public bool is_tiff (File file, Cancellable? cancellable = null) throws Error {
    DataInputStream dins = new DataInputStream (file.read ());

    // first two bytes: "II" (0x4949, for Intel) or "MM" (0x4D4D, for Motorola)
    DataStreamByteOrder order;
    switch (dins.read_uint16 (cancellable)) {
    case 0x4949:
        order = DataStreamByteOrder.LITTLE_ENDIAN;
        break;

    case 0x4D4D:
        order = DataStreamByteOrder.BIG_ENDIAN;
        break;

    default:
        return false;
    }

    dins.set_byte_order (order);

    // second two bytes: some random number
    uint16 lue = dins.read_uint16 (cancellable);
    if (lue != 42)
        return false;

    // remaining bytes are offset of first IFD, which doesn't matter for our purposes
    return true;
}

}
