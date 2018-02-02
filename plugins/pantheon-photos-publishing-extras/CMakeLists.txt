
set(TARGET_NAME pantheon-photos-publishing-extra)
vala_precompile (VALA_C ${TARGET_NAME}
    shotwell-publishing-extras.vala
    YandexPublishing.vala
    TumblrPublishing.vala
    Resources.vala
    RESTSupport.vala
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/config.vapi
    ${CMAKE_BINARY_DIR}/src/${CMAKE_PROJECT_NAME}.vapi
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    ${GLOBAL_VALA_OPTIONS}
)

include (GResource)
glib_compile_resources(GRESOURCES_PUBLISHING_EXTRAS SOURCE io.elementary.photos.plugins.publishing-extras.gresource.xml)

add_library(${TARGET_NAME} MODULE ${VALA_C} ${GRESOURCES_PUBLISHING_EXTRAS})

include_directories (${CMAKE_SOURCE_DIR}/vapi)
target_link_libraries(${TARGET_NAME} ${DEPS_LIBRARIES})
add_dependencies(${TARGET_NAME} ${EXEC_NAME})

install(TARGETS ${TARGET_NAME} DESTINATION ${BUILTIN_DIR})
