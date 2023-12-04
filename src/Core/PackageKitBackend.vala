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

errordomain PackageKitBackendError {
    PACKAGE_NOT_FOUND
}

public class AppCenterCore.PackageKitBackend : Backend, Object {
    private static Task client;
    private AsyncQueue<Job> jobs = new AsyncQueue<Job> ();
    private Thread<bool> worker_thread;

    private GLib.DateTime last_action = null;
    private Gee.HashMap<string, AppCenterCore.Package> package_list;
    private AppStream.Pool appstream_pool;

    public string[] fake_packages { get; set; }

    private const string FAKE_PACKAGE_ID = "%s;fake.version;amd64;installed:xenial-main";

    private const int PACKAGEKIT_ACTIVITY_TIMEOUT_MS = 2000;

    // This is OK as we're only using a single thread (PackageKit can only do one job at a time)
    // This would have to be done differently if there were multiple workers in the pool
    private bool thread_should_run = true;

    public Job.Type job_type { get; protected set; }
    public bool working { public get; protected set; }

    private static Polkit.Permission? update_permission = null;

    // The aptcc backend included in PackageKit < 1.1.10 wasn't able to support multiple packages
    // passed to the search_names method at once. If we have a new enough version we can enable
    // some optimisations when looking up packages
    public static bool supports_parallel_package_queries {
        get {
            if (control.backend_name != "aptcc") {
                return true;
            }

            if (control.version_major >= 1 &&
                control.version_minor >= 1 &&
                control.version_micro >= 10) {
                return true;
            }

            return false;
        }
    }

    private static Pk.Control? _control;
    private static unowned Pk.Control control {
        get {
            if (_control == null) {
                _control = new Pk.Control ();
            }

            return _control;
        }
    }

    private bool can_cancel = true;
    private int current_progress = 0;
    private int last_progress = 0;
    private Pk.Status current_status = Pk.Status.SETUP;
    private Pk.Status status = Pk.Status.SETUP;
    private double progress_denom = 200.0f;
    private double progress = 0.0f;

    private bool worker_func () {
        while (thread_should_run) {
            last_action = new DateTime.now_local ();
            working = false;
            var job = jobs.pop ();
            job_type = job.operation;
            working = true;
            switch (job.operation) {
                case Job.Type.GET_PREPARED_PACKAGES:
                    get_prepared_packages_internal (job);
                    break;
                case Job.Type.GET_INSTALLED_PACKAGES:
                    get_installed_packages_internal (job);
                    break;
                case Job.Type.GET_DOWNLOAD_SIZE:
                    get_download_size_internal (job);
                    break;
                case Job.Type.REFRESH_CACHE:
                    refresh_cache_internal (job);
                    break;
                case Job.Type.GET_UPDATES:
                    get_updates_internal (job);
                    break;
                case Job.Type.INSTALL_PACKAGE:
                    install_package_internal (job);
                    break;
                case Job.Type.UPDATE_PACKAGE:
                    update_package_internal (job);
                    break;
                case Job.Type.REMOVE_PACKAGE:
                    remove_package_internal (job);
                    break;
                case Job.Type.IS_PACKAGE_INSTALLED:
                    is_package_installed_internal (job);
                    break;
                case Job.Type.GET_PACKAGE_DETAILS:
                    get_package_details_internal (job);
                    break;
                case Job.Type.GET_PACKAGE_DEPENDENCIES:
                    get_package_dependencies_internal (job);
                    break;
                default:
                    assert_not_reached ();
            }
        }

        return true;
    }

    static construct {
        _control = new Pk.Control ();

        // Work around an issue where if we call any synchronous method on PackageKit,
        // we never receive signals from Pk.Control.Calling this here causes packagekit-glib2 to
        // connect to the PackageKit DBus and fire signals on the right thread.
        // See: https://github.com/hughsie/PackageKit/issues/207
        var loop = new MainLoop ();
        _control.get_properties_async.begin (null, (obj, res) => {
            try {
                _control.get_properties_async.end (res);
            } catch (Error e) {
                warning (e.message);
            }

            loop.quit ();
        });

        loop.run ();
        client = new Task () {
            only_download = true
        };
    }

    private PackageKitBackend () {
        worker_thread = new Thread<bool> ("packagekit-worker", worker_func);

        package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);
        appstream_pool = new AppStream.Pool ();

