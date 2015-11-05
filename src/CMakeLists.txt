find_package (PkgConfig)

pkg_check_modules (DEPS REQUIRED gthread-2.0 gee-0.8 gtk+-3.0 granite packagekit-glib2 appstream)
pkg_check_modules (UNITY unity>=4.0.0)

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.26" MINIMUM)

if (UNITY_FOUND)
  set (UNITY_OPTIONS -D HAVE_UNITY)
  set (UNITY_PACKAGES unity)
endif ()

include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    Core/Utils.vala
    Core/Client.vala
    Core/Info.vala
    Core/Details.vala
    Core/Summary.vala
    Core/Category.vala
    Core/Package.vala
    Core/OperationEnum.vala

    Application.vala
    MainWindow.vala
    Settings.vala
    Views/AppInfoView.vala
    Views/AppListView.vala
    Views/FeaturedView.vala
    Views/CategoryView.vala
    Views/SearchView.vala
    Views/InstalledView.vala
    Views/View.vala
    Widgets/AppCellRenderer.vala
    Widgets/CategoryItem.vala
    Widgets/FeaturedButton.vala
    ${CMAKE_CURRENT_BINARY_DIR}/config.vala
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

add_definitions (${DEPS_CFLAGS} ${UNITY_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS} ${UNITY_LIBRARY_DIRS})

add_executable (${EXEC_NAME} ${VALA_C})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES} ${UNITY_LIBRARIES}) 

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

