core_tests = executable(
    meson.project_name() + '-core-tests',
    'Core/CardUtils.vala',
    'CoreTest.vala',
    meson.project_source_root() + '/src/Core/CardUtils.vala',
    dependencies: core_deps
)

test('AppCenter core tests', core_tests)