find_package (PkgConfig)

pkg_check_modules (DEPS REQUIRED gthread-2.0 gee-0.8 gtk+-3.0 granite packagekit-glib2 appstream)

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.26" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    ./Application.vala
    ./MainWindow.vala
    ./Views/AppInfoView.vala
    ./Views/AppListView.vala
    ./Views/FeaturedView.vala
    ./Views/CategoryView.vala
    ./Views/SearchView.vala
    ./Views/InstalledView.vala
    ./Widgets/AppCellRenderer.vala
    ./Widgets/CategoryItem.vala
    ./Widgets/FeaturedButton.vala
#TODO: Move these into a separate lib
    ./Core/Utils.vala
    ./Core/Client.vala
    ./Core/Info.vala
    ./Core/Details.vala
    ./Core/Summary.vala
    ./Core/Category.vala
    ./Core/OperationEnum.vala
    ${CMAKE_CURRENT_BINARY_DIR}/config.vala
PACKAGES
    appstream
    gtk+-3.0>=3.12
    gee-0.8
    granite
    packagekit-glib2
OPTIONS
  --vapidir=${CMAKE_SOURCE_DIR}/vapi
  --target-glib=2.32
  --thread
)

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

add_executable (${EXEC_NAME} ${VALA_C})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES}) 

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

