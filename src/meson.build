appcenter_files = files(
    'Application.vala',
    'AsyncMutex.vala',
    'MainWindow.vala',
    'SuspendControl.vala',
    'Utils.vala',
    'Core/CardUtils.vala',
    'Core' / 'CategoryManager.vala',
    'Core/ChangeInformation.vala',
    'Core/FlatpakBackend.vala',
    'Core/HttpClient.vala',
    'Core/Job.vala',
    'Core/Houston.vala',
    'Core/Package.vala',
    'Core/ScreenshotCache.vala',
    'Core/SearchEngine.vala',
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
    'Widgets/ActionStack.vala',
    'Widgets/AppIcon.vala',
    'Widgets/BackButton.vala',
    'Widgets/Banner.vala',
    'Widgets/CardNumberEntry.vala',
    'Widgets/HumbleButton.vala',
    'Widgets/LinkListBox.vala',
    'Widgets/ProgressButton.vala',
    'Widgets/ReleaseRow.vala',
    'Widgets/SizeLabel.vala',
    'Widgets' / 'SearchListItem.vala',
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

if get_option('hide_upstream_distro_apps')
    args += '--define=HIDE_UPSTREAM_DISTRO_APPS'
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
