appcenter_files = files(
    'Application.vala',
    'AsyncMutex.vala',
    'MainWindow.vala',
    'SuspendControl.vala',
    'Utils.vala',
    'Core/BackendAggregator.vala',
    'Core/BackendInterface.vala',
    'Core/ChangeInformation.vala',
    'Core/Client.vala',
    'Core/ComponentValidator.vala',
    'Core/FlatpakBackend.vala',
    'Core/Job.vala',
    'Core/Package.vala',
    'Core/PackageKitBackend.vala',
    'Core/ScreenshotCache.vala',
    'Core/Task.vala',
    'Core/UbuntuDriversBackend.vala',
    'Core/UpdateManager.vala',
    'Dialogs/InstallFailDialog.vala',
    'Dialogs/NonCuratedWarningDialog.vala',
    'Dialogs/StripeDialog.vala',
    'Dialogs/UninstallConfirmDialog.vala',
    'Dialogs/UninstallFailDialog.vala',
    'Dialogs/UpdateFailDialog.vala',
    'Dialogs/UpgradeFailDialog.vala',
    'Services/DBusServer.vala',
    'Services/SearchProvider.vala',
    'Views/AppInfoView.vala',
    'Views/AppListUpdateView.vala',
    'Views/AppListView.vala',
    'Views/CategoryView.vala',
    'Views/Homepage.vala',
    'Views/InstalledView.vala',
    'Views/SearchView.vala',
    'Views/AbstractView.vala',
    'Widgets/AbstractAppList.vala',
    'Widgets/Banner.vala',
    'Widgets/CardNumberEntry.vala',
    'Widgets/CategoryFlowBox.vala',
    'Widgets/CategoryItem.vala',
    'Widgets/HumbleButton.vala',
    'Widgets/NetworkInfoBar.vala',
    'Widgets/PackageRow.vala',
    'Widgets/ReleaseListBox.vala',
    'Widgets/ReleaseRow.vala',
    'Widgets/SharePopover.vala',
    'Widgets/SizeLabel.vala',
    'Widgets/UpdateHeaderRow.vala',
    'Widgets/AppContainers/AbstractAppContainer.vala',
    'Widgets/AppContainers/AbstractPackageRowGrid.vala',
    'Widgets/AppContainers/InstalledPackageRowGrid.vala',
    'Widgets/AppContainers/ListPackageRowGrid.vala'
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

if get_option('payments')
    args += '--define=PAYMENTS'
endif

if get_option('sharing')
    args += '--define=SHARING'
endif

if get_option('hide_upstream_distro_apps')
    args += '--define=HIDE_UPSTREAM_DISTRO_APPS'
endif

if appstream.version().version_compare('>=0.15')
    args += '--define=HAS_APPSTREAM_0_15'
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
