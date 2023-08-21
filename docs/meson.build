valadoc = find_program('valadoc')

basic_command = [
    valadoc,
    '--force',
    '--verbose',
    '--package-name',meson.project_name(),
    '--package-version', meson.project_version(),
    '--driver', meson.get_compiler('vala').version(),
    '--pkg', 'geocode-glib-1.0',
    '--pkg', 'gexiv2',
    '--pkg', 'gtk+-3.0',
    '--pkg', 'gee-0.8',
    '--pkg', 'gio-unix-2.0',
    '--pkg', 'gmodule-2.0',
    '--pkg', 'config',
    '--pkg', 'linux',
    '--pkg', 'LConv',
    '--pkg', 'granite',
    '--pkg', 'gudev-1.0',
    '--pkg', 'libexif',
    '--pkg', 'libgphoto2',
    '--pkg', 'libhandy-1',
    '--pkg', 'libraw',
    '--pkg', 'libwebp',
    '--pkg', 'sqlite3',
    '--pkg', 'gstreamer-1.0',
    '--pkg', 'gstreamer-base-1.0',
    '--pkg', 'gstreamer-pbutils-1.0',
    '--vapidir=' + join_paths(meson.source_root(), 'vapi'),
    '--importdir=' + join_paths(get_option('prefix'), get_option('datadir'), 'gtk-doc', 'html'),
    '--doclet=html',
    '--use-svg-images'
]

doc_target = custom_target(
    'library documentation',
    command: [
        basic_command,
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: library_files,
    output: 'library'
)

all_doc_target = custom_target(
    'full documentation',
    command: [
        basic_command,
        '--internal',
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: library_files + photos_files,
    output: 'full'
)
