icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', 'app', i + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
        rename: meson.project_name() + '.svg'
    )
    install_data(
        join_paths('icons', 'app', i + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps'),
        rename: meson.project_name() + '.svg'
    )
endforeach

install_data(
    join_paths('icons', 'app', 'symbolic.svg'),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'symbolic', 'apps'),
    rename: meson.project_name() + '-symbolic.svg'
)

# GNOME Shell Search Provider
configure_file(
    input: meson.project_name() + '.search-provider.ini.in',
    output: meson.project_name() + '.search-provider.ini',
    configuration: conf_data,
    install_dir: join_paths(get_option('datadir'), 'gnome-shell', 'search-providers')
)

i18n.merge_file(
    input: 'appcenter.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

# Desktop File
desktop_in = configure_file(
    input: meson.project_name() + '.desktop.in.in',
    output: meson.project_name() + '.desktop.in',
    configuration: conf_data
)

i18n.merge_file(
    input: desktop_in,
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.project_source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    install: true
)

i18n.merge_file(
    input: 'io.elementary.appcenter.policy.in',
    output: 'io.elementary.appcenter.policy',
    po_dir: join_paths(meson.project_source_root (), 'po', 'extra'),
    install_dir: join_paths(get_option('datadir'), 'polkit-1', 'actions'),
    install: true
)

# Hidden app list file
install_data(
    'appcenter.hiddenapps',
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

subdir('styles')
