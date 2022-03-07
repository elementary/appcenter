/*-
 * Copyright 2019 elementary, Inc. (https://elementary.io)
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
        string? bin_path = Environment.find_program_in_path ("ubuntu-drivers");
        if (bin_path == null) {
            stderr.printf("ubuntu-drivers: not found\n");
            return false;
        }

        Subprocess command;

        try {
            command = new Subprocess (SubprocessFlags.STDOUT_PIPE, bin_path, "list");
            yield command.communicate_utf8_async (null, null, out output, null);
        } catch (Error e) {
            stderr.printf("ubuntu-drivers: %s\n", e.message);
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
        string? command_output = null;
        bool success = yield get_drivers_output (null, out command_output);
        if (!success || command_output == null) {
            working = false;
            return cached_packages;
        }

#if POP_OS
        int latest_nvidia_ver = 0;
        Package? nvidia_package_current = null;
        Package? nvidia_package_latest = null;
        string? nvidia_version_latest = null;
        string? nvidia_version_current = null;
#endif

        string[] tokens = command_output.split ("\n");
        for (int i = 0; i < tokens.length; i++) {
            unowned string package_name = tokens[i];
            if (package_name.strip () == "") {
                continue;
            }

            // ubuntu-drivers returns lines like the following for dkms packages:
            // backport-iwlwifi-dkms, (kernel modules provided by backport-iwlwifi-dkms)
            // we only want the bit before the comma
            string[] parts = package_name.split (",");
            package_name = parts[0];
#if POP_OS
            if (package_name.has_prefix ("backport-") && package_name.has_suffix ("-dkms")) {
                continue;
            }

            if (package_name.has_suffix ("-server")) {
                continue;
            }

            unowned string? nvidia_version = null;

            if (package_name.has_prefix ("nvidia-driver-")) {
                nvidia_version = package_name.offset (14);
            } else if (package_name.has_prefix ("nvidia-")) {
                nvidia_version = package_name.offset (7);
            }

            Package package = yield driver_package (package_name);

            if (null != nvidia_version) {
                if (nvidia_version.contains ("-")) continue;

                int parsed = int.parse (nvidia_version);

                if (package.installed) {
                    nvidia_version_current = package_name;
                    nvidia_package_current = package;
                }

                if (latest_nvidia_ver < parsed) {
                    nvidia_version_latest = package_name;
                    latest_nvidia_ver = parsed;
                }

                continue;
            }
#else
            Package package = yield driver_package (package_name);
#endif
            cached_packages.add (package);
        }

        if (null != nvidia_version_latest && null != nvidia_version_current) {
            cached_packages.add (nvidia_package_current);
            if (strcmp (nvidia_version_latest, nvidia_version_current) != 0) {
                cached_packages.add (nvidia_package_latest);
            }
        }

        working = false;
        return cached_packages;
    }

    private async Package driver_package (string package_name) {
        var driver_component = new AppStream.Component ();
        driver_component.set_kind (AppStream.ComponentKind.DRIVER);
        driver_component.set_pkgnames ({ package_name });
        driver_component.set_id (package_name);

        var icon = new AppStream.Icon ();
        icon.set_name ("application-x-firmware");
        icon.set_kind (AppStream.IconKind.STOCK);
        driver_component.add_icon (icon);

        var package = new Package (this, driver_component);

        try {
            if (yield is_package_installed (package)) {
                package.mark_installed ();
            }
        } catch (Error e) {
            warning ("Unable to check if driver is installed: %s", e.message);
        }

        return package;
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
        return true;
    }

    public async bool install_package (Package package, owned ChangeInformation.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        return yield PackageKitBackend.get_default ().install_package (package, (owned)cb, cancellable);
    }

    public async bool remove_package (Package package, owned ChangeInformation.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        return yield PackageKitBackend.get_default ().remove_package (package, (owned)cb, cancellable);
    }

    public async bool update_package (Package package, owned ChangeInformation.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        return yield PackageKitBackend.get_default ().update_package (package, (owned)cb, cancellable);
    }

    private static GLib.Once<UbuntuDriversBackend> instance;
    public static unowned UbuntuDriversBackend get_default () {
        return instance.once (() => { return new UbuntuDriversBackend (); });
    }
}
