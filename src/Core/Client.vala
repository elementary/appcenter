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

    public bool connected { public get; private set; }
    public bool updating_cache { public get; private set; }
    public bool task_in_progress { public get; private set; }

    public AppCenterCore.Package os_updates { public get; private set; }
    public GLib.Cancellable cancellable { public get; private set; }

    private Gee.HashMap<string, AppCenterCore.Package> package_list;
    private AppStream.Database appstream_database;
    private GLib.DateTime last_cache_update;
    private uint updates_number = 0U;

    private AppCenter.Task client;
    private SuspendControl sc;

    private Client () {

    }

    construct {
        package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);
        cancellable = new GLib.Cancellable ();

        client = new AppCenter.Task ();
        sc = new SuspendControl ();

        appstream_database = new AppStream.Database ();

        try {
            appstream_database.open ();
            appstream_database.get_all_components ().foreach ((comp) => {
                var package = new AppCenterCore.Package (comp);
                foreach (var pkg_name in comp.get_pkgnames ()) {
                    package_list.set (pkg_name, package);
                }
            });            
        } catch (Error e) {
            error (e.message);
        }

        var icon = new AppStream.Icon ();
        icon.set_name ("distributor-logo");
        icon.set_kind (AppStream.IconKind.STOCK);

        var os_updates_component = new AppStream.Component ();
        os_updates_component.id = AppCenterCore.Package.OS_UPDATES_ID;
        os_updates_component.name = _("Operating System Updates");
        os_updates_component.summary = _("Updates to system components");
        os_updates_component.add_icon (icon);

        os_updates = new AppCenterCore.Package (os_updates_component);
    }

    public AppStream.Component? get_extension (string extension) throws GLib.Error {
        try {
            return appstream_database.get_component_by_id (extension); 
        } catch (Error e) {
            warning ("%s\n", e.message);
        }
        
        return null;
    }

    public async Pk.Exit install_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        task_in_progress = true;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pkg_name in package.component.get_pkgnames ()) {
            packages_ids += pkg_name;
        }

        packages_ids += null;

        try {
            var results = yield client.resolve_async (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.ARCH), packages_ids, cancellable, () => {});
            packages_ids = {};

            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });

            packages_ids += null;

            results = yield client.install_packages_async (packages_ids, cancellable, cb);
            exit_status = results.get_exit_code ();
            if (exit_status != Pk.Exit.SUCCESS) {
                throw new GLib.IOError.FAILED (Pk.Exit.enum_to_string (results.get_exit_code ()));
            }
        } catch (Error e) {
            task_in_progress = false;
            throw e;
        }

        task_in_progress = false;
        return exit_status;
    }

    public async Pk.Exit update_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        task_in_progress = true;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pk_package in package.change_information.changes) {
            packages_ids += pk_package.get_id ();
        }
        
        packages_ids += null;

        try {
            sc.inhibit ();

            var results = yield client.update_packages_async (packages_ids, cancellable, cb);
            exit_status = results.get_exit_code ();
        } catch (Error e) {
            task_in_progress = false;
            throw e;
        } finally {
            sc.uninhibit ();
        }

        if (exit_status != Pk.Exit.SUCCESS) {
            throw new GLib.IOError.FAILED (Pk.Exit.enum_to_string (exit_status));
        } else {
            package.change_information.clear_update_info ();
        }

        task_in_progress = false;
        yield refresh_updates ();
        return exit_status;
    }

    public async Pk.Exit remove_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        task_in_progress = true;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pkg_name in package.component.get_pkgnames ()) {
            packages_ids += pkg_name;
        }

        packages_ids += null;

        try {
            var results = yield client.resolve_async (Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST), packages_ids, cancellable, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });

            results = yield client.remove_packages_async (packages_ids, true, true, cancellable, cb);
            exit_status = results.get_exit_code ();
        } catch (Error e) {
            task_in_progress = false;
            throw e;
        }

        task_in_progress = false;
        yield refresh_updates ();
        return exit_status;
    }

    public async void get_updates () {
        task_in_progress = true;

        try {
            Pk.Results results = yield client.get_updates_async (0, cancellable, (t, p) => { });
            string[] packages_array = {};
            results.get_package_array ().foreach ((pk_package) => {
                packages_array += pk_package.get_id ();
            });

            // We need a null to show to PackageKit that it's then end of the array.
            packages_array += null;

            results = yield client.get_details_async (packages_array , cancellable, (t, p) => { });
            results.get_details_array ().foreach ((pk_detail) => {
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
                    package.update_state ();
                } catch (Error e) {
                    critical (e.message);
                }
            });
        } catch (Error e) {
            // Error code 19 is for operation canceled.
            if (e.code != 19) {
                critical (e.message);
            }

            task_in_progress = false;
            return;
        }

        task_in_progress = false;
        updates_available ();
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications () {
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();
        var installed = yield get_installed_packages ();
        foreach (var pk_package in installed) {
            var package = package_list.get (pk_package.get_name ());
            if (package != null) {
                package.installed_packages.add (pk_package);
                package.update_state ();
                packages.add (package);
            }
        }

        return packages;
    }

    public Gee.Collection<AppCenterCore.Package> search_applications (string? query, AppStream.Category? category) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        string categories = category == null ? null : get_string_from_categories (category);
        try {
            var comps = appstream_database.find_components (query, categories);
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

    public Pk.Package? get_app_package (string application, Pk.Bitfield additional_filters = 0) throws GLib.Error {
        task_in_progress = true;

        Pk.Package? package = null;
        var filter = Pk.Bitfield.from_enums (Pk.Filter.NEWEST);
        filter |= additional_filters;
        try {
            var results = client.search_names_sync (filter, { application, null }, cancellable, () => {});
            var array = results.get_package_array ();
            if (array.length > 0) {
                package = array.get (0);
            }
        } catch (Error e) {
            task_in_progress = false;
            throw e;
        }

        task_in_progress = false;
        return package;
    }

    public async void refresh_updates () {
        updating_cache = true;
        task_in_progress = true;

        try {
            Pk.Results results = yield client.get_updates_async (0, null, (t, p) => {});
            bool was_empty = updates_number == 0U;
            updates_number = get_package_count (results.get_package_array ());

            var application = Application.get_default ();
            if (was_empty && updates_number != 0U) {
                string title = ngettext ("Update Available", "Updates Available", updates_number);
                string body = ngettext ("%u update is available for your system", "%u updates are available for your system", updates_number).printf (updates_number);

                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("system-software-install"));
                notification.set_default_action ("app.open-application");

                application.send_notification ("updates", notification);
            } else {
                application.withdraw_notification ("updates");
            }

#if HAVE_UNITY
            var launcher_entry = Unity.LauncherEntry.get_for_desktop_file ("org.pantheon.appcenter.desktop");
            launcher_entry.count = updates_number;
            launcher_entry.count_visible = updates_number != 0U;
#endif
        } catch (Error e) {
            critical (e.message);
        }

        updating_cache = false;
        task_in_progress = false;
    }

    public uint get_package_count (GLib.GenericArray<weak Pk.Package> package_array) {
        bool os_update_found = false;
        var result_comp = new Gee.TreeSet<AppStream.Component> ();

        package_array.foreach ((pk_package) => {
            var comp = package_list.get (pk_package.get_name ());
            if (comp != null) {
                result_comp.add (comp.component);
            } else {
                os_update_found = true;
            }
        });

        uint size = result_comp.size;
        if (os_update_found) {
            size++;
        }

        return size;
    }

    public async void update_cache (bool force = false) {
        // One cache update a day, keeps the doctor away!
        if (force || last_cache_update == null || (new DateTime.now_local ()).difference (last_cache_update) >= GLib.TimeSpan.DAY) {
            task_in_progress = true;

            try {
                yield client.refresh_cache_async (false, null, (t, p) => { });
                last_cache_update = new DateTime.now_local ();
            } catch (Error e) {
                critical (e.message);
            }

            task_in_progress = false;
            refresh_updates.begin ();
        }

        GLib.Timeout.add_seconds (60*60*24, () => {
            update_cache.begin ();
            return GLib.Source.REMOVE;
        });
    }

    public async Gee.TreeSet<Pk.Package> get_installed_packages () {
        task_in_progress = true;

        Pk.Bitfield filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
        var installed = new Gee.TreeSet<Pk.Package> ();

        try {
            Pk.Results results = yield client.get_packages_async (filter, null, (prog, type) => {});
            results.get_package_array ().foreach ((pk_package) => {
                installed.add (pk_package);
            });

        } catch (Error e) {
            critical (e.message);
        }

        task_in_progress = false;
        return installed;
    }

    private static GLib.Once<Client> instance;
    public static unowned Client get_default () {
        return instance.once (() => { return new Client (); });
    }
}
