# Photos
[![Packaging status](https://repology.org/badge/tiny-repos/elementary-photos.svg)](https://repology.org/metapackage/elementary-photos)
[![Translation status](https://l10n.elementary.io/widgets/photos/-/svg-badge.svg)](https://l10n.elementary.io/projects/photos/?utm_source=widget)

![Photos Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* desktop-file-utils
* intltool
* libexif-dev
* libgee-0.8-dev
* libgeocode-glib-dev
* libgexiv2-dev
* libglib2.0-dev
* libgphoto2-dev
* libgranite-dev >= 6.0.0
* libgstreamer1.0-dev
* libgstreamer-plugins-base1.0-dev
* libgtk-3-dev
* libgudev-1.0-dev
* libhandy-1-dev
* libportal
* libportal-gtk3
* libraw-dev
* libsqlite3-dev
* libwebp-dev
* meson >= 0.57.0
* valac >= 0.40

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `io.elementary.photos`

    sudo ninja install
    io.elementary.photos
