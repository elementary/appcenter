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
    public signal void operation_finished (Package package, Package.State operation, Error? error);
    public signal void cache_update_failed (Error error);
    public signal void updates_available ();
    public signal void drivers_detected ();

    protected static Task client { public get; private set; }
    public static Task get_pk_client () {
        return client;
    }

    public bool connected { public get; private set; }

    private uint _task_count = 0;
    public uint task_count {
        public get {
            return _task_count;
        }
        private set {
            _task_count = value;
            last_action = new DateTime.now_local ();
        }
    }

    public bool updating_cache { public get; private set; default = false; }

    public AppCenterCore.Package os_updates { public get; private set; }
    public Gee.TreeSet<AppCenterCore.Package> driver_list { get; construct; }

    private Gee.HashMap<string, AppCenterCore.Package> package_list;
    private AppStream.Pool appstream_pool;
    private GLib.Cancellable cancellable;

    private GLib.DateTime last_cache_update = null;
    private GLib.DateTime last_action = null;

    public uint updates_number { get; private set; default = 0U; }
    private uint update_cache_timeout_id = 0;
    private bool refresh_in_progress = false;

    private const int SECONDS_BETWEEN_REFRESHES = 60 * 60 * 24;
    private const int PACKAGEKIT_ACTIVITY_TIMEOUT_MS = 2000;

    private SuspendControl sc;

    private Client () {

    }

    static construct {
        client = new Task ();
    }

    construct {
        package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);
        driver_list = new Gee.TreeSet<AppCenterCore.Package> ();
        cancellable = new GLib.Cancellable ();

        sc = new SuspendControl ();

        appstream_pool = new AppStream.Pool ();
        // We don't want to show installed desktop files here
        appstream_pool.set_flags (appstream_pool.get_flags () & ~AppStream.PoolFlags.READ_DESKTOP_FILES);

        try {
            appstream_pool.load ();

            var comp_validator = ComponentValidator.get_default ();
            appstream_pool.get_components ().foreach ((comp) => {
                if (!comp_validator.validate (comp)) {
                    return;
                }

                var package = new AppCenterCore.Package (comp);
                foreach (var pkg_name in comp.get_pkgnames ()) {
                    package_list[pkg_name] = package;
                }
            });
        } catch (Error e) {
            critical (e.message);
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

        var control = new Pk.Control ();
        control.updates_changed.connect (updates_changed_callback);
    }

    private void updates_changed_callback () {
        if (!has_tasks ()) {
            UpdateManager.get_default ().update_restart_state ();

            var time_since_last_action = (new DateTime.now_local ()).difference (last_action) / GLib.TimeSpan.MILLISECOND;
            if (time_since_last_action >= PACKAGEKIT_ACTIVITY_TIMEOUT_MS) {
                info ("packages possibly changed by external program, refreshing cache");
                update_cache.begin (true);
            }
        }
    }

    public bool has_tasks () {
        return task_count > 0;
    }

    public Package? add_local_component_file (File file) throws Error {
        var metadata = new AppStream.Metadata ();
        try {
            metadata.parse_file (file, AppStream.FormatKind.XML);
        } catch (Error e) {
            throw e;
        }

        var component = metadata.get_component ();
        if (component != null) {
            string name = _("%s (local)").printf (component.get_name ());
            string id = "%s%s".printf (component.get_id (), Package.LOCAL_ID_SUFFIX);

            component.set_name (name, null);
            component.set_id (id);
            component.set_origin (Package.APPCENTER_PACKAGE_ORIGIN);

            appstream_pool.add_component (component);

            var package = new AppCenterCore.Package (component);
            package_list[id] = package;

            return package;
        }

        return null;
    }

    public async Pk.Exit install_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        task_count++;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pkg_name in package.component.get_pkgnames ()) {
            packages_ids += pkg_name;
        }

        packages_ids += null;

        try {
            var results = yield client.resolve_async (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.ARCH), packages_ids, cancellable, () => {});

            /*
             * If there were no packages found for the requested architecture,
             * try to resolve IDs by not searching for this architecture
             * e.g: filtering 32 bit only package on a 64 bit system
             */
            GenericArray<weak Pk.Package> package_array = results.get_package_array ();
            if (package_array.length == 0) {
                results = yield client.resolve_async (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.NOT_ARCH), packages_ids, cancellable, () => {});
                package_array = results.get_package_array ();
            }

            packages_ids = {};
            package_array.foreach ((package) => {
                packages_ids += package.package_id;
            });

            packages_ids += null;

            results = yield client.install_packages_async (packages_ids, cancellable, cb);
            exit_status = results.get_exit_code ();
        } catch (Error e) {
            task_count--;
            throw e;
        }

        task_count--;
        return exit_status;
    }

    public async Pk.Exit update_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        task_count++;

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
            task_count--;
            throw e;
        } finally {
            sc.uninhibit ();
        }

        if (exit_status != Pk.Exit.SUCCESS) {
#if VALA_0_40
            throw new GLib.IOError.FAILED (exit_status.enum_to_string());
#else
            throw new GLib.IOError.FAILED (Pk.Exit.enum_to_string (exit_status));
#endif
        } else {
            package.change_information.clear_update_info ();
        }

        task_count--;
        yield refresh_updates ();
        return exit_status;
    }

    public async Pk.Exit remove_package (Package package, Pk.ProgressCallback cb, GLib.Cancellable cancellable) throws GLib.Error {
        task_count++;

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
            task_count--;
            throw e;
        }

        task_count--;
        yield refresh_updates ();
        return exit_status;
    }

    public void get_drivers () {
        task_count++;
        if (driver_list.size > 0) {
            drivers_detected ();
            task_count--;
            return;
        }

        string? drivers_exec_path = Environment.find_program_in_path ("ubuntu-drivers");
        if (drivers_exec_path == null) {
            task_count--;
            return;
        }

        var command = new Granite.Services.SimpleCommand ("/", "%s list".printf (drivers_exec_path));
        command.done.connect ((command, status) => parse_drivers_output (command.standard_output_str, status));
        command.run ();
    }

    private void parse_drivers_output (string output, int status) {
        if (status != 0) {
            task_count--;
            return;
        }

        new Thread<void*> ("parse-drivers-output", () => {
            string[] tokens = output.split ("\n");
            for (int i = 0; i < tokens.length; i++) {
                string package_name = tokens[i];
                if (package_name.strip () == "") {
                    continue;
                }

                var driver_component = new AppStream.Component ();
                driver_component.set_kind (AppStream.ComponentKind.DRIVER);
                driver_component.set_pkgnames ({ package_name });
                driver_component.set_id (package_name);

                var icon = new AppStream.Icon ();
                icon.set_name ("application-x-firmware");
                icon.set_kind (AppStream.IconKind.STOCK);
                driver_component.add_icon (icon);

                var package = new Package (driver_component);
                var pk_package = package.find_package ();
                if (pk_package != null && pk_package.get_info () == Pk.Info.INSTALLED) {
                    package.installed_packages.add (pk_package);
                    package.update_state ();
                }

                driver_list.add (package);
            }

            Idle.add (() => {
                drivers_detected ();
                return false;
            });

            task_count--;
            return null;
        });
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications () {
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();
        var installed = yield get_installed_packages ();
        foreach (var pk_package in installed) {
            var package = package_list[pk_package.get_name ()];
            if (package != null) {
                populate_package (package, pk_package);
                packages.add (package);
            }
        }

        return packages;
    }

    public Gee.Collection<AppCenterCore.Package> get_installed_applications_sync () {
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();
        var installed = get_installed_packages_sync ();
        foreach (var pk_package in installed) {
            var package = package_list[pk_package.get_name ()];
            if (package != null) {
                populate_package (package, pk_package);
                packages.add (package);
            }
        }

        return packages;
    }

    private static void populate_package (AppCenterCore.Package package, Pk.Package pk_package) {
        package.installed_packages.add (pk_package);
        package.latest_version = pk_package.get_version ();
        package.update_state ();
    }

    public Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category) {
        unowned GLib.GenericArray<AppStream.Component> components = category.get_components ();
        if (components.length == 0) {
            var category_array = new GLib.GenericArray<AppStream.Category> ();
            category_array.add (category);
            AppStream.utils_sort_components_into_categories (appstream_pool.get_components (), category_array, true);
            components = category.get_components ();
        }

        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        components.foreach ((comp) => {
            var package = get_package_for_component_id (comp.get_id ());
            if (package != null) {
                apps.add (package);
            }
        });

        return apps;
    }

    public Gee.Collection<AppCenterCore.Package> search_applications (string query, AppStream.Category? category) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        GLib.GenericArray<weak AppStream.Component> comps = appstream_pool.search (query);
        if (category == null) {
            comps.foreach ((comp) => {
                var package = get_package_for_component_id (comp.get_id ());
                if (package != null) {
                    apps.add (package);
                }
            });
        } else {
            var cat_packages = get_applications_for_category (category);
            comps.foreach ((comp) => {
                var package = get_package_for_component_id (comp.get_id ());
                if (package != null && package in cat_packages) {
                    apps.add (package);
                }
            });
        }

        return apps;
    }

    public Pk.Package? get_app_package (string application, Pk.Bitfield additional_filters = 0) throws GLib.Error {
        task_count++;

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
            task_count--;
            throw e;
        }

        if (package != null) {
            Pk.Results details = client.get_details_sync ({ package.package_id, null }, null, (t, p) => {});
            details.get_details_array ().foreach ((details) => {
                package.license = details.license;
                package.description = details.description;
                package.summary = details.summary;
                package.group = details.group;
                package.size = details.size;
                package.url = details.url;
            });
        }

        task_count--;
        return package;
    }

    private async void refresh_updates () {
        task_count++;

        try {
            Pk.Results results = yield UpdateManager.get_default ().get_updates (null);

            bool was_empty = updates_number == 0U;
            updates_number = get_real_packages_length (results.get_package_array ());

            var application = Application.get_default ();
            if (was_empty && updates_number != 0U) {
                string title = ngettext ("Update Available", "Updates Available", updates_number);
                string body = ngettext ("%u update is available for your system", "%u updates are available for your system", updates_number).printf (updates_number);

                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("system-software-install"));
                notification.set_default_action ("app.show-updates");

                application.send_notification ("updates", notification);
            } else {
                application.withdraw_notification ("updates");
            }

#if HAVE_UNITY
            var launcher_entry = Unity.LauncherEntry.get_for_desktop_file (Build.DESKTOP_FILE);
            launcher_entry.count = updates_number;
            launcher_entry.count_visible = updates_number != 0U;
#endif

            uint os_count = 0;
            string os_desc = "";

            results.get_package_array ().foreach ((pk_package) => {
                unowned string pkg_name = pk_package.get_name ();
                var package = package_list[pkg_name];
                if (package == null) {
                    unowned string pkg_summary = pk_package.get_summary();
                    unowned string pkg_version = pk_package.get_version();
                    os_count += 1;
                    os_desc += Markup.printf_escaped ("<li>%s\n\t%s\n\t%s</li>\n", pkg_name, pkg_summary, _("Version: %s").printf (pkg_version));
                } else {
                    package.latest_version = pk_package.get_version ();
                    package.change_information.changes.clear ();
                    package.change_information.details.clear ();
                }
            });

            if (os_count == 0){
                var latest_version = _("No components with updates");
                os_updates.latest_version = latest_version;
                os_updates.description = GLib.Markup.printf_escaped ("<p>%s</p>\n", latest_version);
            } else {
                var latest_version = ngettext ("%u component with updates", "%u components with updates", os_count).printf (os_count);
                os_updates.latest_version = latest_version;
                os_updates.description = "<p>%s</p>\n<ul>\n%s</ul>\n".printf (GLib.Markup.printf_escaped (_("%s:"), latest_version), os_desc);
            }

            os_updates.component.set_pkgnames({});
            os_updates.change_information.changes.clear ();
            os_updates.change_information.details.clear ();

            results.get_details_array ().foreach ((pk_detail) => {
                var pk_package = new Pk.Package ();
                try {
                    pk_package.set_id (pk_detail.get_package_id ());

                    unowned string pkg_name = pk_package.get_name ();
                    var package = package_list[pkg_name];
                    if (package == null) {
                        var pkgnames = os_updates.component.pkgnames;
                        pkgnames += pkg_name;
                        os_updates.component.pkgnames = pkgnames;

                        os_updates.change_information.changes.add (pk_package);
                        os_updates.change_information.details.add (pk_detail);
                    } else {
                        package.change_information.changes.add (pk_package);
                        package.change_information.details.add (pk_detail);
                        package.update_state ();
                    }
                } catch (Error e) {
                    critical (e.message);
                }
            });

            os_updates.update_state();
        } catch (Error e) {
            critical (e.message);
        }

        task_count--;
        updates_available ();
    }

    private uint get_real_packages_length (GLib.GenericArray<weak Pk.Package> package_array) {
        bool os_update_found = false;
        var result_comp = new Gee.TreeSet<AppStream.Component> ();

        package_array.foreach ((pk_package) => {
            var package = package_list[pk_package.get_name ()];
            if (package != null) {
                result_comp.add (package.component);
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

    public void cancel_updates (bool cancel_timeout) {
        cancellable.cancel ();

        if (update_cache_timeout_id > 0 && cancel_timeout) {
            Source.remove (update_cache_timeout_id);
            update_cache_timeout_id = 0;
            last_cache_update = null;
        }

        cancellable = new GLib.Cancellable ();
        refresh_in_progress = false;
    }

    public async void update_cache (bool force = false) {
        debug ("update cache called %s", force.to_string ());
        bool success = false;

        /* Make sure only one update cache can run at a time */
        if (refresh_in_progress) {
            debug ("Update cache already in progress - returning");
            return;
        }

        if (update_cache_timeout_id > 0) {
            if (force) {
                debug ("Forced update_cache called when there is an on-going timeout - cancelling timeout");
                Source.remove (update_cache_timeout_id);
                update_cache_timeout_id = 0;
            } else {
                debug ("Refresh timeout running and not forced - returning");
                refresh_in_progress = false;
                return;
            }
        }

        /* One cache update a day, keeps the doctor away! */
        if (force || last_cache_update == null ||
            (new DateTime.now_local ()).difference (last_cache_update) / GLib.TimeSpan.SECOND >= SECONDS_BETWEEN_REFRESHES) {
            var nm = NetworkMonitor.get_default ();
            if (nm.get_network_available ()) {
                debug ("New refresh task");

                refresh_in_progress = true;
                updating_cache = true;
                try {
                    Pk.Results results = yield client.refresh_cache_async (false, cancellable, (t, p) => { });
                    success = results.get_exit_code () == Pk.Exit.SUCCESS;
                    last_cache_update = new DateTime.now_local ();
                } catch (Error e) {
                    refresh_in_progress = false;
                    updating_cache = false;

                    critical ("Update_cache: Refesh cache async failed - %s", e.message);
                    cache_update_failed (e);
                }

                if (success) {
                    refresh_updates.begin ();
                }
            }

            refresh_in_progress = false; //Stops new timeout while no network.
            updating_cache = false;
        } else {
            debug ("Too soon to refresh and not forced");
        }

        if (refresh_in_progress) {
            update_cache_timeout_id = GLib.Timeout.add_seconds (SECONDS_BETWEEN_REFRESHES, () => {
                update_cache_timeout_id = 0;
                update_cache.begin (true);
                return GLib.Source.REMOVE;
            });

            refresh_in_progress = success;
        } // Otherwise updates and timeout were cancelled during refresh, or no network present.
    }

    public async Gee.TreeSet<Pk.Package> get_installed_packages () {
        task_count++;

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

        task_count--;
        return installed;
    }

    public Gee.TreeSet<Pk.Package> get_installed_packages_sync () {
        task_count++;

        Pk.Bitfield filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
        var installed = new Gee.TreeSet<Pk.Package> ();

        try {
            Pk.Results results = client.get_packages_sync (filter, null, (prog, type) => {});
            results.get_package_array ().foreach ((pk_package) => {
                installed.add (pk_package);
            });

        } catch (Error e) {
            critical (e.message);
        }

        task_count--;
        return installed;
    }

    public async Gee.ArrayList<Pk.Package> get_needed_deps_for_package (AppCenterCore.Package package, Cancellable? cancellable) {
        var pk_package = package.find_package ();
        var deps = new Gee.ArrayList<Pk.Package> ();

        if (pk_package == null) {
            return deps;
        }

        string[] package_array = { pk_package.package_id, null };
        var filters = Pk.Bitfield.from_enums (Pk.Filter.NOT_INSTALLED);
        try {
            var deps_result = yield client.depends_on_async (filters, package_array, false, cancellable, (p, t) => {});
            deps_result.get_package_array ().foreach ((dep_package) => {
                deps.add (dep_package);
            });

            package_array = {};
            foreach (var dep_package in deps) {
                package_array += dep_package.package_id;
            }

            package_array += null;
            if (package_array.length > 1) {
                deps_result = yield client.depends_on_async (filters, package_array, true, cancellable, (p, t) => {});
                deps_result.get_package_array ().foreach ((dep_package) => {
                    deps.add (dep_package);
                });
            }
        } catch (Error e) {
            warning ("Error fetching dependencies for %s: %s", pk_package.package_id, e.message);
        }

        return deps;
    }

    public AppCenterCore.Package? get_package_for_component_id (string id) {
        foreach (var package in package_list.values) {
            if (package.component.id == id) {
                return package;
            }
        }

        return null;
    }

    public AppCenterCore.Package? get_package_for_desktop_id (string desktop_id) {
        foreach (var package in package_list.values) {
            if (package.component.get_desktop_id () == desktop_id) {
                return package;
            }
        }

        return null;
    }

    public Gee.Collection<AppCenterCore.Package> get_packages_by_author (string author, int max) {
        var packages = new Gee.ArrayList<AppCenterCore.Package> ();
        foreach (var package in package_list.values) {
            if (packages.size > max) {
                break;
            }

            if (package.component.developer_name == author) {
                packages.add (package);
            }
        }

        return packages;
    }

    private static GLib.Once<Client> instance;
    public static unowned Client get_default () {
        return instance.once (() => { return new Client (); });
    }
}
