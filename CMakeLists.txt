project (appcenter)

cmake_minimum_required (VERSION 2.8)

# tell cmake where its modules can be found in our project directory
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set (EXEC_NAME ${CMAKE_PROJECT_NAME})
set (APP_NAME "App Center")
set (RELEASE_NAME "An elementary app center.")
set (DESKTOP_ICON "system-software-installer")
set (VERSION "0.1")
set (VERSION_INFO "Alpha")
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/config.vala.cmake ${CMAKE_BINARY_DIR}/src/config.vala)
add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (-w)
add_definitions (-DI_KNOW_THE_PACKAGEKIT_GLIB2_API_IS_SUBJECT_TO_CHANGE)

add_subdirectory (src)
add_subdirectory (data)
add_subdirectory (po)
add_subdirectory (schemas)
