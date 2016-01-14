
set(TARGET_NAME "pantheon-photos-publishing")
vala_precompile (VALA_C ${TARGET_NAME}
    FacebookPublishing.vala
    FlickrPublishing.vala
    PicasaPublishing.vala
    PiwigoPublishing.vala
    shotwell-publishing.vala
    YouTubePublishing.vala
    Resources.vala
    RESTSupport.vala
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/config.vapi
PACKAGES
    ${DEPS_PACKAGES}
    ${CMAKE_PROJECT_NAME}
OPTIONS
    ${GLOBAL_VALA_OPTIONS}
)

add_library(${TARGET_NAME} MODULE ${VALA_C})

include_directories (${CMAKE_SOURCE_DIR}/vapi)
target_link_libraries(${TARGET_NAME} ${DEPS_LIBRARIES})
add_dependencies(${TARGET_NAME} ${EXEC_NAME})

install(TARGETS ${TARGET_NAME} DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}/${CMAKE_PROJECT_NAME}/plugins/builtin/)

# Install custom icons
file (GLOB ICON_FILES *.png)
install (FILES ${ICON_FILES} DESTINATION ${PKGDATADIR}/plugins/builtin)

# Install UI files
file (GLOB UI_FILES *.glade)
install (FILES ${UI_FILES} DESTINATION ${PKGDATADIR}/plugins/builtin)
