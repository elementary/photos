
set(TARGET_NAME pantheon-photos-transitions)
vala_precompile (VALA_C ${TARGET_NAME}
    BlindsEffect.vala
    ChessEffect.vala
    CircleEffect.vala
    CirclesEffect.vala
    ClockEffect.vala
    CrumbleEffect.vala
    FadeEffect.vala
    shotwell-transitions.vala
    SlideEffect.vala
    SquaresEffect.vala
    StripesEffect.vala
    Resources.vala
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/config.vapi
    ${CMAKE_BINARY_DIR}/src/${CMAKE_PROJECT_NAME}.vapi
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    ${GLOBAL_VALA_OPTIONS}
)

include (GResource)
glib_compile_resources(GRESOURCES_TRANSITIONS SOURCE io.elementary.photos.plugins.transitions.gresource.xml)

add_library(${TARGET_NAME} MODULE ${VALA_C} ${GRESOURCES_TRANSITIONS})

include_directories (${CMAKE_SOURCE_DIR}/vapi)
target_link_libraries(${TARGET_NAME} ${DEPS_LIBRARIES})
add_dependencies(${TARGET_NAME} ${EXEC_NAME})

install(TARGETS ${TARGET_NAME} DESTINATION ${BUILTIN_DIR})
