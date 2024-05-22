icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', i + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
        rename: meson.project_name() + '.svg'
    )
    install_data(
        join_paths('icons', i + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps'),
        rename: meson.project_name() + '.svg'
    )

    install_data(
        join_paths('icons', i + '-viewer.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
        rename: meson.project_name() + '-viewer.svg'
    )
    install_data(
        join_paths('icons', i + '-viewer.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps'),
        rename: meson.project_name() + '-viewer.svg'
    )
endforeach

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'glib-2.0', 'schemas')
)

config_data = configuration_data()
config_data.set('EXEC_NAME', meson.project_name())

# Set the executable name and translate the desktop files
viewer_desktop_in_file = configure_file(
    input: meson.project_name() + '-viewer.desktop.in.in',
    output: '@BASENAME@',
    configuration: config_data
)

viewer_desktop_file = i18n.merge_file(
    input: viewer_desktop_in_file,
    output: meson.project_name() + '-viewer.desktop',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    install: true
)

app_desktop_in_file = configure_file(
    input: meson.project_name() + '.desktop.in.in',
    output: '@BASENAME@',
    configuration: config_data
)

app_desktop_file = i18n.merge_file(
    input: app_desktop_in_file,
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    install: true
)

i18n.merge_file(
    input: 'photos.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)
