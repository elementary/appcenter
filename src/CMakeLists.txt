vala_precompile(VALA_C ${EXEC_NAME}
    Core/ChangeInformation.vala
    Core/Client.vala
    Core/Houston.vala
    Core/Package.vala
    Core/Task.vala

    Application.vala
    MainWindow.vala
    Settings.vala
    SuspendControl.vala
    Dialogs/MessageDialog.vala
    Dialogs/RestartDialog.vala
    Dialogs/StripeDialog.vala
    Views/AppInfoView.vala
    Views/AppListView.vala
    Views/Homepage.vala
    Views/InstalledView.vala
    Views/SearchView.vala
    Views/View.vala
    Widgets/AbstractAppContainer.vala
    Widgets/AbstractAppList.vala
    Widgets/Banner.vala
    Widgets/Carousel/Carousel.vala
    Widgets/Carousel/CarouselItem.vala
    Widgets/CategoryFlowBox.vala
    Widgets/CategoryItem.vala
    Widgets/PackageRow.vala
    Widgets/AppListRow.vala
    Widgets/UpdateHeaderRow.vala
    Widgets/HumbleButton.vala
    Widgets/Switcher.vala
    Services/DbusInterfaces.vala
    Services/DBusServer.vala
    ${CMAKE_CURRENT_BINARY_DIR}/config.vala
PACKAGES
    appstream
    gtk+-3.0>=3.12
    gee-0.8
    granite
    packagekit-glib2
    libsoup-2.4 
    json-glib-1.0
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