        // Clear out the default set of metadata locations and only use the folder that gets populated
        // with elementary's AppStream data.
#if HIDE_UPSTREAM_DISTRO_APPS
#if HAS_APPSTREAM_0_16
        // Don't load Ubuntu components
        appstream_pool.set_load_std_data_locations (false);
        appstream_pool.reset_extra_data_locations ();
        appstream_pool.add_extra_data_location ("/usr/share/app-info", AppStream.FormatStyle.CATALOG);
#elif HAS_APPSTREAM_0_15
        // Don't load Ubuntu components
        appstream_pool.set_load_std_data_locations (false);
        appstream_pool.reset_extra_data_locations ();
        appstream_pool.add_extra_data_location ("/usr/share/app-info", AppStream.FormatStyle.COLLECTION);
#else
        // Only use a user cache, the system cache probably contains all the Ubuntu components
        appstream_pool.set_cache_flags (AppStream.CacheFlags.USE_USER);

        appstream_pool.clear_metadata_locations ();
        appstream_pool.add_metadata_location ("/usr/share/app-info");
#endif
#endif

        // We don't want to show installed desktop files here
#if HAS_APPSTREAM_0_15
        appstream_pool.set_flags (
            appstream_pool.get_flags () |
            AppStream.PoolFlags.RESOLVE_ADDONS &
            ~AppStream.PoolFlags.LOAD_OS_DESKTOP_FILES
        );
#else
        appstream_pool.set_flags (appstream_pool.get_flags () & ~AppStream.PoolFlags.READ_DESKTOP_FILES);
#endif

        reload_appstream_pool ();

        var proxy_resolver = GLib.ProxyResolver.get_default ();
        string? http_proxy = null;
        string? ftp_proxy = null;

        try {
            // We need an address of something on the internet to see if we need a proxy or not. It's not really
            // important that this is launchpad, it could be google or fake-made-up-domain.com as it's not resolved
            // at this point. May as well use a real address that PackageKit may need a proxy for though.
            var possible_proxies = proxy_resolver.lookup ("http://ppa.launchpad.net");
            if (possible_proxies.length > 0 && possible_proxies[0] != "direct://") {
                http_proxy = possible_proxies[0];
            }
        } catch (Error e) {
            warning ("Unable to lookup http proxy to use for PackageKit: %s", e.message);
        }

        try {
            var possible_proxies = proxy_resolver.lookup ("ftp://ppa.launchpad.net");
            if (possible_proxies.length > 0 && possible_proxies[0] != "direct://") {
                ftp_proxy = possible_proxies[0];
            }
        } catch (Error e) {
            warning ("Unable to lookup ftp proxy to use for PackageKit: %s", e.message);
        }

        try {
            control.set_proxy (http_proxy, ftp_proxy);
        } catch (Error e) {
            warning ("Unable to set proxy for PackageKit to use: %s", e.message);
        }

