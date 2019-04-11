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

    public bool working { get; private set; }

    private bool worker_func () {
        while (thread_should_run) {
            last_action = new DateTime.now_local ();
            working = false;
            var job = jobs.pop ();
            working = true;
            switch (job.operation) {
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
                default:
                    assert_not_reached ();
            }
        }

        return true;
    }

    static construct {
        client = new Task ();
    }

    private PackageKitBackend () {
        worker_thread = new Thread<bool> ("packagekit-worker", worker_func);

        package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);
        appstream_pool = new AppStream.Pool ();
        // We don't want to show installed desktop files here
        appstream_pool.set_flags (appstream_pool.get_flags () & ~AppStream.PoolFlags.READ_DESKTOP_FILES);

        reload_appstream_pool ();

        var control = new Pk.Control ();
        control.updates_changed.connect (updates_changed_callback);
    }

    private void updates_changed_callback () {
        if (!working) {
            UpdateManager.get_default ().update_restart_state ();

            var time_since_last_action = (new DateTime.now_local ()).difference (last_action) / GLib.TimeSpan.MILLISECOND;
            if (time_since_last_action >= PACKAGEKIT_ACTIVITY_TIMEOUT_MS) {
                info ("packages possibly changed by external program, refreshing cache");
                Client.get_default ().update_cache.begin (true);
            }
        }
    }

    ~PackageKitBackend () {
        thread_should_run = false;
        worker_thread.join ();
    }

    private void reload_appstream_pool () {
        package_list.clear ();

        try {
            appstream_pool.load ();
        } catch (Error e) {
            critical (e.message);
        } finally {
            var comp_validator = ComponentValidator.get_default ();
            appstream_pool.get_components ().foreach ((comp) => {
                if (!comp_validator.validate (comp)) {
                    return;
                }

                var package = new AppCenterCore.Package (this, comp);
                foreach (var pkg_name in comp.get_pkgnames ()) {
                    package_list[pkg_name] = package;
                }
            });
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

        var component = metadata.get_component ();
        if (component != null) {
            string name = _("%s (local)").printf (component.get_name ());
            string id = "%s%s".printf (component.get_id (), Package.LOCAL_ID_SUFFIX);

            component.set_name (name, null);
            component.set_id (id);
            component.set_origin (Package.APPCENTER_PACKAGE_ORIGIN);

            appstream_pool.add_component (component);

            var package = new AppCenterCore.Package (this, component);
            package_list[id] = package;

            return package;
        }

        return null;
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications (Cancellable? cancellable = null) {
        var packages = new Gee.TreeSet<AppCenterCore.Package> ();
        var installed = yield get_installed_packages ();
        foreach (var pk_package in installed) {
            if (cancellable.is_cancelled ()) {
                break;
            }

            var package = package_list[pk_package.get_name ()];
            if (package != null) {
                populate_package (package, pk_package);
                packages.add (package);
            }
        }

        return packages;
    }

    private static void populate_package (AppCenterCore.Package package, Pk.Package pk_package) {
        package.mark_installed ();
        package.latest_version = pk_package.get_version ();
        package.update_state ();
    }

    public AppCenterCore.Package? get_package_for_component_id (string id) {
        foreach (var package in package_list.values) {
            if (package.component.id == id) {
                return package;
            } else if (package.component.id == id + ".desktop") {
                return package;
            }
        }

        return null;
    }

    public AppCenterCore.Package? get_package_for_desktop_id (string desktop_id) {
        foreach (var package in package_list.values) {
            if (package.component.id == desktop_id) {
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

    public Gee.Collection<AppCenterCore.Package> search_applications_mime (string query) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        foreach (var package in package_list.values) {
            weak AppStream.Provided? provided = package.component.get_provided_for_kind (AppStream.ProvidedKind.MIMETYPE);
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

    private void get_installed_packages_internal (Job job) {
        var args = (GetInstalledPackagesArgs)job.args;
        var cancellable = args.cancellable;

        Pk.Bitfield filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
        var installed = new Gee.TreeSet<Pk.Package> ();

        try {
            Pk.Results results = client.get_packages (filter, cancellable, (prog, type) => {});
            var packages = results.get_package_array ();

            for (int i = 0; i < packages.length; i++) {
                if (cancellable.is_cancelled ()) {
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
        job.result.take_object (installed);
        job.results_ready ();
    }

    public async Gee.TreeSet<Pk.Package> get_installed_packages (Cancellable? cancellable = null) {
        var job_args = new GetInstalledPackagesArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.GET_INSTALLED_PACKAGES, job_args);
        return (Gee.TreeSet<Pk.Package>)job.result.get_object ();
    }

    private void get_download_size_internal (Job job) {
        var args = (GetDownloadSizeArgs)job.args;
        var package = args.package;
        var cancellable = args.cancellable;

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

    public async uint64 get_download_size (Package package, Cancellable? cancellable) throws GLib.Error {
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
        var args = (InstallPackageArgs)job.args;
        var package = args.package;
        unowned Pk.ProgressCallback cb = args.cb;
        var cancellable = args.cancellable;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        for (int i = 0; i < package.component.get_pkgnames ().length; i++) {
            packages_ids += package.component.get_pkgnames ()[i];
        }

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

            results = client.install_packages_sync (packages_ids, cancellable, cb);
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

    public async bool install_package (Package package, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new InstallPackageArgs ();
        job_args.package = package;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.INSTALL_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private void update_package_internal (Job job) {
        var args = (UpdatePackageArgs)job.args;
        var package = args.package;
        var cancellable = args.cancellable;
        unowned Pk.ProgressCallback cb = args.cb;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pk_package in package.change_information.updatable_ids) {
            packages_ids += pk_package;
        }

        packages_ids += null;

        try {
            var results = client.update_packages_sync (packages_ids, cancellable, cb);
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

    public async bool update_package (Package package, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new UpdatePackageArgs ();
        job_args.package = package;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.UPDATE_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private void remove_package_internal (Job job) {
        var args = (RemovePackageArgs)job.args;
        var package = args.package;
        var cancellable = args.cancellable;
        unowned Pk.ProgressCallback cb = args.cb;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        for (int i = 0; i < package.component.get_pkgnames ().length; i++) {
            packages_ids += package.component.get_pkgnames ()[i];
        }

        packages_ids += null;

        try {
            var results = client.resolve (Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST), packages_ids, cancellable, () => {});
            packages_ids = {};
            results.get_package_array ().foreach ((package) => {
                packages_ids += package.package_id;
            });

            results = client.remove_packages_sync (packages_ids, true, true, cancellable, cb);
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

    public async bool remove_package (Package package, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new RemovePackageArgs ();
        job_args.package = package;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.REMOVE_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private void get_updates_internal (Job job) {
        var args = (GetUpdatesArgs)job.args;
        var cancellable = args.cancellable;

        Pk.Results? results = null;
        try {
            results = client.get_updates (0, cancellable, (t, p) => { });

            if (fake_packages.length > 0) {
                foreach (string name in fake_packages) {
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

        if (results.get_package_array ().length == 0) {
            job.result = Value (typeof (Object));
            job.result.take_object (results);
            job.results_ready ();
            return;
        }

        string[] package_ids = {};
        results.get_package_array ().foreach ((pk_package) => {
            package_ids += pk_package.get_id ();
        });

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
        job.result.take_object (results);
        job.results_ready ();
    }

    public async Pk.Results get_updates (Cancellable cancellable) throws GLib.Error {
        var job_args = new GetUpdatesArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.GET_UPDATES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Results)job.result.get_object ();
    }

    private void refresh_cache_internal (Job job) {
        var args = (RefreshCacheArgs)job.args;
        var cancellable = args.cancellable;

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
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool refresh_cache (Cancellable cancellable) throws GLib.Error {
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
        var package = args.package;

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
            var results = client.search_names_sync (filter, { name, null }, null, () => {});
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

    private void get_package_details_internal (Job job) {
        var args = (GetPackageDetailsArgs)job.args;
        var package = args.package;

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
        job.result.take_object (result);
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

    private static GLib.Once<PackageKitBackend> instance;
    public static unowned PackageKitBackend get_default () {
        return instance.once (() => { return new PackageKitBackend (); });
    }
}
