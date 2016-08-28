include (Translations)
configure_file (org.pantheon.photos.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos.desktop.in)
configure_file (org.pantheon.photos-viewer.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos-viewer.desktop.in)
configure_file_translation (${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation (${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos-viewer.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos-viewer.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation (${CMAKE_CURRENT_SOURCE_DIR}/org.pantheon.photos.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos.desktop DESTINATION ${DATADIR}/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos-viewer.desktop DESTINATION ${DATADIR}/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.photos.appdata.xml DESTINATION ${DATADIR}/appdata)

# Install custom icons
file (GLOB ICON_FILES icons/*)
install (FILES ${ICON_FILES} DESTINATION ${PKGDATADIR}/icons)

# Install UI files
file (GLOB UI_FILES ui/*)
install (FILES ${UI_FILES} DESTINATION ${PKGDATADIR}/ui)

