set (SUBMODULE_NAME video-thumbnailer)
vala_precompile (VALA_C ${SUBMODULE_NAME}
    shotwell-video-thumbnailer.vala
PACKAGES
    ${DEPS_PACKAGES}
OPTIONS
    ${GLOBAL_VALA_OPTIONS}
)

add_executable (${SUBMODULE_NAME} ${VALA_C})
target_link_libraries (${SUBMODULE_NAME} ${DEPS_LIBRARIES}) 

install (TARGETS ${SUBMODULE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_FULL_LIBEXECDIR}/${CMAKE_PROJECT_NAME})

