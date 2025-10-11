/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface AppCenterCore.Backend : Object {
    public signal void operation_finished (Package package, Package.State operation, Error? error);

    public abstract void notify_package_changed (Package package);

    public abstract bool is_package_installed (Package package) throws GLib.Error;

    public abstract async bool install_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error;
    public abstract async bool remove_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error;
    public abstract async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error;
}
