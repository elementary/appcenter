/*-
 * Copyright (c) 2019 elementary LLC. (https://elementary.io)
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

errordomain PackageKitClientError {
    PACKAGE_NOT_FOUND
}

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
                case PackageKitJob.Type.GET_DETAILS_FOR_PACKAGE_IDS:
                    get_details_for_package_ids_internal (job);
                    break;
                case PackageKitJob.Type.GET_INSTALLED_PACKAGES:
                    get_installed_packages_internal (job);
                    break;
                case PackageKitJob.Type.GET_DOWNLOAD_SIZE:
                    get_download_size_internal (job);
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
                case PackageKitJob.Type.IS_PACKAGE_INSTALLED:
                    is_package_installed_internal (job);
                    break;
                case PackageKitJob.Type.GET_PACKAGE_DETAILS:
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

    private void get_download_size_internal (PackageKitJob job) {
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

        var job = yield launch_job (PackageKitJob.Type.GET_DOWNLOAD_SIZE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_uint64 ();
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

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool install_packages (Gee.ArrayList<string> package_ids, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new InstallPackagesArgs ();
        job_args.package_ids = package_ids;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.INSTALL_PACKAGES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
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

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool update_packages (Gee.ArrayList<string> package_ids, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new UpdatePackagesArgs ();
        job_args.package_ids = package_ids;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.UPDATE_PACKAGES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
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

        job.result = Value (typeof (bool));
        job.result.set_boolean (exit_status == Pk.Exit.SUCCESS);
        job.results_ready ();
    }

    public async bool remove_packages (Gee.ArrayList<string> package_ids, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        var job_args = new RemovePackagesArgs ();
        job_args.package_ids = package_ids;
        job_args.cb = (owned)cb;
        job_args.cancellable = cancellable;

        var job = yield launch_job (PackageKitJob.Type.REMOVE_PACKAGES, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
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

    private void is_package_installed_internal (PackageKitJob job) {
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

        var job = yield launch_job (PackageKitJob.Type.IS_PACKAGE_INSTALLED, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    private Pk.Package get_package_internal (Package package) throws GLib.Error {
        if (package.component == null || package.component.get_pkgnames ().length < 1) {
            throw new PackageKitClientError.PACKAGE_NOT_FOUND ("Package not found");
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
            throw new PackageKitClientError.PACKAGE_NOT_FOUND ("Package not found");
        }

        return pk_package;
    }

    private void get_package_details_internal (PackageKitJob job) {
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

        var job = yield launch_job (PackageKitJob.Type.GET_PACKAGE_DETAILS, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return (PackageDetails)job.result.get_object ();
    }

    private static GLib.Once<PackageKitClient> instance;
    public static unowned PackageKitClient get_default () {
        return instance.once (() => { return new PackageKitClient (); });
    }
}
