pkg_check_modules (UNITY unity>=4.0.0)

if (UNITY_FOUND)
  set (UNITY_OPTIONS -D HAVE_UNITY)
  set (UNITY_PACKAGES unity)
  add_definitions(${UNITY_CFLAGS})
  link_directories(${UNITY_LIBRARY_DIRS})
endif ()

set(DAEMON_EXEC_NAME ${CMAKE_PROJECT_NAME}-daemon)

vala_precompile(DAEMON_VALA_C ${DAEMON_EXEC_NAME}
    Daemon.vala
    ${CMAKE_BINARY_DIR}/src/config.vala
PACKAGES
    appstream
    gtk+-3.0>=3.12
    gee-0.8
    granite
    packagekit-glib2
    ${UNITY_PACKAGES}
OPTIONS
  --vapidir=${CMAKE_SOURCE_DIR}/vapi
  --target-glib=2.32
  --thread
  ${UNITY_OPTIONS}
)

add_executable(${DAEMON_EXEC_NAME} ${DAEMON_VALA_C})
target_link_libraries(${DAEMON_EXEC_NAME} ${DEPS_LIBRARIES} ${UNITY_LIBRARIES} -lm)

install(TARGETS ${DAEMON_EXEC_NAME} RUNTIME DESTINATION bin)
