appcenter_files = files(
    'Application.vala',
    'MainWindow.vala',
    'Settings.vala',
    'SuspendControl.vala',
    'Utils.vala',
    'Core/ChangeInformation.vala',
    'Core/Client.vala',
    'Core/ComponentValidator.vala',
    'Core/Houston.vala',
    'Core/Package.vala',
    'Core/ScreenshotCache.vala',
    'Core/Task.vala',
    'Core/UpdateManager.vala',
    'Dialogs/RestartDialog.vala',
    'Dialogs/ContentWarningDialog.vala',
    'Dialogs/StripeDialog.vala',
    'Dialogs/UpdateFailDialog.vala',
    'Services/DBusInterfaces.vala',
    'Services/DBusServer.vala',
    'Services/SearchProvider.vala',
    'Views/AppInfoView.vala',
    'Views/AppListUpdateView.vala',
    'Views/AppListView.vala',
    'Views/Homepage.vala',
    'Views/InstalledView.vala',
    'Views/SearchView.vala',
    'Views/View.vala',
    'Widgets/AbstractAppList.vala',
    'Widgets/AppListRow.vala',
    'Widgets/Banner.vala',
    'Widgets/CardNumberEntry.vala',
    'Widgets/CategoryFlowBox.vala',
    'Widgets/CategoryItem.vala',
    'Widgets/HumbleButton.vala',
    'Widgets/HumblePopover.vala',
    'Widgets/PackageRow.vala',
    'Widgets/ReleaseListBox.vala',
    'Widgets/ReleaseRow.vala',
    'Widgets/SharePopover.vala',
    'Widgets/Switcher.vala',
    'Widgets/UpdateHeaderRow.vala',
    'Widgets/AppContainers/AbstractAppContainer.vala',
    'Widgets/AppContainers/AbstractPackageRowGrid.vala',
    'Widgets/AppContainers/InstalledPackageRowGrid.vala',
    'Widgets/AppContainers/ListPackageRowGrid.vala',
    'Widgets/Carousel/AuthorCarousel.vala',
    'Widgets/Carousel/Carousel.vala',
    'Widgets/Carousel/CarouselItem.vala'
)

config_file = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf_data
)

args = []
if get_option('curated')
    args += '--define=CURATED'
endif

if get_option('sharing')
    args += '--define=SHARING'
endif

executable(
    meson.project_name(),
    appcenter_files,
    config_file,
    css_gresource,
    icons_gresource,
    dependencies: dependencies,
    vala_args: args,
    install: true
)
