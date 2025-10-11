core_tests = executable(
    meson.project_name() + '-core-tests',
    'Core/CardUtils.vala',
    'Core/Houston.vala',
    'Core/PackageOperations.vala',
    'Core/Stripe.vala',
    'CoreTest.vala',
    'MockBackend.vala',
    'MockHttpClient.vala',
    meson.project_source_root() + '/src/Core/AddonFilter.vala',
    meson.project_source_root() + '/src/Core/Backend.vala',
    meson.project_source_root() + '/src/Core/CardUtils.vala',
    meson.project_source_root() + '/src/Core/ChangeInformation.vala',
    meson.project_source_root() + '/src/Core/FlatpakBackend.vala',
    meson.project_source_root() + '/src/Core/Houston.vala',
    meson.project_source_root() + '/src/Core/HttpClient.vala',
    meson.project_source_root() + '/src/Core/Job.vala',
    meson.project_source_root() + '/src/Core/Package.vala',
    meson.project_source_root() + '/src/Core/SearchEngine.vala',
    meson.project_source_root() + '/src/Core/Stripe.vala',
    meson.project_source_root() + '/src/Utils.vala',
    config_file,
    dependencies: core_deps
)

integration_tests = executable(
    meson.project_name() + '-integration-tests',
    'Integration/SoupClient.vala',
    'Integration.vala',
    meson.project_source_root() + '/src/Core/HttpClient.vala',
    meson.project_source_root() + '/src/Core/SoupClient.vala',
    dependencies: core_deps
)

test('AppCenter core tests', core_tests)
if get_option('integration_tests')
    test('AppCenter integration tests', integration_tests)
endif