        control.updates_changed.connect (updates_changed_callback);
    }

    private void updates_changed_callback () {
        if (!working) {
            UpdateManager.get_default ().update_restart_state ();

            var time_since_last_action = (new DateTime.now_local ()).difference (last_action) / GLib.TimeSpan.MILLISECOND;
            if (time_since_last_action >= PACKAGEKIT_ACTIVITY_TIMEOUT_MS) {
                info ("packages possibly changed by external program, refreshing cache");

                // Clear the installed state of all packages as something may have changed we weren't
                // aware of
                foreach (var package in package_list.values) {
                    if (package.state != Package.State.NOT_INSTALLED || package.installed) {
                        package.clear_installed ();
                    }
                }

                trigger_update_check.begin ();
            }
        }
    }

    private async void trigger_update_check () {
        try {
            yield refresh_cache (null);
        } catch (Error e) {
            warning ("Unable to refresh cache after external change: %s", e.message);
        }

        yield Client.get_default ().refresh_updates ();
    }

    ~PackageKitBackend () {
        thread_should_run = false;
        worker_thread.join ();
    }

    private void reload_appstream_pool () {
        try {
            appstream_pool.load ();
        } catch (Error e) {
            critical (e.message);
        } finally {
            var new_package_list = new Gee.HashMap<string, Package> ();
            var comp_validator = ComponentValidator.get_default ();
#if HAS_APPSTREAM_1_0
            appstream_pool.get_components ().as_array ().foreach ((comp) => {
#else
            appstream_pool.get_components ().foreach ((comp) => {
#endif
                if (!comp_validator.validate (comp)) {
                    return;
                }

                foreach (unowned string pkg_name in comp.get_pkgnames ()) {
                    var package = package_list[pkg_name];
                    if (package != null) {
                        package.replace_component (comp);
                    } else {
                        package = new Package (this, comp);
                    }

                    new_package_list[pkg_name] = package;
                }
            });

            package_list = new_package_list;
        }
    }

    public Package? lookup_package_by_id (string id) {
        return package_list[id];
    }

    public Package? add_local_component_file (File file) throws Error {
        var metadata = new AppStream.Metadata ();
        try {
            metadata.parse_file (file, AppStream.FormatKind.XML);
        } catch (Error e) {
            throw e;
        }

        unowned var component = metadata.get_component ();
        if (component != null) {
            string name = _("%s (local)").printf (component.get_name ());
            string id = "%s%s".printf (component.get_id (), Package.LOCAL_ID_SUFFIX);

            component.set_name (name, null);
            component.set_id (id);
            component.set_origin (Package.APPCENTER_PACKAGE_ORIGIN);

#if HAS_APPSTREAM_1_0
            var components = new AppStream.ComponentBox (AppStream.ComponentBoxFlags.NONE);
            components.add (component);

            appstream_pool.add_components (components);
#elif HAS_APPSTREAM_0_15
            var components = new GenericArray<AppStream.Component> ();
            components.add (component);

            appstream_pool.add_components (components);
#else
            appstream_pool.add_component (component);
#endif

            var package = new AppCenterCore.Package (this, component);
            package_list[id] = package;

            return package;
        }

        return null;
    }

    public async Gee.Collection<AppCenterCore.PackageDetails> get_prepared_applications (Cancellable? cancellable = null) {
        var packages = new Gee.TreeSet<AppCenterCore.PackageDetails> ();

        var pk_prepared = yield get_prepared_packages ();
        var package_array = pk_prepared.get_package_array ();
        foreach (var pk_package in package_array) {
            packages.add (new PackageDetails () {
                name = pk_package.get_name (),
                description = pk_package.description,
                summary = pk_package.get_summary (),
                version = pk_package.get_version ()
            });
        }

        if (package_array.length > 0) {
            updates_changed_callback ();
        }

        return packages;
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications (Cancellable? cancellable = null) {
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();
        var installed = yield get_installed_packages (cancellable);
        foreach (var pk_package in installed) {
            if (cancellable.is_cancelled ()) {
                break;
            }

            var package = populate_basic_package_details (pk_package);
            if (package != null) {
                packages.add (package);
            }
        }

        return packages;
    }

    public Package? get_package_for_component_id (string id) {
        foreach (var package in package_list.values) {
            if (package.component.id == id) {
                return package;
            } else if (package.component.id == id + ".desktop") {
                return package;
            }
        }

        return null;
    }

    public Gee.HashMap<string, AppCenterCore.Package> get_packages_for_component_ids (string[] ids) {
        var packages = new Gee.HashMap<string, AppCenterCore.Package> ();
        foreach (unowned string id in ids) {
            var package = get_package_for_component_id (id);
            if (package != null) {
                packages.set (id, package);
            }
        }

        return packages;
    }

    public Gee.Collection<Package> get_packages_for_component_id (string id) {
        var packages = new Gee.ArrayList<Package> ();
        var suffixed_id = id + ".desktop";
        foreach (var package in package_list.values) {
            if (package.component.id == id) {
                packages.add (package);
            } else if (package.component.id == suffixed_id) {
                packages.add (package);
            }
        }

        return packages;
    }

    public AppCenterCore.Package? get_package_for_desktop_id (string desktop_id) {
        foreach (var package in package_list.values) {
            if (package.component.id == desktop_id ||
                package.component.id + ".desktop" == desktop_id
            ) {
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

#if HAS_APPSTREAM_1_0
            if (package.component.get_developer ().get_name () == author) {
#else
            if (package.component.developer_name == author) {
#endif
                packages.add (package);
            }
        }

        return packages;
    }

    public Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category) {
        unowned GLib.GenericArray<AppStream.Component> components = category.get_components ();
        // Clear out any cached components that could be from other backends
        if (components.length != 0) {
            components.remove_range (0, components.length);
        }

        var category_array = new GLib.GenericArray<AppStream.Category> ();
        category_array.add (category);
#if HAS_APPSTREAM_1_0
        AppStream.utils_sort_components_into_categories (appstream_pool.get_components ().as_array (), category_array, true);
#else
        AppStream.utils_sort_components_into_categories (appstream_pool.get_components (), category_array, true);
#endif
        components = category.get_components ();

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
        var comps = appstream_pool.search (query);
        if (category == null) {
#if HAS_APPSTREAM_1_0
            comps.as_array ().foreach ((comp) => {
#else
            comps.foreach ((comp) => {
#endif
                var package = get_package_for_component_id (comp.get_id ());
                if (package != null) {
                    apps.add (package);
                }
            });
        } else {
            var cat_packages = get_applications_for_category (category);
#if HAS_APPSTREAM_1_0
            comps.as_array ().foreach ((comp) => {
#else
            comps.foreach ((comp) => {
#endif
                var package = get_package_for_component_id (comp.get_id ());
                if (package != null && package in cat_packages) {
                    apps.add (package);
                }
            });
        }

        return apps;
    }

    public Gee.Collection<AppCenterCore.Package> search_applications_mime (string query) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        foreach (var package in package_list.values) {
            weak AppStream.Provided? provided = package.component.get_provided_for_kind (AppStream.ProvidedKind.MEDIATYPE);
            if (provided != null && provided.has_item (query)) {
                apps.add (package);
            }
        }

        return apps;
    }

    private async Job launch_job (Job.Type type, JobArgs? args = null) {
        var job = new Job (type);
        job.args = args;

        SourceFunc callback = launch_job.callback;
        job.results_ready.connect (() => {
            Idle.add ((owned) callback);
        });

        jobs.push (job);
        yield;
        return job;
    }

    private void get_prepared_packages_internal (Job job) {
        var args = (GetPreparedPackagesArgs)job.args;
        var cancellable = args.cancellable;

        Pk.Results? results = null;
        try {
            results = client.get_updates (0, cancellable, (t, p) => { });
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        string[] package_ids = {};
        var downloaded_updates = get_downloaded_updates ();
        results.get_package_array ().foreach ((pk_package) => {
            if (downloaded_updates.contains (pk_package.get_id ())) {
                package_ids += pk_package.get_id ();
            }
        });

        if (package_ids.length == 0) {
            job.result = Value (typeof (Object));
            job.result.take_object (new Pk.Results ());
            job.results_ready ();
            return;
        }

        package_ids += null;

        Pk.Results details;
        try {
            details = client.get_details (package_ids, cancellable, (p, t) => {});
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        details.get_details_array ().foreach ((details) => {
            results.add_details (details);
        });

        job.result = Value (typeof (Object));
        job.result.take_object ((owned) results);
        job.results_ready ();
    }

    public async Pk.Results get_prepared_packages (Cancellable? cancellable = null) {
        var job_args = new GetPreparedPackagesArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.GET_PREPARED_PACKAGES, job_args);
        return (Pk.Results)job.result.get_object ();
    }

    private void get_installed_packages_internal (Job job) {
        unowned var args = (GetInstalledPackagesArgs)job.args;
        unowned var cancellable = args.cancellable;

        Pk.Bitfield filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
        var installed = new Gee.TreeSet<Pk.Package> ();

        try {
            Pk.Results results = client.get_packages (filter, cancellable, (prog, type) => {});
            var packages = results.get_package_array ();

            for (int i = 0; i < packages.length; i++) {
                if (cancellable != null && cancellable.is_cancelled ()) {
                    job.result = Value (typeof (Object));
                    job.result.take_object (installed);
                    job.results_ready ();
                    return;
                }

                unowned Pk.Package pk_package = packages[i];
                installed.add (pk_package);
            }

        } catch (Error e) {
            critical (e.message);
        }

        job.result = Value (typeof (Object));
        job.result.take_object ((owned) installed);
        job.results_ready ();
    }

    public async Gee.TreeSet<Pk.Package> get_installed_packages (Cancellable? cancellable = null) {
        var job_args = new GetInstalledPackagesArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.GET_INSTALLED_PACKAGES, job_args);
        return (Gee.TreeSet<Pk.Package>)job.result.get_object ();
    }

    private void get_download_size_internal (Job job) {
        unowned var args = (GetDownloadSizeArgs)job.args;
        unowned var package = args.package;
        unowned var cancellable = args.cancellable;

        Pk.Package pk_package;
        try {
            pk_package = get_package_internal (package);
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        uint64 size = 0;

        string[] package_array = { pk_package.package_id, null };
        var filters = Pk.Bitfield.from_enums (Pk.Filter.NOT_INSTALLED, Pk.Filter.ARCH, Pk.Filter.NEWEST);
        try {
            var deps_result = client.depends_on (filters, package_array, true, cancellable, (p, t) => {});
            package_array = { pk_package.package_id };
            deps_result.get_package_array ().foreach ((dep_package) => {
                package_array += dep_package.package_id;
            });

            package_array += null;

            Pk.Results details;
            try {
                details = client.get_details (package_array, cancellable, (p, t) => {});
            } catch (Error e) {
                job.error = e;
                job.results_ready ();
                return;
            }

            details.get_details_array ().foreach ((detail) => {
                size += detail.size;
            });
        } catch (Error e) {
            warning ("Error fetching dependencies for %s: %s", pk_package.package_id, e.message);
        }

        job.result = Value (typeof (uint64));
        job.result.set_uint64 (size);
        job.results_ready ();
    }

    public async uint64 get_download_size (Package package, Cancellable? cancellable, bool is_update = false) throws GLib.Error {
        var job_args = new GetDownloadSizeArgs ();
        job_args.package = package;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.GET_DOWNLOAD_SIZE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_uint64 ();
    }

    private void install_package_internal (Job job) {
        unowned var args = (InstallPackageArgs)job.args;
        unowned var package = args.package;
        unowned ChangeInformation? change_info = args.change_info;
        unowned var cancellable = args.cancellable;

        reset_progress ();

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = package.component.get_pkgnames ();
        packages_ids += null;

        try {
            var results = client.resolve (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.ARCH), packages_ids, cancellable, () => {});

            /*
             * If there were no packages found for the requested architecture,
             * try to resolve IDs by not searching for this architecture
             * e.g: filtering 32 bit only package on a 64 bit system
             */
            GenericArray<weak Pk.Package> package_array = results.get_package_array ();
            if (package_array.length == 0) {
                results = client.resolve (Pk.Bitfield.from_enums (Pk.Filter.NEWEST, Pk.Filter.NOT_ARCH), packages_ids, cancellable, () => {});
                package_array = results.get_package_array ();
            }

            packages_ids = {};
            package_array.foreach ((package) => {
                packages_ids += package.package_id;
            });

            packages_ids += null;

            results = client.install_packages_sync (packages_ids, cancellable, (progress, status) => {
                update_progress_status (progress, status);
                change_info.callback (can_cancel, Utils.pk_status_to_string (this.status), this.progress, pk_status_to_appcenter_status (this.status));
            });

            exit_status = results.get_exit_code ();
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool install_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        var job_args = new InstallPackageArgs ();
        job_args.package = package;
        job_args.change_info = change_info;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.INSTALL_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private void update_package_internal (Job job) {
        unowned var args = (UpdatePackageArgs)job.args;
        unowned var package = args.package;
        unowned var cancellable = args.cancellable;
        unowned ChangeInformation? change_info = args.change_info;

        reset_progress ();

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = package.change_information.updatable_packages[this].to_array ();

        if (packages_ids.length == 0) {
            job.result = true;
            job.results_ready ();
            return;
        }

        packages_ids += null;

        try {
            var results = client.update_packages_sync (packages_ids, cancellable, (progress, status) => {
                update_progress_status (progress, status);
                change_info.callback (can_cancel, Utils.pk_status_to_string (this.status), this.progress, pk_status_to_appcenter_status (this.status));
            });

            exit_status = results.get_exit_code ();
            if (exit_status == Pk.Exit.SUCCESS) {
                Pk.offline_trigger (Pk.OfflineAction.REBOOT, cancellable);
            }
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        var job_args = new UpdatePackageArgs ();
        job_args.package = package;
        job_args.change_info = change_info;
        job_args.cancellable = cancellable;

        if (update_permission == null) {
            try {
                update_permission = yield new Polkit.Permission (
                    "io.elementary.appcenter.update",
                    new Polkit.UnixProcess (Posix.getpid ())
                );
            } catch (Error e) {
                warning ("Can't get permission to update without prompting for admin: %s", e.message);
            }
        }

        var job = yield launch_job (Job.Type.UPDATE_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private void remove_package_internal (Job job) {
        unowned var args = (RemovePackageArgs)job.args;
        unowned var package = args.package;
        unowned var cancellable = args.cancellable;
        unowned ChangeInformation? change_info = args.change_info;

        reset_progress ();

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = package.component.get_pkgnames ();
        packages_ids += null;

        try {
            var results = client.resolve (Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST), packages_ids, cancellable, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });

            results = client.remove_packages_sync (packages_ids, true, true, cancellable, (progress, status) => {
                update_progress_status (progress, status);
                change_info.callback (can_cancel, Utils.pk_status_to_string (this.status), this.progress, pk_status_to_appcenter_status (this.status));
            });

            exit_status = results.get_exit_code ();
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool remove_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        var job_args = new RemovePackageArgs ();
        job_args.package = package;
        job_args.change_info = change_info;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.REMOVE_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private Gee.ArrayList<string> get_downloaded_updates () {
        var downloaded_updates = new Gee.ArrayList<string> ();

        // A PackageKit update query with Filters set to Pk.Filter.DOWNLOADED and Pk.Filter.NOT_INSTALLED
        // returns all downloaded but not installed packages even if they are not prepared for an update.
        // So instead we read the prepared updates from the configuration file which would also be read
        // by the PackageKit daemon on boot.
        const string PK_PREPARED_IDS_PATH = "/var/lib/PackageKit/prepared-update";

        if (!FileUtils.test (PK_PREPARED_IDS_PATH, FileTest.IS_REGULAR)) {
            return downloaded_updates;
        }

        var key_file = new KeyFile ();
        try {
            key_file.load_from_file (PK_PREPARED_IDS_PATH, KeyFileFlags.NONE);
            var prepared_ids = key_file.get_string ("update", "prepared_ids").split (",");
            downloaded_updates = new Gee.ArrayList<string>.wrap (prepared_ids);
        } catch (Error e) {
            warning ("Unable to read PackageKit prepared ids: %s", e.message);
        }

        return downloaded_updates;
    }

    public bool is_restart_required () {
        const string PK_OFFLINE_UPDATE_ACTION_PATH = "/var/lib/PackageKit/offline-update-action";

        if (!FileUtils.test (PK_OFFLINE_UPDATE_ACTION_PATH, FileTest.IS_REGULAR)) {
            return false;
        }

        var pk_offline_update_action = File.new_for_path (PK_OFFLINE_UPDATE_ACTION_PATH);
        try {
            var @is = pk_offline_update_action.read ();
            var dis = new DataInputStream (@is);

            if ("reboot" in dis.read_line ()) {
                return true;
            }
        } catch (Error e) {
            critical ("Couldn't read PackageKit offline update action: %s", e.message);
        }

        return false;
    }

    private void get_updates_internal (Job job) {
        var args = (GetUpdatesArgs)job.args;
        var cancellable = args.cancellable;

        Pk.Results? results = null;
        try {
            results = client.get_updates (0, cancellable, (t, p) => { });

            if (fake_packages.length > 0) {
                foreach (unowned string name in fake_packages) {
                    var package = new Pk.Package ();
                    if (package.set_id (FAKE_PACKAGE_ID.printf (name))) {
                        results.add_package (package);
                    } else {
                        warning ("Could not add a fake package '%s' to the update list".printf (name));
                    }
                }

                fake_packages = {};
            }
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        string[] package_ids = {};
        var downloaded_updates = get_downloaded_updates ();
        results.get_package_array ().foreach ((pk_package) => {
            if (!downloaded_updates.contains (pk_package.get_id ())) {
                package_ids += pk_package.get_id ();
            }
        });

        if (package_ids.length == 0) {
            job.result = Value (typeof (Object));
            job.result.take_object (new Pk.Results ());
            job.results_ready ();
            return;
        }

        package_ids += null;

        Pk.Results details;
        try {
            details = client.get_details (package_ids, cancellable, (p, t) => {});
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        details.get_details_array ().foreach ((details) => {
            results.add_details (details);
        });

        job.result = Value (typeof (Object));
        job.result.take_object ((owned) results);
        job.results_ready ();
    }

    public async Pk.Results get_updates (Cancellable? cancellable) throws GLib.Error {
        var job_args = new GetUpdatesArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.GET_UPDATES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Results)job.result.get_object ();
    }

    private void refresh_cache_internal (Job job) {
        unowned var args = (RefreshCacheArgs)job.args;
        unowned var cancellable = args.cancellable;

        // Don't refresh cache if PackageKit prepared updates.
        // Otherwise PackageKit deletes all information related to prepared updates
        if (get_downloaded_updates ().size > 0) {
            job.result = Value (typeof (bool));
            job.result.set_boolean (true);
            job.results_ready ();
            return;
        }

        Pk.Results? results = null;
        try {
            results = client.refresh_cache (false, cancellable, (t, p) => { });
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        var exit_status = results.get_exit_code ();
        if (exit_status == Pk.Exit.SUCCESS) {
            reload_appstream_pool ();
            BackendAggregator.get_default ().cache_flush_needed ();
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool refresh_cache (Cancellable? cancellable) throws GLib.Error {
        var job_args = new RefreshCacheArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.REFRESH_CACHE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private void is_package_installed_internal (Job job) {
        var args = (IsPackageInstalledArgs)job.args;
        unowned var package = args.package;

        Pk.Package pk_package;
        try {
            pk_package = get_package_internal (package);
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        job.result = Value (typeof (bool));
        job.result = pk_package.info == Pk.Info.INSTALLED;
        job.results_ready ();
    }

    public async bool is_package_installed (Package package) throws GLib.Error {
        var job_args = new IsPackageInstalledArgs ();
        job_args.package = package;

        var job = yield launch_job (Job.Type.IS_PACKAGE_INSTALLED, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private Pk.Package get_package_internal (Package package) throws GLib.Error {
        if (package.component == null || package.component.get_pkgnames ().length < 1) {
            throw new PackageKitBackendError.PACKAGE_NOT_FOUND ("Package not found");
        }

        var name = package.component.get_pkgnames ()[0];

        Pk.Package? pk_package = null;
        var filter = Pk.Bitfield.from_enums (Pk.Filter.NEWEST);
        try {
            var results = client.resolve_sync (filter, { name, null }, null, () => {});
            var array = results.get_package_array ();
            if (array.length > 0) {
                pk_package = array.get (0);
            }
        } catch (Error e) {
            throw e;
        }

        if (pk_package != null) {
            try {
                Pk.Results details = client.get_details_sync ({ pk_package.package_id, null }, null, (t, p) => {});
                details.get_details_array ().foreach ((details) => {
                    pk_package.license = details.license;
                    pk_package.description = details.description;
                    pk_package.summary = details.summary;
                    pk_package.group = details.group;
                    pk_package.size = details.size;
                    pk_package.url = details.url;
                });
            } catch (Error e) {
                warning ("Unable to get details for package %s: %s", pk_package.package_id, e.message);
            }
        }

        if (pk_package == null) {
            throw new PackageKitBackendError.PACKAGE_NOT_FOUND ("Package not found");
        }

        return pk_package;
    }

    public async void update_multiple_package_state (Gee.Collection<Package> packages) throws GLib.Error {
        string[] query = {};
        foreach (var app in packages) {
            if (app.backend == this) {
                query += app.component.get_pkgnames ()[0];
            }
        }

        if (query.length < 1) {
            return;
        }

        query += null;

        var filter = Pk.Bitfield.from_enums (Pk.Filter.NONE);

        try {
            var results = yield client.search_names_async (filter, query, null, () => {});
            var array = results.get_package_array ();
            array.foreach ((pk_package) => {
                populate_basic_package_details (pk_package);
            });
        } catch (Error e) {
            throw e;
        }
    }

    private Package? populate_basic_package_details (Pk.Package pk_package) {
        var package = package_list[pk_package.get_name ()];
        if (package == null) {
            return null;
        }

        // The version, name and summary are required in the installed list view, cache these values
        // here where necessary to avoid looking up each package individually later
        package.latest_version = pk_package.get_version ();

        // If there is no AppStream name for the component, use the debian package name instead
        if (unlikely (package.component.get_name () == null)) {
            package.set_name (pk_package.get_name ());
        }

        if (package.component.get_summary () == null) {
            package.set_summary (pk_package.get_summary ());
        }

        if (pk_package.info == Pk.Info.INSTALLED) {
            package.mark_installed ();
        }

        return package;
    }

    private void get_package_details_internal (Job job) {
        unowned var args = (GetPackageDetailsArgs)job.args;
        unowned var package = args.package;

        Pk.Package pk_package;
        try {
            pk_package = get_package_internal (package);
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        var result = new PackageDetails ();
        result.name = pk_package.get_name ();
        result.description = pk_package.description;
        result.summary = pk_package.summary;
        result.version = pk_package.get_version ();

        job.result = Value (typeof (Object));
        job.result.take_object ((owned) result);
        job.results_ready ();
    }

    public async PackageDetails get_package_details (Package package) throws GLib.Error {
        var job_args = new GetPackageDetailsArgs ();
        job_args.package = package;

        var job = yield launch_job (Job.Type.GET_PACKAGE_DETAILS, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (PackageDetails)job.result.get_object ();
    }

    private void get_package_dependencies_internal (Job job) {
        unowned var args = (GetPackageDependenciesArgs)job.args;
        unowned var package = args.package;
        unowned var cancellable = args.cancellable;

        Pk.Package pk_package;
        try {
            pk_package = get_package_internal (package);
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        string[] package_array = { pk_package.package_id, null };
        var filters = Pk.Bitfield.from_enums (Pk.Filter.ARCH, Pk.Filter.NEWEST);
        try {
            var deps_result = client.depends_on (filters, package_array, true, cancellable, (p, t) => {});
            package_array = {};
            deps_result.get_package_array ().foreach ((dep_package) => {
                package_array += dep_package.get_name ();
            });
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        var result = new Gee.ArrayList<string>.wrap (package_array);

        job.result = Value (typeof (Object));
        job.result.take_object ((owned) result);
        job.results_ready ();
    }

    public async Gee.ArrayList<string> get_package_dependencies (Package package, Cancellable? cancellable) throws GLib.Error {
        var job_args = new GetPackageDependenciesArgs () {
            package = package,
            cancellable = cancellable
        };

        var job = yield launch_job (Job.Type.GET_PACKAGE_DEPENDENCIES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Gee.ArrayList<string>)job.result.get_object ();
    }

    private void update_progress_status (Pk.Progress progress, Pk.ProgressType type) {
        switch (type) {
            case Pk.ProgressType.ALLOW_CANCEL:
                can_cancel = progress.allow_cancel;
                break;
            case Pk.ProgressType.ITEM_PROGRESS:
                if (current_status == Pk.Status.SETUP) {
                    current_status = (Pk.Status) progress.status;
                    /* skipping package download, we have cached packages */
                    if (current_status != Pk.Status.DOWNLOAD) {
                        progress_denom = 100.0f;
                    }
                }
                /* transaction changed so progress count is starting over */
                else if ((Pk.Status) progress.status != current_status) {
                    current_status = (Pk.Status) progress.status;
                    current_progress = last_progress;
                }

                last_progress = progress.percentage;
                double progress_sum = current_progress + last_progress;
                this.progress = progress_sum / progress_denom;
                break;
            case Pk.ProgressType.STATUS:
                status = (Pk.Status) progress.status;
                break;

            case Pk.ProgressType.CALLER_ACTIVE:
            case Pk.ProgressType.DOWNLOAD_SIZE_REMAINING:
            case Pk.ProgressType.ELAPSED_TIME:
            case Pk.ProgressType.INVALID:
            case Pk.ProgressType.PACKAGE:
            case Pk.ProgressType.PACKAGE_ID:
            case Pk.ProgressType.PERCENTAGE:
            case Pk.ProgressType.REMAINING_TIME:
            case Pk.ProgressType.ROLE:
            case Pk.ProgressType.SPEED:
            case Pk.ProgressType.TRANSACTION_FLAGS:
            case Pk.ProgressType.TRANSACTION_ID:
            case Pk.ProgressType.UID:
                // All other ProgressTypes deliberately ignored
                break;
        }
    }

    private static ChangeInformation.Status pk_status_to_appcenter_status (Pk.Status status) {
        switch (status) {
            case Pk.Status.WAIT:
            case Pk.Status.WAITING_FOR_AUTH:
                return ChangeInformation.Status.WAITING;
            case Pk.Status.CANCEL:
                return ChangeInformation.Status.CANCELLED;
            case Pk.Status.FINISHED:
                return ChangeInformation.Status.FINISHED;
            default:
                return ChangeInformation.Status.RUNNING;
        }
    }

    private void reset_progress () {
        can_cancel = true;
        current_progress = 0;
        last_progress = 0;
        current_status = Pk.Status.SETUP;
        status = Pk.Status.SETUP;
        progress_denom = 200.0f;
        progress = 0.0f;
    }

    public async bool repair (Cancellable? cancellable = null) {
        return true;
    }

    private static GLib.Once<PackageKitBackend> instance;
    public static unowned PackageKitBackend get_default () {
        return instance.once (() => { return new PackageKitBackend (); });
    }
}
