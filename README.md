# Photos
[![Translation status](https://l10n.elementary.io/widgets/photos/-/svg-badge.svg)](https://l10n.elementary.io/projects/photos/?utm_source=widget)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* desktop-file-utils
* intltool
* libaccounts-glib-dev
* libexif-dev
* libgee-0.8-dev
* libgeocode-glib-dev
* libgexiv2-dev
* libglib2.0-dev
* libgphoto2-dev
* libgranite-dev
* libgstreamer1.0-dev
* libgstreamer-plugins-base1.0-dev
* libgtk-3-dev
* libgudev-1.0-dev
* libjson-glib-dev
* libraw-dev
* librest-dev
* libsignon-glib-dev
* libsoup2.4-dev
* libsqlite3-dev
* libunity-dev
* libwebkit2gtk-4.0-dev
* libwebp-dev
* libxml2
* python-scour
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`, then execute with `io.elementary.photos`

    sudo make install
    io.elementary.photos
