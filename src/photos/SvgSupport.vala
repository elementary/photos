/**
 * Copyright (C) 2018 Adam Bieńkowski
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

    private static Xml.Node* get_node_by_name (Xml.Node* node, string name) {
        for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
            if (iter->name == name) {
                return iter;
            }
        }

        return null;
    }

    private static string? get_xml_string (Xml.Node* node, string[] path) {
        Xml.Node* current = node;
        for (int i = 0; i < path.length && current != null; i++) {
            current = get_node_by_name (current, path[i]);
        }

        return current != null ? current->get_content () : null;
    }

    private void parse_metadata (Rsvg.Handle handle, DetectedPhotoInformation detected) {
        unowned string metadata = handle.get_metadata ();
        Xml.Doc* doc = Xml.Parser.parse_memory (metadata, metadata.length);
        if (doc == null) {
            return;
        }

        Xml.Node* root = doc->get_root_element ();
        if (root == null) {
            delete doc;
            return;
        }

        Xml.Node* data = get_node_by_name (root, "cc:Work");
        if (data == null) {
            delete doc;
            return;
        }

        for (Xml.Node* iter = data->children; iter != null; iter = iter->next) {
            switch (iter->name) {
                case "dc:title":
                    detected.metadata.set_title (iter->get_content ());
                    break;
                case "dc:description":
                    detected.metadata.set_comment (iter->get_content ());
                    break;
                case "dc:creator":
                    string? author = get_xml_string (iter, { "cc:Agent", "dc:title" });
                    if (author != null) {
                        detected.metadata.set_string ("Exif.Image.Artist", author);
                    }

                    break;
            }
        }

        delete doc;
    }

    public override DetectedPhotoInformation? sniff () throws Error {
        Rsvg.Handle handle;
        try {
            handle = new Rsvg.Handle.from_file (file.get_path ());
        } catch (Error e) {
            return null;
        }

        DetectedPhotoInformation? detected = base.sniff ();
        if (detected == null || detected.file_format != PhotoFileFormat.SVG) {
            return null;
        }

        if (detected.metadata != null) {
            parse_metadata (handle, detected);
        }

        detected.image_dim = Dimensions (handle.width, handle.height);
        return detected;
    }
}

public class SvgReader : GdkReader {
    public SvgReader (string filepath) {
        base (filepath, PhotoFileFormat.SVG);
    }

    public override Gdk.Pixbuf unscaled_read () throws Error {
        return Rsvg.pixbuf_from_file (get_filepath ());
    }

    public override Gdk.Pixbuf scaled_read (Dimensions full, Dimensions scaled) throws Error {
        return Rsvg.pixbuf_from_file_at_size (get_filepath (), scaled.width, scaled.height);
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
        return new SvgSniffer (file, options);
    }

    public override PhotoMetadata create_metadata () {
        return new PhotoMetadata ();
    }
}