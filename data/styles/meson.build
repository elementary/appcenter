sassc = find_program('sassc')

sassc_opts = [ '-a', '-M', '-t', 'compact' ]

stylesheet_deps = custom_target(
    'Application.scss',
    input: 'Index.scss',
    output: 'Application.css',
    command: [
        sassc,
        sassc_opts,
        '@INPUT@',
        '@OUTPUT@',
    ]
)

css_gresource = gnome.compile_resources(
    'css-gresource',
    'styles.gresource.xml',
    source_dir: [
        meson.current_build_dir(),
        meson.current_source_dir(),
    ],
    dependencies: stylesheet_deps
)
