vala_precompile(VALA_C ${EXEC_NAME}
    Core/Client.vala
    Core/Package.vala

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
    Widgets/PackageRow.vala
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

add_executable (${EXEC_NAME} ${VALA_C})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES}) 

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

