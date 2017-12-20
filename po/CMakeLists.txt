include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../data
    ../plugins
    ../src
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/org.pantheon.photos-viewer.desktop.in
        ${CMAKE_BINARY_DIR}/data/org.pantheon.photos.desktop.in
    APPDATA_FILES
        ../data/io.elementary.photos.appdata.xml.in
)
