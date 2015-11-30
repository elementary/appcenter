/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

public class AppCenterCore.Client : Object {
    public signal void updates_available ();
    public signal void tasks_finished ();

    public bool connected { public get; private set; }
    public AppCenterCore.Package os_updates { public get; private set; }

    private Gee.LinkedList<Pk.Task> task_list;
    private Gee.HashMap<string, AppCenterCore.Package> package_list;
    private AppStream.Database appstream_database;
    private UpdateSignals update_daemon;

    private Client () {
        task_list = new Gee.LinkedList<Pk.Task> ();
        package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);

        var datapool = new AppStream.DataPool ();
        datapool.update ();
        appstream_database = new AppStream.Database ();
        appstream_database.open ();

        var os_updates_component = new AppStream.Component ();
        os_updates_component.id = AppCenterCore.Package.OS_UPDATES_ID;
        os_updates_component.name = _("Operating System Updates");
        os_updates_component.summary = _("Updates to system components");
        os_updates_component.add_icon (AppStream.IconKind.STOCK, 48, 48, "distributor-logo");
        os_updates = new AppCenterCore.Package (os_updates_component);

        try {
            update_daemon = Bus.get_proxy_sync (BusType.SESSION, "org.pantheon.AppCenter", "/org/pantheon/appcenter");
        } catch (Error e) {
            critical (e.message);
        }

        appstream_database.get_all_components ().foreach ((comp) => {
            var package = new AppCenterCore.Package (comp);
            foreach (var pkg_name in comp.get_pkgnames ()) {
                package_list.set (pkg_name, package);
            }
        });
    }

    public bool has_tasks () {
        return !task_list.is_empty;
    }

    private Pk.Task request_task () {
        Pk.Task task = new Pk.Task ();
        task_list.add (task);
        return task;
    }

    private void release_task (Pk.Task task) {
        task_list.remove (task);
        if (task_list.is_empty) {
            tasks_finished ();
        }
    }

    public async void install_packages (Gee.TreeSet<Package> packages, Pk.ProgressCallback cb) throws GLib.Error {
        Pk.Task install_task = request_task ();
        Pk.Task search_task = request_task ();
        string[] packages_ids = {};
        foreach (var package in packages) {
            foreach (var pkg_name in package.component.get_pkgnames ()) {
                packages_ids += pkg_name;
            }
        }
        packages_ids += null;

        try {
            var results = yield search_task.search_names_async (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.ARCH), packages_ids, null, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });
            packages_ids += null;

            yield install_task.install_packages_async (packages_ids, null, cb);
        } catch (Error e) {
            release_task (search_task);
            release_task (install_task);
            throw e;
        }

        release_task (search_task);
        release_task (install_task);
    }

    public async void update_packages (Gee.TreeSet<Package> packages, Pk.ProgressCallback cb) throws GLib.Error {
        Pk.Task update_task = request_task ();
        string[] packages_ids = {};
        foreach (var package in packages) {
            foreach (var pk_package in package.update_packages) {
                packages_ids += pk_package.get_id ();
            }
        }
        packages_ids += null;

        try {
            yield update_task.update_packages_async (packages_ids, null, cb);
        } catch (Error e) {
            release_task (update_task);
            throw e;
        }

        foreach (var package in packages) {
            package.installed_packages.add_all (package.update_packages);
            package.update_packages.clear ();
            package.update_size = 0ULL;
            package.notify_property ("update-available");
        }

        try {
            update_daemon.refresh_updates ();
        } catch (Error e) {
            critical (e.message);
        }

        release_task (update_task);
    }

    public async void remove_packages (Gee.TreeSet<Package> packages, Pk.ProgressCallback cb) throws GLib.Error {
        Pk.Task remove_task = request_task ();
        Pk.Task search_task = request_task ();
        string[] packages_ids = {};
        foreach (var package in packages) {
            foreach (var pkg_name in package.component.get_pkgnames ()) {
                packages_ids += pkg_name;
            }
        }
        packages_ids += null;

        try {
            var filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
            var results = yield search_task.search_names_async (filter, packages_ids, null, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });

            yield remove_task.remove_packages_async (packages_ids, true, true, null, cb);
        } catch (Error e) {
            release_task (search_task);
            release_task (remove_task);
            throw e;
        }

        try {
            update_daemon.refresh_updates ();
        } catch (Error e) {
            critical (e.message);
        }

        release_task (search_task);
        release_task (remove_task);
    }

    public async void get_updates () {
        Pk.Task update_task = request_task ();
        Pk.Task details_task = request_task ();
        try {
            Pk.Results result = yield update_task.get_updates_async (0, null, (t, p) => { });
            var packages = new Gee.HashMap<string, Pk.Package> (null, null);
            result.get_package_array ().foreach ((pk_package) => {
                packages.set (pk_package.get_id (), pk_package);
            });

            // We need a null to show to PackageKit that it's then end of the array.
            string[] packages_array = packages.keys.to_array ();
            packages_array += null;

            Pk.Results result2 = yield details_task.get_details_async (packages_array , null, (t, p) => { });
            result2.get_details_array ().foreach ((pk_detail) => {
                var pk_package = packages.get (pk_detail.get_package_id ());
                var package = package_list.get (pk_package.get_name ());
                if (package == null) {
                    package = os_updates;
                    var pkgnames = os_updates.component.pkgnames;
                    pkgnames += pk_package.get_name ();
                    os_updates.component.pkgnames = pkgnames;
                }

                package.update_packages.add (pk_package);
                package.update_size += pk_detail.size;
                package.notify_property ("update-available");
            });
        } catch (Error e) {
            critical (e.message);
        }

        release_task (details_task);
        release_task (update_task);
        updates_available ();
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications () {
        Pk.Task packages_task = request_task ();
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();

        try {
            var filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
            Pk.Results result = yield packages_task.get_packages_async (filter, null, (prog, type) => {});
            result.get_package_array ().foreach ((pk_package) => {
                var package = package_list.get (pk_package.get_name ());
                if (package != null) {
                    package.installed_packages.add (pk_package);
                    package.notify_property ("installed");
                    packages.add (package);
                }
            });
        } catch (Error e) {
            critical (e.message);
        }

        release_task (packages_task);
        return packages;
    }

    public Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        var query = new AppStream.SearchQuery ("*");
        query.set_categories_from_string (category.name);
        var comps = appstream_database.find_components (query);
        comps.foreach ((comp) => {
            apps.add (package_list.get (comp.get_pkgnames ()[0]));
        });

        return apps;
    }

    public Pk.Package? get_app_package (string application, Pk.Bitfield additional_filters = 0, GLib.Cancellable? cancellable = null) throws GLib.Error {
        Pk.Task packages_task = request_task ();
        Pk.Package? package = null;
        var filter = Pk.Bitfield.from_enums (Pk.Filter.NEWEST);
        filter |= additional_filters;
        try {
            var results = packages_task.search_names_sync (filter, { application, null }, cancellable, () => {});
            package = results.get_package_array ().get (0);
        } catch (Error e) {
            release_task (packages_task);
            throw e;
        }

        release_task (packages_task);
        return package;
    }

    private static GLib.Once<Client> instance;
    public static unowned Client get_default () {
        return instance.once (() => { return new Client (); });
    }
}

[DBus (name = "org.pantheon.AppCenter")]
interface AppCenterCore.UpdateSignals : Object {
    public abstract void refresh_cache () throws IOError;
    public abstract void refresh_updates () throws IOError;
}
