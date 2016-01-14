include (Translations)
configure_file (${CMAKE_PROJECT_NAME}.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}.desktop.in)
configure_file (${CMAKE_PROJECT_NAME}-viewer.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}-viewer.desktop.in)
configure_file_translation (${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation (${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}-viewer.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}-viewer.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation (${CMAKE_CURRENT_SOURCE_DIR}/${CMAKE_PROJECT_NAME}.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}.desktop DESTINATION ${DATADIR}/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}-viewer.desktop DESTINATION ${DATADIR}/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_PROJECT_NAME}.appdata.xml DESTINATION ${DATADIR}/appdata)

# Install custom icons
file (GLOB ICON_FILES icons/*)
install (FILES ${ICON_FILES} DESTINATION ${PKGDATADIR}/icons)

# Install UI files
file (GLOB UI_FILES ui/*)
install (FILES ${UI_FILES} DESTINATION ${PKGDATADIR}/ui)

