project(
    'io.elementary.photos',
    'vala', 'c',
    version: '2.7.1',
    meson_version: '>=0.46.0'
)

add_project_arguments([
        '-Wno-discarded-qualifiers',
        '-Wno-incompatible-pointer-types',
        '-Wno-unused',
        '-Wl,--enable-new-dtags',

        '-include', 'config.h',
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())
    ],
    language: 'c',
)
add_project_arguments([
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi'),
        '--pkg', 'config',
    ],
    language: 'vala',
)

libexecdir = join_paths(get_option('prefix'), get_option('libexecdir'), meson.project_name())
pluginsdir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')

conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('_VERSION', meson.project_version())
conf_data.set_quoted('_PREFIX', get_option('prefix'))
conf_data.set_quoted('_LIB', join_paths(get_option('prefix'), get_option('libdir')))
conf_data.set_quoted('_LIBEXECDIR', libexecdir)
config_header = configure_file(
    output : 'config.h',
    configuration : conf_data
)

gnome = import('gnome')
i18n = import('i18n')

glib_dep = dependency('glib-2.0', version: '>=2.30.0')
gio_unix_dep = dependency('gio-unix-2.0', version: '>=2.20')
gee_dep = dependency('gee-0.8', version: '>=0.8.5')
gexiv2_dep = dependency('gexiv2', version: '>=0.4.90')
if gexiv2_dep.version().version_compare('>= 0.11')
  add_global_arguments(['--define=GEXIV2_0_11'], language : 'vala')
endif
geocode_glib_dep = dependency('geocode-glib-1.0')
gmodule_dep = dependency('gmodule-2.0', version: '>=2.24.0')
gstreamer_dep = dependency('gstreamer-1.0', version: '>=1.0.0')
gstreamer_base_dep = dependency('gstreamer-base-1.0', version: '>=1.0.0')
gstreamer_plugins_base_dep = dependency('gstreamer-plugins-base-1.0', version: '>=1.0.0')
gstreamer_pbutils_dep = dependency('gstreamer-pbutils-1.0', version: '>=1.0.0')
granite_dep = dependency('granite', version: '>=6.0.0')
gtk_dep = dependency('gtk+-3.0', version: '>=3.6.0')
gudev_dep = dependency('gudev-1.0', version: '>=145')
handy = dependency('libhandy-1')
json_glib_dep = dependency('json-glib-1.0')
libexif_dep = dependency('libexif', version: '>=0.6.16')
gphoto2_dep = dependency('libgphoto2', version: '>=2.4.2')
libraw_dep = dependency('libraw', version: '>=0.13.2')
libwebp_dep = dependency('libwebp', version: '>=0.4.4')
libsoup_dep = dependency('libsoup-2.4', version: '>=2.26.0')
libxml_dep = dependency('libxml-2.0', version: '>=2.6.32')
rest_dep = dependency('rest-0.7', version: '>=0.7')
sqlite3_dep = dependency('sqlite3', version: '>=3.5.9')
webkit2gtk_dep = dependency('webkit2gtk-4.0', version: '>=2.0.0')
gstreamer_plugins_base_vapi = meson.get_compiler('vala').find_library('gstreamer-base-1.0')
gstreamer_plugins_base_dep = declare_dependency(dependencies: [gstreamer_plugins_base_vapi])
lconv_dep = meson.get_compiler('vala').find_library('LConv', dirs: join_paths(meson.current_source_dir(), 'vapi'))
linux_dep = meson.get_compiler('vala').find_library('linux')

vapi_include = include_directories('./vapi')

dependencies = [
    glib_dep,
    gio_unix_dep,
    gee_dep,
    gexiv2_dep,
    geocode_glib_dep,
    gmodule_dep,
    gstreamer_dep,
    gstreamer_base_dep,
    gstreamer_plugins_base_dep,
    gstreamer_pbutils_dep,
    granite_dep,
    gtk_dep,
    gudev_dep,
    handy,
    json_glib_dep,
    libexif_dep,
    gphoto2_dep,
    libraw_dep,
    libwebp_dep,
    libsoup_dep,
    libxml_dep,
    rest_dep,
    sqlite3_dep,
    webkit2gtk_dep,
    lconv_dep,
    linux_dep,
]

add_project_arguments(['--vapidir', join_paths(meson.current_source_dir(), 'vapi')], language: 'vala')

#FIXME: Move the Resource files when we have the required GLib version
global_gresource = gnome.compile_resources(
    'gresource_global',
    'data/io.elementary.photos.gresource.xml',
    source_dir: 'data'
)

icons_gresource = gnome.compile_resources(
    'gresource_icons',
    'data/icons/icons.gresource.xml',
    source_dir: 'data/icons'
)

transitions_gresource = gnome.compile_resources(
    'gresource_plugin_transitions',
    'plugins/pantheon-photos-transitions/io.elementary.photos.plugins.transitions.gresource.xml',
    source_dir: 'plugins/pantheon-photos-transitions'
)

publishing_gresource = gnome.compile_resources(
    'gresource_plugin_publishing',
    'plugins/pantheon-photos-publishing/io.elementary.photos.plugins.publishing.gresource.xml',
    source_dir: 'plugins/pantheon-photos-publishing'
)

publishing_extras_gresource = gnome.compile_resources(
    'gresource_plugin_publishing_extras',
    'plugins/pantheon-photos-publishing-extras/io.elementary.photos.plugins.publishing-extras.gresource.xml',
    source_dir: 'plugins/pantheon-photos-publishing-extras'
)

subdir('data')
subdir('src')
subdir('thumbnailer')
if get_option('plugins')
    subdir('plugins')
endif
subdir('po')
if get_option('documentation')
    subdir('docs')
endif

meson.add_install_script('meson/post_install.py')
