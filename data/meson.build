# Daemon Desktop file (for GNOME Session autostart)
configure_file(
    input: meson.project_name() + '-daemon.desktop.in',
    output: '@BASENAME@',
    configuration: conf_data,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# D-Bus Service
configure_file(
    input: meson.project_name() + '.service.in',
    output: '@BASENAME@',
    configuration: conf_data,
    install_dir: dbus.get_pkgconfig_variable('session_bus_services_dir')
)

# GNOME Shell Search Provider
configure_file(
    input: meson.project_name() + '.search-provider.ini.in',
    output: '@BASENAME@',
    configuration: conf_data,
    install_dir: join_paths(get_option('datadir'), 'gnome-shell', 'search-providers')
)

# AppData file
i18n.merge_file(
    input: meson.project_name() + '.appdata.xml.in',
    output: '@BASENAME@',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'xml',
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
    install: true
)

# Desktop File
desktop_in = configure_file(
    input: meson.project_name() + '.desktop.in.in',
    output: '@BASENAME@',
    configuration: conf_data
)

i18n.merge_file(
    input: desktop_in,
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    install: true
)

# Blacklist file
install_data(
    'appcenter.blacklist',
    install_dir: config_dir,
)

# Install GSettings schemas
install_data(
    'io.elementary.appcenter.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

# Use GResource
css_gresource = gnome.compile_resources(
    'gresource_css',
    meson.project_name() + '.gresource.xml'
)

icons_gresource = gnome.compile_resources(
    'gresource_icons',
    'icons/categories.gresource.xml',
    source_dir: 'icons'
)
