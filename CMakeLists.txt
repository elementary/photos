project (pantheon-photos)

cmake_minimum_required (VERSION 2.8)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

include (GNUInstallDirs)
set (DATADIR "${CMAKE_INSTALL_FULL_DATAROOTDIR}")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set (EXEC_NAME ${CMAKE_PROJECT_NAME})
set (APP_NAME "Photos")
set (VERSION "0.2")
set (VERSION_INFO "Alpha")
set (DOLLAR "$")

option (BUILD_PLUGINS "Whether to build plugins or not." ON)

add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (-w)

set (DEPS_PKG
    gee-0.8>=0.8.5
    gexiv2>=0.4.90
    geocode-glib-1.0
    gio-unix-2.0>=2.20
    glib-2.0>=2.30.0
    gmodule-2.0>=2.24.0
    gstreamer-1.0>=1.0.0
    gstreamer-base-1.0>=1.0.0
    gstreamer-plugins-base-1.0>=1.0.0
    gstreamer-pbutils-1.0>=1.0.0
    granite
    gtk+-3.0>=3.6.0
    gudev-1.0>=145
    json-glib-1.0
    libexif>=0.6.16
    libgphoto2>=2.4.2
    libraw>=0.13.2
    libsoup-2.4>=2.26.0
    libxml-2.0>=2.6.32
    rest-0.7>=0.7
    sqlite3>=3.5.9
    webkit2gtk-4.0>=2.0.0
)

set (DEPS_PACKAGES
    atk
    gdk-3.0
    gee-0.8
    geocode-glib-1.0
    gexiv2
    gio-unix-2.0
    glib-2.0
    gmodule-2.0
    granite
    gstreamer-1.0
    gstreamer-base-1.0
    gstreamer-pbutils-1.0
    gtk+-3.0
    gudev-1.0
    libexif
    libgphoto2
    json-glib-1.0
    libraw
    libsoup-2.4
    libxml-2.0
    sqlite3
    webkit2gtk-4.0
    # Custom .vapis
    ExtendedPosix
    LConv
    unique-3.0
)

set (GLOBAL_VALA_OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --target-glib=2.32
    --thread
    # Remove it when vala bindings are no more experimental (see https://bugzilla.gnome.org/show_bug.cgi?id=719597)
    --enable-experimental
)

find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED ${DEPS_PKG})
pkg_check_modules (UNITY QUIET unity)
if (UNITY_FOUND)
    message("-- Unity support enabled")
    set (DEPS_CFLAGS ${DEPS_CFLAGS} ${UNITY_CFLAGS})
    set (DEPS_LIBRARY_DIRS ${DEPS_LIBRARY_DIRS} ${UNITY_LIBRARY_DIRS})
    set (DEPS_LIBRARIES ${DEPS_LIBRARIES} ${UNITY_LIBRARIES})
    set (DEPS_PACKAGES ${DEPS_PACKAGES} unity)
    set (GLOBAL_VALA_OPTIONS ${GLOBAL_VALA_OPTIONS} --define UNITY_SUPPORT)
else ()
    message("-- Unity support disabled")
endif ()

add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.26" MINIMUM)

include (ValaPrecompile)

add_subdirectory (po)
add_subdirectory (data)
add_subdirectory (schemas)
add_subdirectory (src)
add_subdirectory (thumbnailer)
add_subdirectory (plugins)

