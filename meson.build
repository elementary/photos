project(
    'io.elementary.photos',
    'vala', 'c',
    version: '8.0.0',
    meson_version: '>=0.58.0'
)

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

granite_dep = dependency('granite-7')
gtk_dep = dependency('gtk4')

dependencies = [
    granite_dep,
    gtk_dep,
]

gnome.post_install(glib_compile_schemas: true)

subdir('data')
subdir('src')
