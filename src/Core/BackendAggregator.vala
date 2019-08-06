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

public class AppCenterCore.BackendAggregator : Backend, Object {
    private Gee.ArrayList<unowned Backend> backends;

    construct {
        backends = new Gee.ArrayList<unowned Backend> ();
        backends.add (PackageKitBackend.get_default ());
        backends.add (UbuntuDriversBackend.get_default ());
        backends.add (FlatpakBackend.get_default ());

        foreach (var backend in backends) {
            backend.notify["working"].connect (() => {
                notify_property ("working");
            });
        }
    }

    public bool working {
        get {
            foreach (var backend in backends) {
                if (backend.working) {
                    return true;
                }
            }

            return false;
        }

        set { }
    }

    public async Gee.Collection<Package> get_installed_applications (Cancellable? cancellable = null) {
        var apps = new Gee.TreeSet<Package> ();
        foreach (var backend in backends) {
            if (cancellable.is_cancelled ()) {
                break;
            }

            apps.add_all (yield backend.get_installed_applications (cancellable));
        }

        return apps;
    }

    public Gee.Collection<Package> get_applications_for_category (AppStream.Category category) {
        var apps = new Gee.TreeSet<Package> ((a, b) => {
            return a.normalized_component_id.collate (b.normalized_component_id);
        });

        foreach (var backend in backends) {
            apps.add_all (backend.get_applications_for_category (category));
        }

        return apps;
    }

    public Gee.Collection<Package> search_applications (string query, AppStream.Category? category) {
        var apps = new Gee.TreeSet<Package> ((a, b) => {
            return a.normalized_component_id.collate (b.normalized_component_id);
        });

        foreach (var backend in backends) {
            apps.add_all (backend.search_applications (query, category));
        }

        return apps;
    }

    public Gee.Collection<Package> search_applications_mime (string query) {
        var apps = new Gee.TreeSet<Package> ();
        foreach (var backend in backends) {
            apps.add_all (backend.search_applications_mime (query));
        }

        return apps;
    }

    public Package? get_package_for_component_id (string id) {
        Package? package;
        foreach (var backend in backends) {
            package = backend.get_package_for_component_id (id);
            if (package != null) {
                return package;
            }
        }

        return null;
    }

    public Gee.Collection<Package> get_packages_for_component_id (string id) {
        string package_id = id;
        if (package_id.has_suffix (".desktop")) {
            package_id = package_id.substring (0, package_id.length + package_id.index_of_nth_char (-8));
        }

        var packages = new Gee.ArrayList<Package> ();
        foreach (var backend in backends) {
            packages.add_all (backend.get_packages_for_component_id (package_id));
        }

        return packages;
    }

    public Package? get_package_for_desktop_id (string desktop_id) {
        Package? package;
        foreach (var backend in backends) {
            package = backend.get_package_for_desktop_id (desktop_id);
            if (package != null) {
                return package;
            }
        }

        return null;
    }

    public Gee.Collection<Package> get_packages_by_author (string author, int max) {
        var packages = new Gee.TreeSet<Package> ();
        foreach (var backend in backends) {
            packages.add_all (backend.get_packages_by_author (author, max));
            if (packages.size >= max) {
                break;
            }
        }

        return packages;
    }

    public async uint64 get_download_size (Package package, Cancellable? cancellable) throws GLib.Error {
        return package.change_information.size;
    }

    public async bool is_package_installed (Package package) throws GLib.Error {
        assert_not_reached ();
    }

    public async PackageDetails get_package_details (Package package) throws GLib.Error {
        assert_not_reached ();
    }

    public async bool refresh_cache (Cancellable? cancellable) throws GLib.Error {
        var success = true;
        foreach (var backend in backends) {
            if (!yield backend.refresh_cache (cancellable)) {
                success = false;
            }
        }

        return success;
    }

    public async bool install_package (Package package, owned ChangeInformation.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        assert_not_reached ();
    }

    public async bool update_package (Package package, owned ChangeInformation.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var success = true;
        foreach (var backend in backends) {
            if (!yield backend.update_package (package, cb, cancellable)) {
                success = false;
            }
        }

        return success;
    }

    public async bool remove_package (Package package, owned ChangeInformation.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        assert_not_reached ();
    }

    private static GLib.Once<BackendAggregator> instance;
    public static unowned BackendAggregator get_default () {
        return instance.once (() => { return new BackendAggregator (); });
    }
}
