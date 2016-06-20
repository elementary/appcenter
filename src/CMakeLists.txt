vala_precompile(VALA_C ${EXEC_NAME}
    Core/ChangeInformation.vala
    Core/Client.vala
    Core/Package.vala
    Core/Task.vala

    Application.vala
    MainWindow.vala
    Settings.vala
    SuspendControl.vala
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
    Widgets/PackageRow.vala
    ${CMAKE_CURRENT_BINARY_DIR}/config.vala
PACKAGES
    appstream
    gtk+-3.0>=3.12
    gee-0.8
    granite
    packagekit-glib2
    libxml-2.0
    ${UNITY_PACKAGES}
OPTIONS
  --vapidir=${CMAKE_SOURCE_DIR}/vapi
  --target-glib=2.32
  --thread
  ${UNITY_OPTIONS}
)

include (GResource)
glib_compile_resources (GLIB_RESOURCES_CATEGORIES SOURCE ../data/icons/categories.gresource.xml)

add_executable (${EXEC_NAME} ${VALA_C} ${GLIB_RESOURCES_CATEGORIES})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES} ${UNITY_LIBRARIES})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

