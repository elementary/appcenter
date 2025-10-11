/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class MockBackend : Object, AppCenterCore.Backend {
    public signal void finish_operation ();

    public int package_changed_notified { get; private set; default = 0; }

    public Error? next_operation_error { get; set; default = null; }

    public Gee.List<AppCenterCore.Package> installed_packages { get; construct; }

    construct {
        installed_packages = new Gee.ArrayList<AppCenterCore.Package> ();
    }

    public void notify_package_changed (AppCenterCore.Package package) {
        package_changed_notified++;
    }

    public bool is_package_installed (AppCenterCore.Package package) throws GLib.Error {
        return package in installed_packages;
    }

    public async bool install_package (AppCenterCore.Package package, AppCenterCore.ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        if (yield run_operation ()) {
            installed_packages.add (package);
            return true;
        }
        return false;
    }

    public async bool remove_package (AppCenterCore.Package package, AppCenterCore.ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        if (yield run_operation ()) {
            installed_packages.remove (package);
            return true;
        }
        return false;
    }

    public async bool update_package (AppCenterCore.Package package, AppCenterCore.ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        return yield run_operation ();
    }

    private async bool run_operation () throws GLib.Error {
        ulong handler = 0;
        handler = finish_operation.connect (() => {
            disconnect (handler);

            Idle.add (() => {
                run_operation.callback ();
                return Source.REMOVE;
            });
        });

        yield;

        if (next_operation_error != null) {
            var error = next_operation_error;
            next_operation_error = null;
            throw error;
        }
        return true;
    }
}
