core_tests = executable(
    meson.project_name() + '-core-tests',
    'Core/CardUtils.vala',
    'Core/Houston.vala',
    'Core/SoupClient.vala',
    'Core/Stripe.vala',
    'CoreTest.vala',
    'MockHttpClient.vala',
    meson.project_source_root() + '/src/Core/CardUtils.vala',
    meson.project_source_root() + '/src/Core/Houston.vala',
    meson.project_source_root() + '/src/Core/HttpClient.vala',
    meson.project_source_root() + '/src/Core/SoupClient.vala',
    meson.project_source_root() + '/src/Core/Stripe.vala',
    dependencies: core_deps
)

test('AppCenter core tests', core_tests)