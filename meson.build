project(
    'io.elementary.appcenter',
    'vala', 'c',
    version: '0.2.9')

gettext_name = meson.project_name()
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    '-DI_KNOW_THE_PACKAGEKIT_GLIB2_API_IS_SUBJECT_TO_CHANGE',
    language:'c'
)

gee = dependency ('gee-0.8')
gtk = dependency ('gtk+-3.0', version: '>=3.10')
granite = dependency ('granite', version: '>=0.4.2')
packagekit = dependency ('packagekit-glib2')
appstream = dependency ('appstream', version: '>=0.10.0')
libsoup = dependency ('libsoup-2.4')
json = dependency ('json-glib-1.0')

dbus = dependency ('dbus-1')

dependencies = [
    gee,
    gtk,
    granite,
    packagekit,
    appstream,
    libsoup,
    json
]

if get_option('libunity')
    dependencies += dependency ('unity', version: '>=4.0.0')
    add_project_arguments('--define=HAVE_UNITY', language: 'vala')
endif

config_dir = join_paths(get_option('sysconfdir'), meson.project_name())
conf_data = configuration_data()
conf_data.set('PROJECT_NAME', meson.project_name())
conf_data.set('DESKTOP_ICON', get_option('icon'))
conf_data.set('EXEC_NAME', meson.project_name())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('APP_NAME', get_option('name'))
conf_data.set('BLACKLIST', get_option('blacklist_file'))
conf_data.set('VERSION', meson.project_version())
conf_data.set('CONFIGDIR', config_dir)
conf_data.set('EXEC_PATH', join_paths (get_option('prefix'), get_option('bindir'), meson.project_name()))

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('meson/post_install.py')
