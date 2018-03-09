vala_precompile(VALA_C ${EXEC_NAME}
    Core/ChangeInformation.vala
    Core/Client.vala
    Core/Houston.vala
    Core/Package.vala
    Core/Task.vala
    Core/UpdateManager.vala
    Core/ComponentValidator.vala

    Application.vala
    MainWindow.vala
    Settings.vala
    SuspendControl.vala
    Dialogs/RestartDialog.vala
    Dialogs/StripeDialog.vala
    Views/AppInfoView.vala
    Views/AppListView.vala
    Views/AppListUpdateView.vala
    Views/Homepage.vala
    Views/InstalledView.vala
    Views/SearchView.vala
    Views/View.vala
    Widgets/AppContainers/AbstractAppContainer.vala
    Widgets/AppContainers/AbstractPackageRowGrid.vala
    Widgets/AppContainers/InstalledPackageRowGrid.vala
    Widgets/AppContainers/ListPackageRowGrid.vala
    Widgets/AbstractAppList.vala
    Widgets/Banner.vala
    Widgets/Carousel/Carousel.vala
    Widgets/Carousel/CarouselItem.vala
    Widgets/Carousel/AuthorCarousel.vala
    Widgets/CategoryFlowBox.vala
    Widgets/CategoryItem.vala
    Widgets/PackageRow.vala
    Widgets/AppListRow.vala
    Widgets/UpdateHeaderRow.vala
    Widgets/HumbleButton.vala
    Widgets/SharePopover.vala
    Widgets/Switcher.vala
    Widgets/ReleaseListBox.vala
    Widgets/ReleaseRow.vala
    Widgets/CardNumberEntry.vala
    Services/DBusInterfaces.vala
    Services/DBusServer.vala
    Services/SearchProvider.vala
    ${CMAKE_CURRENT_BINARY_DIR}/config.vala
PACKAGES
    appstream
    gtk+-3.0>=3.12
    gee-0.8
    granite>=0.5
    packagekit-glib2
    libsoup-2.4
    json-glib-1.0
    libxml-2.0
    ${UNITY_PACKAGES}
OPTIONS
  --vapidir=${CMAKE_SOURCE_DIR}/vapi
  --target-glib=2.32
  --thread
  ${CURATED_FLAG}
  ${UNITY_OPTIONS}
)

include (GResource)
glib_compile_resources (GLIB_RESOURCES_CATEGORIES SOURCE ../data/icons/categories.gresource.xml)
glib_compile_resources (GLIB_RESOURCES_CSS SOURCE ../data/io.elementary.appcenter.gresource.xml)

add_executable (${EXEC_NAME} ${VALA_C} ${GLIB_RESOURCES_CATEGORIES} ${GLIB_RESOURCES_CSS})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES} ${UNITY_LIBRARIES})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)
