appcenter_files = files(
    'Application.vala',
    'AsyncMutex.vala',
    'MainWindow.vala',
    'SuspendControl.vala',
    'Utils.vala',
    'Core/BackendAggregator.vala',
    'Core/BackendInterface.vala',
    'Core/CardUtils.vala',
    'Core/ChangeInformation.vala',
    'Core/Client.vala',
    'Core/ComponentValidator.vala',
    'Core/FlatpakBackend.vala',
    'Core/HttpClient.vala',
    'Core/Job.vala',
    'Core/Houston.vala',
    'Core/Package.vala',
    'Core/ScreenshotCache.vala',
    'Core/SoupClient.vala',
    'Core/Stripe.vala',
    'Core/UpdateManager.vala',
    'Dialogs/InstallFailDialog.vala',
    'Dialogs/RepairFailDialog.vala',
    'Dialogs/StripeDialog.vala',
    'Dialogs/UninstallConfirmDialog.vala',
    'Dialogs/UninstallFailDialog.vala',
    'Dialogs/UpdateFailDialog.vala',
    'Dialogs/UpgradeFailDialog.vala',
    'Services/DBusServer.vala',
    'Services/SearchProvider.vala',
    'Views/AppInfoView.vala',
    'Views/AppListUpdateView.vala',
    'Views/AuthorView.vala',
    'Views/CategoryView.vala',
    'Views/Homepage.vala',
    'Views/SearchView.vala',
    'Widgets/Banner.vala',
    'Widgets/CardNumberEntry.vala',
    'Widgets/HumbleButton.vala',
    'Widgets/PackageRow.vala',
    'Widgets/ReleaseRow.vala',
    'Widgets/SharePopover.vala',
    'Widgets/SizeLabel.vala',
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

if appstream.version().version_compare('>=0.16')
    args += '--define=HAS_APPSTREAM_0_16'
endif

if get_option('packagekit_backend')
    appcenter_files += files(
        'Core/PackageKitBackend.vala',
        'Core/Task.vala',
    )

    args += '--define=PACKAGEKIT_BACKEND'
endif

if get_option('ubuntu_drivers_backend')
    if not get_option('packagekit_backend')
        error('Option ubuntu_drivers requires option packagekit_backend')
    endif

    appcenter_files += files('Core/UbuntuDriversBackend.vala')

    args += '--define=UBUNTU_DRIVERS_BACKEND'
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
