project(
    'io.elementary.appcenter',
    'vala', 'c',
    version: '7.4.0',
    meson_version: '>=0.57.0'
)

gettext_name = meson.project_name()
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    '-DHANDY_USE_UNSTABLE_API',
    '-DI_KNOW_THE_PACKAGEKIT_GLIB2_API_IS_SUBJECT_TO_CHANGE',
    language:'c'
)

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

glib = dependency ('glib-2.0')
gobject = dependency ('gobject-2.0')
gio = dependency ('gio-2.0')
gee = dependency ('gee-0.8')
gtk = dependency ('gtk+-3.0', version: '>=3.10')
granite = dependency ('granite', version: '>=6.0.0')
handy = dependency('libhandy-1', version: '>=1.4.0')
appstream = dependency ('appstream', version: '>=0.15.2')
libsoup = dependency ('libsoup-3.0')
json = dependency ('json-glib-1.0')
flatpak = dependency ('flatpak')
xml = dependency ('libxml-2.0')
polkit = dependency ('polkit-gobject-1')
portal = dependency('libportal')
portal_gtk3 = dependency('libportal-gtk3')
posix = meson.get_compiler('vala').find_library('posix')

dbus = dependency ('dbus-1')

core_deps = [
    glib,
    gobject,
    gio,
    json,
    libsoup,
]

dependencies = core_deps + [
    gtk,
    granite,
    handy,
    appstream,
    flatpak,
    xml,
    polkit,
    portal,
    portal_gtk3,
    posix
]

if get_option('packagekit_backend')
    dependencies += [dependency ('packagekit-glib2')]
endif

config_dir = join_paths(get_option('sysconfdir'), meson.project_name())
conf_data = configuration_data()
conf_data.set('PROJECT_NAME', meson.project_name())
conf_data.set('EXEC_NAME', meson.project_name())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('APP_NAME', get_option('name'))
conf_data.set('HIDDEN_APP_LIST', get_option('hidden_app_list_file'))
conf_data.set('VERSION', meson.project_version())
conf_data.set('RUNTIME_NAME', get_option('runtime_name'))
conf_data.set('CONFIGDIR', config_dir)
conf_data.set('EXEC_PATH', join_paths (get_option('prefix'), get_option('bindir'), meson.project_name()))
conf_data.set('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))

subdir('data')
subdir('src')
subdir('po')
subdir('test')

gnome.post_install(glib_compile_schemas: true)
