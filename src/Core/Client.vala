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
    public bool connected_to_daemon { public get; private set; default=false; }
    public AppCenterCore.Package os_updates { public get; private set; }

    private Gee.LinkedList<AppCenter.Task> task_list;
    private Gee.LinkedList<AppCenter.Task> task_with_agreement_list;
    private Gee.HashMap<string, AppCenterCore.Package> package_list;
    private AppStream.Database appstream_database;
    private UpdateSignals update_daemon;
    public GLib.Cancellable interface_cancellable;

    private Client () {
        Bus.get_proxy.begin<UpdateSignals> (BusType.SESSION, "org.pantheon.AppCenter", "/org/pantheon/appcenter", GLib.DBusProxyFlags.NONE, interface_cancellable, (obj, res) => {
            try {
                update_daemon = Bus.get_proxy.end (res);
                connected_to_daemon = true;
            } catch (Error e) {
                // Error code 19 is for operation canceled.
                if (e.code != 19) {
                    critical (e.message);
                }
            }
        });

        try {
            appstream_database.get_all_components ().foreach ((comp) => {
                var package = new AppCenterCore.Package (comp);
                foreach (var pkg_name in comp.get_pkgnames ()) {
                    package_list.set (pkg_name, package);
                }
            });
        } catch (Error e) {
            error (e.message);
        }
    }

    construct {
        task_list = new Gee.LinkedList<AppCenter.Task> ();
        task_with_agreement_list = new Gee.LinkedList<AppCenter.Task> ();
        package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);
        interface_cancellable = new GLib.Cancellable ();

        appstream_database = new AppStream.Database ();
        try {
            appstream_database.open ();
        } catch (Error e) {
            error (e.message);
        }

        var os_updates_component = new AppStream.Component ();
        os_updates_component.id = AppCenterCore.Package.OS_UPDATES_ID;
        os_updates_component.name = _("Operating System Updates");
        os_updates_component.summary = _("Updates to system components");
        var icon = new AppStream.Icon ();
        icon.set_name ("distributor-logo");
        icon.set_kind (AppStream.IconKind.STOCK);
        os_updates_component.add_icon (icon);
        os_updates = new AppCenterCore.Package (os_updates_component);
    }

    public bool has_tasks () {
        return !task_list.is_empty;
    }

    private AppCenter.Task request_task (bool requires_user_agreement = true) {
        AppCenter.Task task = new AppCenter.Task ();
        task_list.add (task);
        if (requires_user_agreement) {
            if (task_with_agreement_list.size == 0) {
                Pk.polkit_agent_open ();
            }
            task_with_agreement_list.add (task);
        }
        return task;
    }

    private void release_task (AppCenter.Task task) {
        task_list.remove (task);
        if (task_list.is_empty) {
            tasks_finished ();
            if (task in task_with_agreement_list) {
                task_with_agreement_list.remove (task);
                if (task_with_agreement_list.size == 0) {
                    Pk.polkit_agent_close ();
                }
            }
        }
    }

    public async void install_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        AppCenter.Task install_task = request_task ();
        AppCenter.Task search_task = request_task ();
        string[] packages_ids = {};
        foreach (var pkg_name in package.component.get_pkgnames ()) {
            packages_ids += pkg_name;
        }
        packages_ids += null;

        try {
            var results = yield search_task.search_names_async (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.ARCH), packages_ids, cancellable, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });
            packages_ids += null;

            results = yield install_task.install_packages_async (packages_ids, null, cb);
            if (results.get_exit_code () != Pk.Exit.SUCCESS) {
                release_task (search_task);
                release_task (install_task);
                throw new GLib.IOError.FAILED (Pk.Exit.enum_to_string (results.get_exit_code ()));
            }
        } catch (Error e) {
            release_task (search_task);
            release_task (install_task);
            throw e;
        }

        release_task (search_task);
        release_task (install_task);
    }

    public async void update_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        SuspendControl sc = new SuspendControl ();
        AppCenter.Task update_task = request_task ();
        string[] packages_ids = {};
        foreach (var pk_package in package.change_information.changes) {
            packages_ids += pk_package.get_id ();
        }
        packages_ids += null;

        try {
            sc.inhibit ();
            var results = yield update_task.update_packages_async (packages_ids, cancellable, cb);
            if (results.get_exit_code () != Pk.Exit.SUCCESS) {
                release_task (update_task);
                throw new GLib.IOError.FAILED (Pk.Exit.enum_to_string (results.get_exit_code ()));
            }
        } catch (Error e) {
            release_task (update_task);
            throw e;
        } finally {
            sc.uninhibit ();
        }

        try {
            update_daemon.refresh_updates ();
        } catch (Error e) {
            critical (e.message);
        }

        release_task (update_task);
    }

    public async void remove_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        AppCenter.Task remove_task = request_task ();
        AppCenter.Task search_task = request_task ();
        string[] packages_ids = {};
        foreach (var pkg_name in package.component.get_pkgnames ()) {
            packages_ids += pkg_name;
        }
        packages_ids += null;

        try {
            var filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
            var results = yield search_task.search_names_async (filter, packages_ids, cancellable, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });

            yield remove_task.remove_packages_async (packages_ids, true, true, cancellable, cb);
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
        AppCenter.Task update_task = request_task (false);
        AppCenter.Task details_task = request_task (false);
        try {
            Pk.Results result = yield update_task.get_updates_async (0, interface_cancellable, (t, p) => { });
            string[] packages_array = {};
            result.get_package_array ().foreach ((pk_package) => {
                packages_array += pk_package.get_id ();
            });

            // We need a null to show to PackageKit that it's then end of the array.
            packages_array += null;

            Pk.Results result2 = yield details_task.get_details_async (packages_array , interface_cancellable, (t, p) => { });
            result2.get_details_array ().foreach ((pk_detail) => {
                var pk_package = new Pk.Package ();
                try {
                    pk_package.set_id (pk_detail.get_package_id ());
                    unowned string pkg_name = pk_package.get_name ();
                    var package = package_list.get (pkg_name);
                    if (package == null) {
                        package = os_updates;
                        var pkgnames = os_updates.component.pkgnames;
                        pkgnames += pkg_name;
                        os_updates.component.pkgnames = pkgnames;
                    }

                    package.change_information.changes.add (pk_package);
                    package.change_information.details.add (pk_detail);
                    package.notify_property ("update-available");
                } catch (Error e) {
                    critical (e.message);
                }
            });
        } catch (Error e) {
            // Error code 19 is for operation canceled.
            if (e.code != 19) {
                critical (e.message);
            }
        }

        release_task (details_task);
        release_task (update_task);
        updates_available ();
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications () {
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();
        try {
            var packages_strv = update_daemon.get_installed_packages ();
            foreach (var pkg_id in packages_strv) {
                var pk_package = new Pk.Package ();
                pk_package.set_id (pkg_id);
                var package = package_list.get (pk_package.get_name ());
                if (package != null) {
                    package.installed_packages.add (pk_package);
                    package.notify_property ("installed");
                    packages.add (package);
                }
            }
        } catch (Error e) {
            critical (e.message);
        }

        return packages;
    }

    public Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        string categories = get_string_from_categories (category);
        try {
            var comps = appstream_database.find_components (null, categories);
            comps.foreach ((comp) => {
                apps.add (package_list.get (comp.get_pkgnames ()[0]));
            });
        } catch (Error e) {
            critical (e.message);
        }

        return apps;
    }

    private string get_string_from_categories (AppStream.Category category) {
        string categories = "";
        unowned Gee.LinkedList<string> categories_list = category.get_data<Gee.LinkedList> ("categories");
        foreach (var cat in categories_list) {
            if (categories != "") {
                categories += ";" + cat.down ();
            } else {
                categories = cat.down ();
            }
        }

        category.get_subcategories ().foreach ((cat) => {
            if (!(cat.name in categories)) {
                categories += ";" + get_string_from_categories (cat);
            }
        });

        return categories;
    }

    public Gee.Collection<AppCenterCore.Package> search_applications (string query) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        try {
            var comps = appstream_database.find_components (query, null);
            comps.foreach ((comp) => {
                apps.add (package_list.get (comp.get_pkgnames ()[0]));
            });
        } catch (Error e) {
            critical (e.message);
        }

        return apps;
    }

    public Pk.Package? get_app_package (string application, Pk.Bitfield additional_filters = 0) throws GLib.Error {
        AppCenter.Task packages_task = request_task (false);
        Pk.Package? package = null;
        var filter = Pk.Bitfield.from_enums (Pk.Filter.NEWEST);
        filter |= additional_filters;
        try {
            var results = packages_task.search_names_sync (filter, { application, null }, interface_cancellable, () => {});
            var array = results.get_package_array ();
            if (array.length > 0) {
                package = array.get (0);
            }
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
    public abstract void refresh_cache (bool force) throws IOError;
    public abstract void refresh_updates () throws IOError;
    public abstract string[] get_installed_packages () throws IOError;
}
