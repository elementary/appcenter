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
    public signal void cache_flush_needed ();

    private Gee.ArrayList<unowned Backend> backends;
    private uint remove_inhibit_timeout = 0;
    private uint inhibit_token = 0;

    construct {
        backends = new Gee.ArrayList<unowned Backend> ();
        backends.add (PackageKitBackend.get_default ());
        backends.add (UbuntuDriversBackend.get_default ());
        backends.add (FlatpakBackend.get_default ());

        unowned Gtk.Application app = (Gtk.Application) GLib.Application.get_default ();
        foreach (var backend in backends) {
            backend.notify["working"].connect (() => {
                if (working) {
                    if (remove_inhibit_timeout != 0) {
                        Source.remove (remove_inhibit_timeout);
                        remove_inhibit_timeout = 0;
                    }

                    if (inhibit_token == 0) {
                        inhibit_token = app.inhibit (
                            app.get_active_window (),
                            Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND,
                            _("package operations are being performed")
                        );
                    }
                } else {
                    // Wait for 5 seconds of inactivity before uninhibiting as we may be
                    // rapidly switching between working states on different backends etc...
                    if (remove_inhibit_timeout == 0) {
                        remove_inhibit_timeout = Timeout.add_seconds (5, () => {
                            if (inhibit_token != 0) {
                                app.uninhibit (inhibit_token);
                                inhibit_token = 0;
                            }

                            remove_inhibit_timeout = 0;

                            return false;
                        });
                    }
                }

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

            var installed = yield backend.get_installed_applications (cancellable);
            if (installed != null) {
                apps.add_all (installed);
            }
        }

        return apps;
    }

    public Gee.Collection<Package> get_applications_for_category (AppStream.Category category) {
        var apps = new Gee.HashMap<string, Package> ();
        foreach (var backend in backends) {
            var results = backend.get_applications_for_category (category);

            foreach (var result in results) {
                var result_component_id = result.normalized_component_id;
                if (apps.has_key (result_component_id)) {
                    if (result.origin_score > apps[result_component_id].origin_score) {
                        apps[result_component_id] = result;
                    }
                } else {
                    apps[result_component_id] = result;
                }
            }
        }

        return apps.values;
    }

    public Gee.Collection<Package> search_applications (string query, AppStream.Category? category) {
        var apps = new Gee.HashMap<string, Package> ();
        foreach (var backend in backends) {
            var results = backend.search_applications (query, category);

            foreach (var result in results) {
                var result_component_id = result.normalized_component_id;
                if (apps.has_key (result_component_id)) {
                    if (result.origin_score > apps[result_component_id].origin_score) {
                        apps[result_component_id] = result;
                    }
                } else {
                    apps[result_component_id] = result;
                }
            }
        }

        return apps.values;
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
            // ".desktop" is always 8 bytes in UTF-8 so we can just chop 8 bytes off the end
            package_id = package_id.substring (0, package_id.length - 8);
        }

        var packages = new Gee.ArrayList<Package> ();
        foreach (var backend in backends) {
            packages.add_all (backend.get_packages_for_component_id (package_id));
        }

        packages.sort ((a, b) => {
            return b.origin_score - a.origin_score;
        });

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

    public async uint64 get_download_size (Package package, Cancellable? cancellable, bool is_update = false) throws GLib.Error {
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

    public async bool install_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        assert_not_reached ();
    }

    public async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        var success = true;
        // updatable_packages is a HashMultiMap of packages to be updated, where the key is
        // a pointer to the backend that is capable of updating them. Most packages only have one
        // backend, but there is the special case of the OS updates package which could contain
        // flatpaks and/or packagekit packages

        var backends = package.change_information.updatable_packages.get_keys ();
        Gee.ArrayList<ChangeInformation>? change_infos = null;
        if (change_info != null) {
            change_infos = new Gee.ArrayList<ChangeInformation> ();
        }

        foreach (var backend in backends) {
            ChangeInformation? sub_change_info = null;
            if (change_info != null) {
                // Intercept progress callbacks so we can divide the progress between the number of backends
                sub_change_info = new ChangeInformation ();
                change_infos.add (sub_change_info);
                sub_change_info.status_changed.connect (() => {
                    report_change_info (change_info, change_infos);
                });
                sub_change_info.progress_changed.connect (() => {
                    report_change_info (change_info, change_infos);
                });
            }
            var backend_succeeded = yield backend.update_package (
                package,
                sub_change_info,
                cancellable
            );

            if (!backend_succeeded) {
                success = false;
            }
        }

        return success;
    }

    public async bool remove_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        assert_not_reached ();
    }

    private static void report_change_info (ChangeInformation real_change_info, Gee.ArrayList<ChangeInformation> change_infos) {
        double calculated_progress = 0.0f;
        var consolidated_status = ChangeInformation.Status.FINISHED;
        bool can_cancel = true;
        foreach (var change_info in change_infos) {
            if (change_info.status != ChangeInformation.Status.FINISHED) {
                consolidated_status = ChangeInformation.Status.RUNNING;
            }

            if (change_info.can_cancel == false) {
                can_cancel = false;
            }

            calculated_progress += change_info.progress / change_infos.size;
        }

        real_change_info.callback (can_cancel, _("Waiting"), calculated_progress, consolidated_status);
    }

    private static GLib.Once<BackendAggregator> instance;
    public static unowned BackendAggregator get_default () {
        return instance.once (() => { return new BackendAggregator (); });
    }
}
