/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2018 elementary LLC. (https://elementary.io)
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
    private class CameraImportJob : BatchImportJob {
        private GPhoto.ContextWrapper context;
        private ImportSource import_file;
        private GPhoto.Camera camera;
        private string fulldir;
        private string filename;
        private uint64 filesize;
        private PhotoMetadata metadata;
        private int64 exposure_time;
        private CameraImportJob? associated = null;
        private BackingPhotoRow? associated_file = null;
        private DuplicatedFile? duplicated_file;
        private GLib.Settings file_settings;

        public CameraImportJob (GPhoto.ContextWrapper context, ImportSource import_file,
                                DuplicatedFile? duplicated_file = null) {
            file_settings = new GLib.Settings (GSettingsConfigurationEngine.FILES_PREFS_SCHEMA_NAME);

            this.context = context;
            this.import_file = import_file;
            this.duplicated_file = duplicated_file;

            // stash everything called in prepare (), as it may/will be called from a separate thread
            camera = import_file.camera;
            fulldir = import_file.get_fulldir ();
            // this should've been caught long ago when the files were first enumerated
            assert (fulldir != null);
            filename = import_file.filename;
            filesize = import_file.file_size;
            metadata = (import_file is PhotoImportSource) ?
                       ((PhotoImportSource)import_file).get_metadata () : null;
            exposure_time = import_file.get_exposure_time ();
        }

        public int64 get_exposure_time () {
            return exposure_time;
        }

        public override DuplicatedFile? get_duplicated_file () {
            return duplicated_file;
        }

        public override int64 get_exposure_time_override () {
            return (import_file is VideoImportSource) ? get_exposure_time () : 0;
        }

        public override string get_dest_identifier () {
            return filename;
        }

        public override string get_source_identifier () {
            return import_file.filename;
        }

        public override string get_basename () {
            return filename;
        }

        public override string get_path () {
            return fulldir;
        }

        public override void set_associated (BatchImportJob associated) {
            this.associated = associated as CameraImportJob;
        }

        public ImportSource get_source () {
            return import_file;
        }

        public override bool is_directory () {
            return false;
        }

        public override bool determine_file_size (out uint64 filesize, out File file) {
            file = null;
            filesize = this.filesize;

            return true;
        }

        public override bool prepare (out File file_to_import, out bool copy_to_library) throws Error {
            file_to_import = null;
            copy_to_library = false;

            File dest_file = null;
            try {
                bool collision;
                dest_file = LibraryFiles.generate_unique_file (filename, metadata, exposure_time,
                out collision);
            } catch (Error err) {
                warning ("Unable to generate local file for %s: %s", import_file.filename,
                err.message);
            }

            if (dest_file == null) {
                message ("Unable to generate local file for %s", import_file.filename);

                return false;
            }

            // always blacklist the copied images from the LibraryMonitor, otherwise it'll think
            // they should be auto-imported
            LibraryMonitor.blacklist_file (dest_file, "CameraImportJob.prepare");
            try {
                GPhoto.save_image (context.context, camera, fulldir, filename, dest_file);
            } finally {
                LibraryMonitor.unblacklist_file (dest_file);
            }

            // Copy over associated file, if it exists.
            if (associated != null) {
                try {
                    associated_file =
                    RawDeveloper.CAMERA.create_backing_row_for_development (dest_file.get_path (),
                    associated.get_basename ());
                } catch (Error err) {
                    warning ("Unable to generate backing associated file for %s: %s", associated.filename,
                             err.message);
                }

                if (associated_file == null) {
                    message ("Unable to generate backing associated file for %s", associated.filename);
                    return false;
                }

                File assoc_dest = File.new_for_path (associated_file.filepath);
                LibraryMonitor.blacklist_file (assoc_dest, "CameraImportJob.prepare");
                try {
                    GPhoto.save_image (context.context, camera, associated.fulldir, associated.filename,
                                       assoc_dest);
                } finally {
                    LibraryMonitor.unblacklist_file (assoc_dest);
                }
            }

            file_to_import = dest_file;
            copy_to_library = false;

            return true;
        }

        public override bool complete (MediaSource source, BatchImportRoll import_roll) throws Error {
            bool ret = false;
            if (source is Photo) {
                Photo photo = source as Photo;

                // Associate paired JPEG with RAW photo.
                if (associated_file != null) {
                    photo.add_backing_photo_for_development (RawDeveloper.CAMERA, associated_file);
                    ret = true;
                    photo.set_raw_developer (
                        RawDeveloper.from_string (file_settings.get_string ("raw-developer-default"))
                    );
                }
            }
            return ret;
        }
    }
