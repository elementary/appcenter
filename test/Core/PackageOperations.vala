/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

void add_package_operations_tests () {
    Test.add_func ("/package/operations/simple", () => {
        var loop = new MainLoop ();
        test_package_operations_simple.begin (() => {
            loop.quit ();
        });
        loop.run ();
    });
}

public async void test_package_operations_simple () {
    var backend = new MockBackend ();
    var component = new AppStream.Component ();
    var package = new AppCenterCore.Package ("test-package", backend, component);

    try {
        yield test_run_op (package, backend, INSTALLING, NOT_INSTALLED, INSTALLED);

        package.change_information.updatable_packages.add ("test-package");
        package.update_state ();

        yield test_run_op (package, backend, UPDATING, UPDATE_AVAILABLE, INSTALLED);

        yield test_run_op (package, backend, REMOVING, INSTALLED, NOT_INSTALLED);
    } catch (Error e) {
        assert_not_reached ();
    }
}

public async void test_run_op (
    AppCenterCore.Package package,
    MockBackend backend,
    AppCenterCore.Package.State op,
    AppCenterCore.Package.State state_before,
    AppCenterCore.Package.State state_after
) throws Error {
    assert_cmpint (package.state, EQ, state_before);

    Error? error = null;

    AsyncReadyCallback callback = (obj, res) => {
        try {
            switch (op) {
                case INSTALLING:
                    package.install.end (res);
                    break;

                case UPDATING:
                    package.update.end (res);
                    break;

                case REMOVING:
                    package.uninstall.end (res);
                    break;

                default:
                    assert_not_reached ();
            }
        } catch (Error e) {
            error = e;
        }

        Idle.add (() => {
            test_run_op.callback ();
            return Source.REMOVE;
        });
    };

    switch (op) {
        case INSTALLING:
            package.install.begin (callback);
            break;

        case UPDATING:
            package.update.begin (callback);
            break;

        case REMOVING:
            package.uninstall.begin (callback);
            break;

        default:
            assert_not_reached ();
    }

    assert_cmpint (package.state, EQ, op);

    backend.finish_operation ();

    yield;

    if (error != null) {
        assert_cmpint (package.state, EQ, state_before);
        throw error;
    } else {
        assert_cmpint (package.state, EQ, state_after);
    }
}
