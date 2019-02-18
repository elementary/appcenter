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

public class AppCenterCore.PackageKitClient : Object {
    private static Task client;
    private AsyncQueue<PackageKitJob> jobs = new AsyncQueue<PackageKitJob> ();
    private Thread<bool> worker_thread;

    // This is OK as we're only using a single thread (PackageKit can only do one job at a time)
    // This would have to be done differently if there were multiple workers in the pool
    private bool thread_should_run = true;

    public bool working { get; private set; }

    private bool worker_func () {
        while (thread_should_run) {
            working = false;
            var job = jobs.pop ();
            working = true;
            switch (job.operation) {
                case PackageKitJob.Type.GET_PACKAGE_BY_NAME:
                    get_package_by_name_internal (job);
                    break;
                case PackageKitJob.Type.GET_DETAILS_FOR_PACKAGE_IDS:
                    get_details_for_package_ids_internal (job);
                    break;
                case PackageKitJob.Type.GET_INSTALLED_PACKAGES:
                    get_installed_packages_internal (job);
                    break;
                case PackageKitJob.Type.GET_NOT_INSTALLED_DEPS_FOR_PACKAGE:
                    get_not_installed_deps_for_package_internal (job);
                    break;
                case PackageKitJob.Type.REFRESH_CACHE:
                    refresh_cache_internal (job);
                    break;
                case PackageKitJob.Type.GET_UPDATES:
                    get_updates_internal (job);
                    break;
                case PackageKitJob.Type.INSTALL_PACKAGES:
                    install_packages_internal (job);
                    break;
                case PackageKitJob.Type.UPDATE_PACKAGES:
                    update_packages_internal (job);
                    break;
                case PackageKitJob.Type.REMOVE_PACKAGES:
                    remove_packages_internal (job);
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

    private PackageKitClient () {
        worker_thread = new Thread<bool> ("packagekit-worker", worker_func);
    }

    ~PackageKitClient () {
        thread_should_run = false;
        worker_thread.join ();
    }

    private async PackageKitJob launch_job (PackageKitJob.Type type, JobArgs? args = null) {
        var job = new PackageKitJob (type);
        job.args = args;

        SourceFunc callback = launch_job.callback;
        job.results_ready.connect (() => {
            Idle.add ((owned) callback);
        });

        jobs.push (job);
        yield;
        return job;
    }

    private void get_package_by_name_internal (PackageKitJob job) {
        var args = (GetPackageByNameArgs)job.args;
        unowned string name = args.name;
        var additional_filters = args.additional_filters;

        Pk.Package? package = null;
        var filter = Pk.Bitfield.from_enums (Pk.Filter.NEWEST);
        filter |= additional_filters;
        try {
            var results = client.search_names_sync (filter, { name, null }, null, () => {});
            var array = results.get_package_array ();
            if (array.length > 0) {
                package = array.get (0);
            }
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        if (package != null) {
            try {
                Pk.Results details = client.get_details_sync ({ package.package_id, null }, null, (t, p) => {});
                details.get_details_array ().foreach ((details) => {
                    package.license = details.license;
                    package.description = details.description;
                    package.summary = details.summary;
                    package.group = details.group;
                    package.size = details.size;
                    package.url = details.url;
                });
            } catch (Error e) {
                warning ("Unable to get details for package %s: %s", package.package_id, e.message);
            }
        }

        job.result = Value (typeof (Object));
        job.result.take_object (package);
        job.results_ready ();
    }

    public async Pk.Package? get_package_by_name (string name, Pk.Bitfield additional_filters = 0) throws GLib.Error {
        var job_args = new GetPackageByNameArgs ();
        job_args.name = name;
        job_args.additional_filters = additional_filters;

        var job = yield launch_job (PackageKitJob.Type.GET_PACKAGE_BY_NAME, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Package?)job.result.get_object ();
    }

    private void get_details_for_package_ids_internal (PackageKitJob job) {
        var args = (GetDetailsForPackageIDsArgs)job.args;
        var package_ids = args.package_ids;
        var cancellable = args.cancellable;

        string[] packages_ids = {};

        foreach (var package in package_ids) {
            packages_ids += package;
        }

        packages_ids += null;

        Pk.Results? result = null;
        try {
            result = client.get_details (packages_ids, cancellable, (p, t) => {});
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        job.result = Value (typeof (Object));
        job.result.take_object (result);
        job.results_ready ();
    }

    public async Pk.Results get_details_for_package_ids (Gee.ArrayList<string> package_ids, Cancellable? cancellable) throws GLib.Error {
        var job_args = new GetDetailsForPackageIDsArgs ();
        job_args.package_ids = package_ids;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.GET_DETAILS_FOR_PACKAGE_IDS, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Results)job.result.get_object ();
    }

    private void get_installed_packages_internal (PackageKitJob job) {
        Pk.Bitfield filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
        var installed = new Gee.TreeSet<Pk.Package> ();

        try {
            Pk.Results results = client.get_packages (filter, null, (prog, type) => {});
            results.get_package_array ().foreach ((pk_package) => {
                installed.add (pk_package);
            });

        } catch (Error e) {
            critical (e.message);
        }

        job.result = Value (typeof (Object));
        job.result.take_object (installed);
        job.results_ready ();
    }

    public async Gee.TreeSet<Pk.Package> get_installed_packages () {
        var job = yield launch_job (PackageKitJob.Type.GET_INSTALLED_PACKAGES);
        return (Gee.TreeSet<Pk.Package>)job.result.get_object ();
    }

    private void get_not_installed_deps_for_package_internal (PackageKitJob job) {
        var args = (GetNotInstalledDepsForPackageArgs)job.args;
        var pk_package = args.package;
        var cancellable = args.cancellable;

        var deps = new Gee.ArrayList<Pk.Package> ();

        if (pk_package == null) {
            job.result = Value (typeof (Object));
            job.result.take_object (deps);
            job.results_ready ();
            return;
        }

        string[] package_array = { pk_package.package_id, null };
        var filters = Pk.Bitfield.from_enums (Pk.Filter.NOT_INSTALLED);
        try {
            var deps_result = client.depends_on (filters, package_array, false, cancellable, (p, t) => {});
            deps_result.get_package_array ().foreach ((dep_package) => {
                deps.add (dep_package);
            });

            package_array = {};
            foreach (var dep_package in deps) {
                package_array += dep_package.package_id;
            }

            package_array += null;
            if (package_array.length > 1) {
                deps_result = client.depends_on (filters, package_array, true, cancellable, (p, t) => {});
                deps_result.get_package_array ().foreach ((dep_package) => {
                    deps.add (dep_package);
                });
            }
        } catch (Error e) {
            warning ("Error fetching dependencies for %s: %s", pk_package.package_id, e.message);
        }

        job.result = Value (typeof (Object));
        job.result.take_object (deps);
        job.results_ready ();
    }

    public async Gee.ArrayList<Pk.Package> get_not_installed_deps_for_package (Pk.Package? package, Cancellable? cancellable) {
        if (package == null) {
            return new Gee.ArrayList<Pk.Package> ();
        }

        var job_args = new GetNotInstalledDepsForPackageArgs ();
        job_args.package = package;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.GET_NOT_INSTALLED_DEPS_FOR_PACKAGE, job_args);
        return (Gee.ArrayList<Pk.Package>)job.result.get_object ();
    }

    private void install_packages_internal (PackageKitJob job) {
        var args = (InstallPackagesArgs)job.args;
        var package_ids = args.package_ids;
        unowned Pk.ProgressCallback cb = args.cb;
        var cancellable = args.cancellable;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pkg_name in package_ids) {
            packages_ids += pkg_name;
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

        job.result = Value (typeof(Pk.Exit));
        job.result.set_enum (exit_status);
        job.results_ready ();
    }

    public async Pk.Exit install_packages (Gee.ArrayList<string> package_ids, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new InstallPackagesArgs ();
        job_args.package_ids = package_ids;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.INSTALL_PACKAGES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Exit)job.result.get_enum ();
    }

    private void update_packages_internal (PackageKitJob job) {
        var args = (UpdatePackagesArgs)job.args;
        var package_ids = args.package_ids;
        var cancellable = args.cancellable;
        unowned Pk.ProgressCallback cb = args.cb;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pk_package in package_ids) {
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

        job.result = Value (typeof (Pk.Exit));
        job.result.set_enum (exit_status);
        job.results_ready ();
    }

    public async Pk.Exit update_packages (Gee.ArrayList<string> package_ids, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new UpdatePackagesArgs ();
        job_args.package_ids = package_ids;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.UPDATE_PACKAGES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Exit)job.result.get_enum ();
    }

    private void remove_packages_internal (PackageKitJob job) {
        var args = (RemovePackagesArgs)job.args;
        var package_ids = args.package_ids;
        var cancellable = args.cancellable;
        unowned Pk.ProgressCallback cb = args.cb;

        Pk.Exit exit_status = Pk.Exit.UNKNOWN;
        string[] packages_ids = {};
        foreach (var pkg_name in package_ids) {
            packages_ids += pkg_name;
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

        job.result = Value (typeof (Pk.Exit));
        job.result.set_enum (exit_status);
        job.results_ready ();
    }

    public async Pk.Exit remove_packages (Gee.ArrayList<string> package_ids, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new RemovePackagesArgs ();
        job_args.package_ids = package_ids;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.REMOVE_PACKAGES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Exit)job.result.get_enum ();
    }

    private void get_updates_internal (PackageKitJob job) {
        var args = (GetUpdatesArgs)job.args;
        var cancellable = args.cancellable;

        Pk.Results? results = null;
        try {
            results = client.get_updates (0, cancellable, (t, p) => { });
        } catch (Error e) {
            job.error = e;
            job.results_ready ();
            return;
        }

        job.result = Value (typeof (Object));
        job.result.take_object (results);
        job.results_ready ();
    }

    public async Pk.Results get_updates (Cancellable cancellable) throws GLib.Error {
        var job_args = new GetUpdatesArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.GET_UPDATES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Results)job.result.get_object ();
    }

    private void refresh_cache_internal (PackageKitJob job) {
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

        job.result = Value (typeof (Object));
        job.result.take_object (results);
        job.results_ready ();
    }

    public async Pk.Results refresh_cache (Cancellable cancellable) throws GLib.Error {
        var job_args = new RefreshCacheArgs ();
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.REFRESH_CACHE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (Pk.Results)job.result.get_object ();
    }

    private static GLib.Once<PackageKitClient> instance;
    public static unowned PackageKitClient get_default () {
        return instance.once (() => { return new PackageKitClient (); });
    }
}
