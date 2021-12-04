/*-
 * Copyright 2019-2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class AppCenterCore.UbuntuDriversBackend : Backend, Object {

    public bool working { public get; protected set; }

    private Gee.TreeSet<Package>? cached_packages = null;

    private async bool get_drivers_output (Cancellable? cancellable = null, out string? output = null) {
        output = null;
        string? drivers_exec_path = Environment.find_program_in_path ("ubuntu-drivers");
        if (drivers_exec_path == null) {
            return false;
        }

        Subprocess command;
        try {
            command = new Subprocess (SubprocessFlags.STDOUT_PIPE, drivers_exec_path, "list");
            yield command.communicate_utf8_async (null, cancellable, out output, null);
        } catch (Error e) {
            return false;
        }

        return command.get_exit_status () == 0;
    }

    public async Gee.Collection<Package> get_installed_applications (Cancellable? cancellable = null) {
        if (cached_packages != null) {
            return cached_packages;
        }

        working = true;

        cached_packages = new Gee.TreeSet<Package> ();
        var tokens = AppCenter.App.settings.get_strv ("cached-drivers");

        for (int i = 0; i < tokens.length; i++) {
            if (cancellable.is_cancelled ()) {
                break;
            }

            unowned string package_name = tokens[i];
            if (package_name.strip () == "") {
                continue;
            }

            // Filter out the nvidia server drivers
            if (package_name.contains ("nvidia") && package_name.contains ("-server")) {
                continue;
            }

            string[] pkgnames = {};

            // ubuntu-drivers returns lines like the following for dkms packages:
            // backport-iwlwifi-dkms, (kernel modules provided by backport-iwlwifi-dkms)
            // nvidia-driver-470, (kernel modules provided by linux-modules-nvidia-470-generic-hwe-20.04)
            // we want to install both packages if they're different

            string[] parts = package_name.split (",");
            // Get the driver part (before the comma)
            pkgnames += parts[0];

            if (parts.length > 1) {
                if (parts[1].contains ("kernel modules provided by")) {
                    string[] kernel_module_parts = parts[1].split (" ");
                    // Get the remainder of the string after the last space
                    var last_part = kernel_module_parts[kernel_module_parts.length - 1];
                    // Strip off the trailing bracket
                    last_part = last_part.replace (")", "");

                    if (!(last_part in pkgnames)) {
                        pkgnames += last_part;
                    }
                } else {
                    warning ("Unrecognised line from ubuntu-drivers, needs checking: %s", package_name);
                }
            }

            var driver_component = new AppStream.Component ();
            driver_component.set_kind (AppStream.ComponentKind.DRIVER);
            driver_component.set_pkgnames (pkgnames);
            driver_component.set_id (package_name);

            var icon = new AppStream.Icon ();
            icon.set_name ("application-x-firmware");
            icon.set_kind (AppStream.IconKind.STOCK);
            driver_component.add_icon (icon);

            var package = new Package (this, driver_component);
            try {
                if (yield is_package_installed (package)) {
                    package.mark_installed ();
                    package.update_state ();
                }
            } catch (Error e) {
                warning ("Unable to check if driver is installed: %s", e.message);
            }

            yield add_kernel_headers_if_necessary (package, cancellable);

            cached_packages.add (package);
        }

        working = false;
        return cached_packages;
    }

    private static async void add_kernel_headers_if_necessary (Package package, Cancellable? cancellable) {
        Gee.ArrayList<string>? depends = null;

        try {
            depends = yield PackageKitBackend.get_default ().get_package_dependencies (package, cancellable);
        } catch (Error e) {
            warning ("Unable to get dependencies of driver package, kernel headers may not be installed");
            return;
        }

        if (depends != null && "dkms" in depends) {
            // Ensure we have matching kernel headers installed for our installed `linux-image-generic` metapackages.
            // Sometimes Ubuntu drivers depend on non-HWE headers and the module doesn't get built for the running kernel
            var installed = yield PackageKitBackend.get_default ().get_installed_packages (cancellable);
            foreach (var pkg in installed) {
                unowned string pkgname = pkg.get_name ();
                if (pkgname.has_prefix ("linux-image-generic")) {
                    var pkgnames = package.component.get_pkgnames ();
                    pkgnames += pkgname.replace ("linux-image", "linux-headers");
                    package.component.set_pkgnames (pkgnames);
                }
            }
        }
    }

    public Gee.Collection<Package> get_applications_for_category (AppStream.Category category) {
        return new Gee.ArrayList<Package> ();
    }

    public Gee.Collection<Package> search_applications (string query, AppStream.Category? category) {
        return new Gee.ArrayList<Package> ();
    }

    public Gee.Collection<Package> search_applications_mime (string query) {
        return new Gee.ArrayList<Package> ();
    }

    public Package? get_package_for_component_id (string id) {
        return null;
    }

    public Gee.Collection<Package> get_packages_for_component_id (string id) {
        return new Gee.ArrayList<Package> ();
    }

    public Package? get_package_for_desktop_id (string id) {
        return null;
    }

    public Gee.Collection<Package> get_packages_by_author (string author, int max) {
        return new Gee.ArrayList<Package> ();
    }

    public async uint64 get_download_size (Package package, Cancellable? cancellable, bool is_update = false) throws GLib.Error {
        return yield PackageKitBackend.get_default ().get_download_size (package, cancellable, is_update);
    }

    public async bool is_package_installed (Package package) throws GLib.Error {
        return yield PackageKitBackend.get_default ().is_package_installed (package);
    }

    public async PackageDetails get_package_details (Package package) throws GLib.Error {
        return yield PackageKitBackend.get_default ().get_package_details (package);
    }

    public async bool refresh_cache (Cancellable? cancellable) throws GLib.Error {
        working = true;
        string? command_output;
        var result = yield get_drivers_output (cancellable, out command_output);
        if (!result || command_output == null || cancellable.is_cancelled ()) {
            working = false;
            return false;
        }

        string[] tokens = command_output.split ("\n");
        string[] pkgnames = {};
        foreach (unowned string token in tokens) {
            if (token.strip () != "") {
                pkgnames += token;
            }
        }

        AppCenter.App.settings.set_strv ("cached-drivers", pkgnames);

        working = false;
        return true;
    }

    public async bool install_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        cached_packages = null;
        return yield PackageKitBackend.get_default ().install_package (package, change_info, cancellable);
    }

    public async bool remove_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        cached_packages = null;
        return yield PackageKitBackend.get_default ().remove_package (package, change_info, cancellable);
    }

    public async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        return yield PackageKitBackend.get_default ().update_package (package, change_info, cancellable);
    }

    private static GLib.Once<UbuntuDriversBackend> instance;
    public static unowned UbuntuDriversBackend get_default () {
        return instance.once (() => { return new UbuntuDriversBackend (); });
    }
}
