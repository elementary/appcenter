/*
 * Copyright 2019–2021 elementary, Inc. (https://elementary.io)
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

public class AppCenterCore.FlatpakPackage : Package {
    public weak Flatpak.Installation installation { public get; construct; }

    public FlatpakPackage (Flatpak.Installation installation, Backend backend, AppStream.Component component) {
        Object (
            installation: installation,
            backend: backend,
            component: component
        );
    }
}

public class AppCenterCore.FlatpakBackend : Backend, Object {
    // AppStream data has to be 1 hour old before it's refreshed
    public const uint MAX_APPSTREAM_AGE = 3600;

    private AsyncQueue<Job> jobs = new AsyncQueue<Job> ();
    private Thread<bool> worker_thread;

    private Gee.HashMap<string, Package> package_list;
    private AppStream.Pool user_appstream_pool;
    private AppStream.Pool system_appstream_pool;

    // This is OK as we're only using a single thread
    // This would have to be done differently if there were multiple workers in the pool
    private bool thread_should_run = true;

    public bool working { public get; protected set; }

    private string user_metadata_path;
    private string system_metadata_path;

    public static Flatpak.Installation? user_installation { get; private set; }
    public static Flatpak.Installation? system_installation { get; private set; }

    private static GLib.FileMonitor user_installation_changed_monitor;
    private static GLib.FileMonitor system_installation_changed_monitor;

    private uint total_operations;
    private int current_operation;

    private bool worker_func () {
        while (thread_should_run) {
            var job = jobs.pop ();
            working = true;
            switch (job.operation) {
                case Job.Type.REFRESH_CACHE:
                    refresh_cache_internal (job);
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
                default:
                    assert_not_reached ();
            }

            working = false;
        }

        return true;
    }

    construct {
        worker_thread = new Thread<bool> ("flatpak-worker", worker_func);
        user_appstream_pool = new AppStream.Pool ();
#if HAS_APPSTREAM_0_15
        user_appstream_pool.set_flags (AppStream.PoolFlags.LOAD_OS_COLLECTION);
#else
        user_appstream_pool.set_flags (AppStream.PoolFlags.READ_COLLECTION);
#endif
        user_appstream_pool.set_cache_flags (AppStream.CacheFlags.NONE);

        system_appstream_pool = new AppStream.Pool ();
#if HAS_APPSTREAM_0_15
        system_appstream_pool.set_flags (AppStream.PoolFlags.LOAD_OS_COLLECTION);
#else
        system_appstream_pool.set_flags (AppStream.PoolFlags.READ_COLLECTION);
#endif
        system_appstream_pool.set_cache_flags (AppStream.CacheFlags.NONE);
        package_list = new Gee.HashMap<string, Package> (null, null);

        // Monitor the FlatpakInstallation for changes (e.g. adding/removing remotes)
        if (user_installation != null) {
            try {
                user_installation_changed_monitor = user_installation.create_monitor ();
            } catch (Error e) {
                warning ("Couldn't user create Installation File Monitor : %s", e.message);
            }

            user_installation_changed_monitor.changed.connect (() => {
                if (!working) {
                    debug ("Flatpak user installation changed.");

                    // Clear the installed state of all packages as something may have changed we weren't
                    // aware of
                    foreach (var package in package_list.values) {
                        if (package.state != Package.State.NOT_INSTALLED || package.installed) {
                            package.clear_installed ();
                        }
                    }

                    trigger_update_check.begin ();
                }
            });
        } else {
            warning ("Couldn't create user Installation File Monitor due to no installation");
        }

        if (system_installation != null) {
            try {
                system_installation_changed_monitor = system_installation.create_monitor ();
            } catch (Error e) {
                warning ("Couldn't create system Installation File Monitor : %s", e.message);
            }

            system_installation_changed_monitor.changed.connect (() => {
                // Only trigger a cache refresh if we're not doing anything (i.e. its an external change)
                if (!working) {
                    debug ("Flatpak system installation changed.");

                    // Clear the installed state of all packages as something may have changed we weren't
                    // aware of
                    foreach (var package in package_list.values) {
                        if (package.state != Package.State.NOT_INSTALLED || package.installed) {
                            package.clear_installed ();
                        }
                    }

                    // Reloads the appstream data for enabled remotes and checks what applications are
                    // installed/require updates
                    trigger_update_check.begin ();
                }
            });
        } else {
            warning ("Couldn't create system Installation File Monitor due to no installation");
        }

        user_metadata_path = Path.build_filename (
            Environment.get_user_cache_dir (),
            "io.elementary.appcenter",
            "flatpak-metadata",
            "user"
        );

        system_metadata_path = Path.build_filename (
            Environment.get_user_cache_dir (),
            "io.elementary.appcenter",
            "flatpak-metadata",
            "system"
        );

        reload_appstream_pool ();
    }

    private async void trigger_update_check () {
        try {
            yield refresh_cache (null);
        } catch (Error e) {
            warning ("Unable to refresh cache after external change: %s", e.message);
        }

        yield Client.get_default ().refresh_updates ();
    }

    static construct {
        try {
            user_installation = new Flatpak.Installation.user ();
        } catch (Error e) {
            critical ("Unable to get flatpak user installation : %s", e.message);
        }

        try {
            system_installation = new Flatpak.Installation.system ();
        } catch (Error e) {
            warning ("Unable to get flatpak system installation : %s", e.message);
        }
    }

    ~FlatpakBackend () {
        thread_should_run = false;
        worker_thread.join ();
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

    public async Gee.Collection<Package> get_installed_applications (Cancellable? cancellable = null) {
        var installed_apps = new Gee.HashSet<Package> ();

        if (user_installation == null && system_installation == null) {
            critical ("Couldn't get installed apps due to no flatpak installation");
            return installed_apps;
        }

        GLib.GenericArray<weak Flatpak.InstalledRef> installed_refs;
        try {
            installed_refs = user_installation.list_installed_refs ();
            installed_apps.add_all (get_installed_apps_from_refs (false, installed_refs, cancellable));
        } catch (Error e) {
            critical ("Unable to get installed flatpaks: %s", e.message);
            return installed_apps;
        }

        try {
            installed_refs = system_installation.list_installed_refs ();
            installed_apps.add_all (get_installed_apps_from_refs (true, installed_refs, cancellable));
        } catch (Error e) {
            critical ("Unable to get installed flatpaks: %s", e.message);
            return installed_apps;
        }

        return installed_apps;
    }

    private Gee.Collection<Package> get_installed_apps_from_refs (bool system, GLib.GenericArray<weak Flatpak.InstalledRef> installed_refs, Cancellable? cancellable) {
        var installed_apps = new Gee.HashSet<Package> ();

        for (int i = 0; i < installed_refs.length; i++) {
            if (cancellable.is_cancelled ()) {
                break;
            }

            unowned Flatpak.InstalledRef installed_ref = installed_refs[i];

            var bundle_id = generate_package_list_key (system, installed_ref.origin, installed_ref.format_ref ());
            var package = package_list[bundle_id];
            if (package != null) {
                package.mark_installed ();
                package.update_state ();
                installed_apps.add (package);
            }
        }

        return installed_apps;
    }

    public Gee.Collection<Package> get_featured_packages_by_release_date () {
        var apps = new Gee.TreeSet<AppCenterCore.Package> (compare_packages_by_release_date);

        foreach (var package in package_list.values) {
            if (!package.is_explicit && !package.is_plugin) {
#if CURATED
                if (package.is_native) {
                    apps.add (package);
                }
#else
                apps.add (package);
#endif
            }
        }

        return apps;
    }

    private int compare_packages_by_release_date (AppCenterCore.Package a, AppCenterCore.Package b) {
        // Sort packages from user remotes higher
        if (((FlatpakPackage)a).installation != ((FlatpakPackage)b).installation) {
            return ((FlatpakPackage)a).installation == user_installation ? -1 : 1;
        }

        // Then sort by release timestamp
        uint64 a_timestamp = 0;
        uint64 b_timestamp = 0;

        var a_newest_release = a.get_newest_release ();
        if (a_newest_release != null) {
            a_timestamp = a_newest_release.get_timestamp ();
        }

        var b_newest_release = b.get_newest_release ();
        if (b_newest_release != null) {
            b_timestamp = b_newest_release.get_timestamp ();
        }

        var a_datetime = new DateTime.from_unix_utc ((int64) a_timestamp);
        var b_datetime = new DateTime.from_unix_utc ((int64) b_timestamp);

        return b_datetime.compare (a_datetime);
    }

    public Gee.Collection<Package> get_applications_for_category (AppStream.Category category) {
        unowned GLib.GenericArray<AppStream.Component> components = category.get_components ();
        // Clear out any cached components that could be from other backends
        if (components.length != 0) {
            components.remove_range (0, components.length);
        }

        var category_array = new GLib.GenericArray<AppStream.Category> ();
        category_array.add (category);
        AppStream.utils_sort_components_into_categories (user_appstream_pool.get_components (), category_array, false);
        AppStream.utils_sort_components_into_categories (system_appstream_pool.get_components (), category_array, false);
        components = category.get_components ();

        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        components.foreach ((comp) => {
            var packages = get_packages_for_component_id (comp.get_id ());
            apps.add_all (packages);
        });

        return apps;
    }

    public Gee.Collection<Package> search_applications (string query, AppStream.Category? category) {
        var apps = new Gee.TreeSet<AppCenterCore.Package> ();
        var comps = user_appstream_pool.search (query);
        if (category == null) {
            comps.foreach ((comp) => {
                var packages = get_packages_for_component_id (comp.get_id ());
                apps.add_all (packages);
            });
        } else {
            var cat_packages = get_applications_for_category (category);
            comps.foreach ((comp) => {
                var packages = get_packages_for_component_id (comp.get_id ());
                foreach (var package in packages) {
                    if (package in cat_packages) {
                        apps.add (package);
                    }
                }
            });
        }

        comps = system_appstream_pool.search (query);
        if (category == null) {
            comps.foreach ((comp) => {
                var packages = get_packages_for_component_id (comp.get_id ());
                apps.add_all (packages);
            });
        } else {
            var cat_packages = get_applications_for_category (category);
            comps.foreach ((comp) => {
                var packages = get_packages_for_component_id (comp.get_id ());
                foreach (var package in packages) {
                    if (package in cat_packages) {
                        apps.add (package);
                    }
                }
            });
        }

        return apps;
    }

    public Gee.Collection<Package> search_applications_mime (string query) {
        return new Gee.ArrayList<Package> ();
    }

    public Package? get_package_for_component_id (string id) {
        var suffixed_id = id + ".desktop";
        foreach (var package in package_list.values) {
            if (package.component.id == id) {
                return package;
            } else if (package.component.id == suffixed_id) {
                return package;
            }
        }

        return null;
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

    public Package? get_package_for_desktop_id (string desktop_id) {
        foreach (var package in package_list.values) {
            if (package.component.id == desktop_id ||
                package.component.id + ".desktop" == desktop_id
            ) {
                return package;
            }
        }

        return null;
    }

    public Gee.Collection<Package> get_packages_by_author (string author, int max) {
        var packages = new Gee.ArrayList<AppCenterCore.Package> ();
        var package_ids = new Gee.ArrayList<string> ();

        foreach (var package in package_list.values) {
            if (packages.size > max) {
                break;
            }

            if (package.component.id in package_ids) {
                continue;
            }

            if (package.component.developer_name == author) {
                package_ids.add (package.component.id);

                AppCenterCore.Package? user_package = null;
                foreach (var origin_package in package.origin_packages) {
                    if (((FlatpakPackage) origin_package).installation == user_installation) {
                        user_package = origin_package;
                        break;
                    }
                }

                if (user_package != null) {
                    packages.add (user_package);
                } else {
                    packages.add (package);
                }
            }
        }

        return packages;
    }

    public async uint64 get_download_size (Package package, Cancellable? cancellable, bool is_update = false) throws GLib.Error {
        var bundle = package.component.get_bundle (AppStream.BundleKind.FLATPAK);
        if (bundle == null) {
            return 0;
        }

        unowned var fp_package = package as FlatpakPackage;
        if (fp_package == null) {
            return 0;
        }

        bool system = fp_package.installation == system_installation;

        var id = generate_package_list_key (system, package.component.get_origin (), bundle.get_id ());
        return yield get_download_size_by_id (id, cancellable, is_update);
    }

    public async uint64 get_download_size_by_id (string id, Cancellable? cancellable, bool is_update = false) throws GLib.Error {
        bool system;
        string origin, bundle_id;
        var split_success = get_package_list_key_parts (id, out system, out origin, out bundle_id);
        if (!split_success) {
            return 0;
        }

        unowned Flatpak.Installation? installation = null;
        if (system) {
            installation = system_installation;
        } else {
            installation = user_installation;
        }

        if (installation == null) {
            return 0;
        }

        var flatpak_ref = Flatpak.Ref.parse (bundle_id);
        bool is_app = flatpak_ref.kind == Flatpak.RefKind.APP;

        uint64 download_size = 0;

        var added_remotes = new Gee.ArrayList<string> ();

        try {
            var transaction = new Flatpak.Transaction.for_installation (installation, cancellable);
            transaction.add_default_dependency_sources ();
            if (is_update) {
                transaction.add_update (bundle_id, null, null);
            } else {
                transaction.add_install (origin, bundle_id, null);
            }

            transaction.add_new_remote.connect ((reason, from_id, remote_name, url) => {
                if (reason == Flatpak.TransactionRemoteReason.RUNTIME_DEPS) {
                    added_remotes.add (url);
                    return true;
                }

                return false;
            });

            transaction.ready.connect (() => {
                var operations = transaction.get_operations ();
                operations.foreach ((entry) => {

                    Flatpak.Ref entry_ref;
                    try {
                        entry_ref = Flatpak.Ref.parse (entry.get_ref ());
                    } catch (Error e) {
                        return;
                    }

                    // Don't include runtime deps in download size for apps we're updating
                    // as this is counted in the OS Updates package
                    var entry_is_runtime_dep = entry_ref.kind == Flatpak.RefKind.RUNTIME;
                    if (is_update && is_app && entry_is_runtime_dep) {
                        return;
                    }

                    download_size += entry.get_download_size ();
                });

                // Do not allow the install to start, this is a dry run
                return false;
            });

            transaction.run (cancellable);

            // Cleanup any remotes we had to add while testing the transaction
            installation.list_remotes ().foreach ((remote) => {
                if (remote.get_url () in added_remotes) {
                    try {
                        installation.remove_remote (remote.get_name ());
                    } catch (Error e) {
                        warning ("Error while removing dry run remote: %s", e.message);
                    }
                }
            });
        } catch (Error e) {
            if (!(e is Flatpak.Error.ABORTED)) {
                throw e;
            }
        }

        return download_size;
    }

    public async bool is_package_installed (Package package) throws GLib.Error {
        unowned var fp_package = package as FlatpakPackage;
        if (fp_package == null || fp_package.installation == null) {
            critical ("Could not check installed state of package due to no flatpak installation");
            return false;
        }

        unowned var bundle = package.component.get_bundle (AppStream.BundleKind.FLATPAK);
        if (bundle == null) {
            return false;
        }

        bool system = fp_package.installation == system_installation;

        var key = generate_package_list_key (system, package.component.get_origin (), bundle.get_id ());

        var installed_refs = fp_package.installation.list_installed_refs ();
        for (int j = 0; j < installed_refs.length; j++) {
            unowned Flatpak.InstalledRef installed_ref = installed_refs[j];

            var bundle_id = generate_package_list_key (system, installed_ref.origin, installed_ref.format_ref ());
            if (key == bundle_id) {
                return true;
            }
        }

        return false;
    }

    public async PackageDetails get_package_details (Package package) throws GLib.Error {
        var details = new PackageDetails ();
        details.name = package.component.get_name ();
        details.description = package.component.get_description ();
        details.summary = package.component.get_summary ();

        var newest_version = package.get_newest_release ();
        if (newest_version != null) {
            details.version = newest_version.get_version ();
        }

        return details;
    }

    private void refresh_cache_internal (Job job) {
        unowned var args = (RefreshCacheArgs)job.args;
        unowned var cancellable = args.cancellable;

        if (user_installation == null && system_installation == null) {
            critical ("Error refreshing flatpak cache due to no installation");
            return;
        }

        GLib.GenericArray<weak Flatpak.Remote> remotes = null;

        if (user_installation != null) {
            try {
                user_installation.drop_caches ();
                remotes = user_installation.list_remotes ();
                preprocess_metadata (false, remotes, cancellable);
            } catch (Error e) {
                critical ("Error getting user flatpak remotes: %s", e.message);
            }
        }

        if (system_installation != null) {
            try {
                system_installation.drop_caches ();
                remotes = system_installation.list_remotes ();
                preprocess_metadata (true, remotes, cancellable);
            } catch (Error e) {
                warning ("Error getting system flatpak remotes: %s", e.message);
            }
        }

        reload_appstream_pool ();
        BackendAggregator.get_default ().cache_flush_needed ();

        job.result = Value (typeof (bool));
        job.result.set_boolean (true);
        job.results_ready ();
    }

    private void preprocess_metadata (bool system, GLib.GenericArray<weak Flatpak.Remote> remotes, Cancellable? cancellable) {
        unowned Flatpak.Installation installation;

        unowned string dest_path;
        if (system) {
            dest_path = system_metadata_path;
            installation = system_installation;
        } else {
            dest_path = user_metadata_path;
            installation = user_installation;
        }

        if (installation == null) {
            return;
        }

        var dest_folder = File.new_for_path (dest_path);
        if (!dest_folder.query_exists ()) {
            try {
                dest_folder.make_directory_with_parents ();
            } catch (Error e) {
                critical ("Error while creating flatpak metadata dir: %s", e.message);
                return;
            }
        }

        delete_folder_contents (dest_folder);

        for (int i = 0; i < remotes.length; i++) {
            unowned Flatpak.Remote remote = remotes[i];

            bool cache_refresh_needed = false;

            unowned string origin_name = remote.get_name ();
            debug ("Found remote: %s", origin_name);

            if (remote.get_disabled ()) {
                debug ("%s is disabled, skipping.", origin_name);
                continue;
            }

            var timestamp_file = remote.get_appstream_timestamp (null);
            if (!timestamp_file.query_exists ()) {
                cache_refresh_needed = true;
            } else {
                var age = Utils.get_file_age (timestamp_file);
                debug ("Appstream age: %u", age);
                if (age > MAX_APPSTREAM_AGE) {
                    cache_refresh_needed = true;
                }
            }

            if (cache_refresh_needed) {
                debug ("Updating remote");
                bool success = false;
                try {
                    success = installation.update_remote_sync (remote.get_name ());
                } catch (Error e) {
                    warning ("Unable to update remote: %s", e.message);
                }
                debug ("Remote updated: %s", success.to_string ());

                debug ("Updating appstream data");
                success = false;
                try {
                    success = installation.update_appstream_sync (remote.get_name (), null, null, cancellable);
                } catch (Error e) {
                    warning ("Unable to update appstream: %s", e.message);
                }

                debug ("Appstream updated: %s", success.to_string ());
            }

            var metadata_location = remote.get_appstream_dir (null).get_path ();
            var metadata_folder_file = File.new_for_path (metadata_location);

            var metadata_path = Path.build_filename (metadata_location, "appstream.xml.gz");
            var metadata_file = File.new_for_path (metadata_path);

            if (metadata_file.query_exists ()) {
                var dest_file = dest_folder.get_child (origin_name + ".xml.gz");

                perform_xml_fixups (origin_name, metadata_file, dest_file);

                var local_icons_path = dest_folder.get_child ("icons");
                if (!local_icons_path.query_exists ()) {
                    try {
                        local_icons_path.make_directory ();
                    } catch (Error e) {
                        warning ("Error creating flatpak icons structure, icons may not display: %s", e.message);
                        continue;
                    }
                }

                var remote_icons_folder = metadata_folder_file.get_child ("icons");
                if (!remote_icons_folder.query_exists ()) {
                    continue;
                }

                if (remote_icons_folder.get_child (origin_name).query_exists ()) {
                    local_icons_path = local_icons_path.get_child (origin_name);
                    try {
                        local_icons_path.make_symbolic_link (remote_icons_folder.get_child (origin_name).get_path ());
                    } catch (Error e) {
                        warning ("Error creating flatpak icons structure, icons may not display: %s", e.message);
                        continue;
                    }
                } else {
                    local_icons_path = local_icons_path.get_child (origin_name);
                    try {
                        local_icons_path.make_symbolic_link (remote_icons_folder.get_path ());
                    } catch (Error e) {
                        warning ("Error creating flatpak icons structure, icons may not display: %s", e.message);
                        continue;
                    }
                }
            } else {
                continue;
            }
        }
    }

    private void reload_appstream_pool () {
        var new_package_list = new Gee.HashMap<string, Package> ();

        user_appstream_pool.clear_metadata_locations ();
        user_appstream_pool.add_metadata_location (user_metadata_path);

        try {
            debug ("Loading flatpak user pool");
            user_appstream_pool.load ();
        } catch (Error e) {
            warning ("Errors found in flatpak appdata, some components may be incomplete/missing: %s", e.message);
        } finally {
            var comp_validator = ComponentValidator.get_default ();
            user_appstream_pool.get_components ().foreach ((comp) => {
                if (!comp_validator.validate (comp)) {
                    return;
                }

                var bundle = comp.get_bundle (AppStream.BundleKind.FLATPAK);
                if (bundle != null) {
                    var key = generate_package_list_key (false, comp.get_origin (), bundle.get_id ());
                    var package = package_list[key];
                    if (package != null) {
                        package.replace_component (comp);
                    } else {
                        package = new FlatpakPackage (user_installation, this, comp);
                    }

                    new_package_list[key] = package;
                }
            });
        }

        system_appstream_pool.clear_metadata_locations ();
        system_appstream_pool.add_metadata_location (system_metadata_path);

        try {
            debug ("Loading flatpak system pool");
            system_appstream_pool.load ();
        } catch (Error e) {
            warning ("Errors found in flatpak appdata, some components may be incomplete/missing: %s", e.message);
        } finally {
            var comp_validator = ComponentValidator.get_default ();
            system_appstream_pool.get_components ().foreach ((comp) => {
                if (!comp_validator.validate (comp)) {
                    return;
                }

                var bundle = comp.get_bundle (AppStream.BundleKind.FLATPAK);
                if (bundle != null) {
                    var key = generate_package_list_key (true, comp.get_origin (), bundle.get_id ());
                    var package = package_list[key];
                    if (package != null) {
                        package.replace_component (comp);
                    } else {
                        package = new FlatpakPackage (system_installation, this, comp);
                    }

                    new_package_list[key] = package;
                }
            });
        }

        package_list = new_package_list;
    }

    private string generate_package_list_key (bool system, string origin, string bundle_id) {
        unowned string installation = system ? "system" : "user";
        return "%s/%s/%s".printf (installation, origin, bundle_id);
    }

    public static bool get_package_list_key_parts (string key, out bool? system, out string? origin, out string? bundle_id) {
        system = null;
        origin = null;
        bundle_id = null;

        string[] parts = key.split ("/", 3);
        if (parts.length != 3) {
            return false;
        }

        system = parts[0] == "system";
        origin = parts[1];
        bundle_id = parts[2];

        return true;
    }

    private void delete_folder_contents (File folder, Cancellable? cancellable = null) {
        FileEnumerator enumerator;
        try {
            enumerator = folder.enumerate_children (
                GLib.FileAttribute.STANDARD_NAME + "," + GLib.FileAttribute.STANDARD_TYPE,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                cancellable
            );
        } catch (Error e) {
            warning ("Unable to create enumerator to cleanup flatpak metadata: %s", e.message);
            return;
        }

        FileInfo? info = null;
        try {
            while (!cancellable.is_cancelled () && (info = enumerator.next_file (cancellable)) != null) {
                if (info.get_file_type () != FileType.DIRECTORY) {
                    var child = folder.resolve_relative_path (info.get_name ());
                    debug ("Deleting %s", child.get_path ());
                    child.delete ();
                } else {
                    var child = folder.resolve_relative_path (info.get_name ());
                    delete_folder_contents (child, cancellable);
                    child.delete ();
                }
            }
        } catch (Error e) {
            warning ("Error while cleaning up flatpak metadat directory: %s", e.message);
        }
    }

    private static void perform_xml_fixups (string origin_name, File src_file, File dest_file) {
        var path = src_file.get_path ();
        Xml.Doc* doc = Xml.Parser.parse_file (path);
        if (doc == null) {
            warning ("Appstream XML file %s not found or permissions missing", path);
            return;
        }

        Xml.Node* root = doc->get_root_element ();
        if (root == null) {
            delete doc;
            warning ("The xml file '%s' is empty", path);
            return;
        }

        if (root->name != "components") {
            delete doc;
            warning ("The root node of %s isn't 'components', valid appstream file?", path);
            return;
        }

        Xml.Attr* origin_attr = root->has_prop ("origin");
        if (origin_attr == null) {
            delete doc;
            warning ("The root node of %s doesn't have an origin attribute, valid appstream file?", path);
            return;
        }

        root->set_prop ("origin", origin_name);

        // FIXME: This is a workaround for https://github.com/ximion/appstream/issues/339
        // Remap the <metadata> tag that contains the custom x-appcenter-xxx values to
        // <custom> as expected by the AppStream parser
        Xml.XPath.Context cntx = new Xml.XPath.Context (doc);
        Xml.XPath.Object* res = cntx.eval_expression ("/components/component/metadata");

        if (res != null && res->type == Xml.XPath.ObjectType.NODESET && res->nodesetval != null) {
            for (int i = 0; i < res->nodesetval->length (); i++) {
                Xml.Node* node = res->nodesetval->item (i);
                node->set_name ("custom");
            }
        }

        /* The below sorting is a workaround for the fact that libappstream uses app ID + remote as a unique
         * key for an app, and any subsequent duplicates found in the XML are discarded. So if there's a "stable"
         * branch and a "daily" branch for an application from the same remote, and the daily branch happens to come
         * first in the file, libappstream throws away the AppData for the stable version.
         *
         * See https://github.com/elementary/appcenter/issues/1612 for details
         */
        var sorted_components = new Gee.ArrayList<Xml.Node*> ();
        // Iterate through all components in the appstream XML
        for (Xml.Node* component = root->children; component != null; component = component->next) {
            if (component->name != "component") {
                continue;
            }

            // Find their bundle tag
            for (Xml.Node* iter = component->children; iter != null; iter = iter->next) {
                if (iter->name == "bundle") {
                    string bundle_id = iter->get_content ();
                    // If it's not an app, we don't care about sorting it
                    if (!bundle_id.has_prefix ("app/")) {
                        break;
                    }

                    // If it's a stable branch of an app, put it on top of the array
                    if (bundle_id.has_suffix ("/stable")) {
                        sorted_components.insert (0, component);
                    // Otherwise add it to the end
                    } else {
                        sorted_components.add (component);
                    }

                    break;
                }
            }
        }

        // Unlink all of the components we sorted, so we can re-attach them in their new positions
        // Can't do this during the loop above as it breaks the iterator
        foreach (var component in sorted_components) {
            component->unlink ();
        }

        // Re-attach them in the new order
        foreach (var component in sorted_components) {
            root->add_child (component);
        }

        doc->set_compress_mode (7);
        doc->save_file (dest_file.get_path ());

        delete res;
        delete doc;
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

    private void install_package_internal (Job job) {
        unowned var args = (InstallPackageArgs)job.args;
        unowned var package = args.package;
        unowned var fp_package = package as FlatpakPackage;
        unowned ChangeInformation? change_info = args.change_info;
        unowned var cancellable = args.cancellable;

        var bundle = package.component.get_bundle (AppStream.BundleKind.FLATPAK);
        if (bundle == null) {
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.results_ready ();
            return;
        }

        if (fp_package == null || fp_package.installation == null) {
            critical ("Error getting flatpak installation");
            job.result = false;
            job.results_ready ();
            return;
        }

        Flatpak.Transaction transaction;
        try {
            transaction = new Flatpak.Transaction.for_installation (fp_package.installation, cancellable);
            transaction.add_default_dependency_sources ();
        } catch (Error e) {
            critical ("Error creating transaction for flatpak install: %s", e.message);
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.results_ready ();
            return;
        }

        try {
            transaction.add_install (package.component.get_origin (), bundle.get_id (), null);
        } catch (Error e) {
            critical ("Error setting up transaction for flatpak install: %s", e.message);
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.error = e;
            job.results_ready ();
            return;
        }

        transaction.choose_remote_for_ref.connect ((@ref, runtime_ref, remotes) => {
            if (remotes.length > 0) {
                return 0;
            } else {
                return -1;
            }
        });

        transaction.new_operation.connect ((operation, progress) => {
            current_operation++;

            progress.changed.connect (() => {
                if (cancellable.is_cancelled ()) {
                    return;
                }

                // Calculate the progress contribution of the previous operations not including the current, hence -1
                double existing_progress = (double)(current_operation - 1) / (double)total_operations;
                double this_op_progress = (double)progress.get_progress () / 100.0f / (double)total_operations;
                change_info.callback (true, _("Installing"), existing_progress + this_op_progress, ChangeInformation.Status.RUNNING);
            });
        });

        bool success = false;

        transaction.operation_error.connect ((operation, e, detail) => {
            warning ("Flatpak installation failed: %s (detail: %d)", e.message, detail);
            if (e is GLib.IOError.CANCELLED) {
                change_info.callback (false, _("Cancelling"), 1.0f, ChangeInformation.Status.CANCELLED);
                success = true;
            }

            // Only cancel the transaction if this is fatal
            var should_continue = detail == Flatpak.TransactionErrorDetails.NON_FATAL;
            if (!should_continue) {
                job.error = e;
            }

            return should_continue;
        });

        transaction.ready.connect (() => {
            total_operations = transaction.get_operations ().length ();
            return true;
        });

        current_operation = 0;

        try {
            success = transaction.run (cancellable);
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                change_info.callback (false, _("Cancelling"), 1.0f, ChangeInformation.Status.CANCELLED);
                success = true;
            } else {
                success = false;
                // Don't overwrite any previous errors as the first is probably most important
                if (job.error != null) {
                    job.error = e;
                }
            }
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (success);
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

    private void remove_package_internal (Job job) {
        unowned var args = (RemovePackageArgs)job.args;
        unowned var package = args.package;
        unowned var fp_package = package as FlatpakPackage;
        unowned ChangeInformation? change_info = args.change_info;
        unowned var cancellable = args.cancellable;

        unowned var bundle = package.component.get_bundle (AppStream.BundleKind.FLATPAK);
        if (bundle == null) {
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.results_ready ();
            return;
        }

        Flatpak.Ref flatpak_ref;
        try {
            flatpak_ref = Flatpak.Ref.parse (bundle.get_id ());
        } catch (Error e) {
            critical ("Error parsing flatpak ref for removal: %s", e.message);
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.results_ready ();
            return;
        }

        if (fp_package == null || fp_package.installation == null) {
            critical ("Error getting flatpak installation for removal");
            job.result = false;
            job.results_ready ();
            return;
        }

        Flatpak.Transaction transaction;
        try {
            transaction = new Flatpak.Transaction.for_installation (fp_package.installation, cancellable);
            transaction.add_default_dependency_sources ();
        } catch (Error e) {
            critical ("Error creating transaction for flatpak removal: %s", e.message);
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.results_ready ();
            return;
        }

        try {
            transaction.add_uninstall (bundle.get_id ());
        } catch (Error e) {
            critical ("Error setting up transaction for flatpak removal: %s", e.message);
            job.result = Value (typeof (bool));
            job.result.set_boolean (false);
            job.error = e;
            job.results_ready ();
            return;
        }

        transaction.set_no_pull (true);

        transaction.new_operation.connect ((operation, progress) => {
            current_operation++;

            progress.changed.connect (() => {
                if (cancellable.is_cancelled ()) {
                    return;
                }

                // Calculate the progress contribution of the previous operations not including the current, hence -1
                double existing_progress = (double)(current_operation - 1) / (double)total_operations;
                double this_op_progress = (double)progress.get_progress () / 100.0f / (double)total_operations;
                change_info.callback (true, _("Uninstalling"), existing_progress + this_op_progress, ChangeInformation.Status.RUNNING);
            });
        });

        bool success = false;

        transaction.operation_error.connect ((operation, e, detail) => {
            warning ("Flatpak removal failed: %s (detail: %d)", e.message, detail);
            if (e is GLib.IOError.CANCELLED) {
                change_info.callback (false, _("Cancelling"), 1.0f, ChangeInformation.Status.CANCELLED);
                success = true;
            }

            // Only cancel the transaction if this is fatal
            var should_continue = detail == Flatpak.TransactionErrorDetails.NON_FATAL;
            if (!should_continue) {
                job.error = e;
            }

            return should_continue;
        });

        transaction.ready.connect (() => {
            total_operations = transaction.get_operations ().length ();
            return true;
        });

        current_operation = 0;

        try {
            success = transaction.run (cancellable);
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                change_info.callback (false, _("Cancelling"), 1.0f, ChangeInformation.Status.CANCELLED);
                success = true;
            } else {
                success = false;
                // Don't overwrite any previous errors as the first is probably most important
                if (job.error != null) {
                    job.error = e;
                }
            }
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (success);
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

    private void update_package_internal (Job job) {
        unowned var args = (UpdatePackageArgs)job.args;
        unowned var package = args.package;
        unowned ChangeInformation change_info = args.change_info;
        unowned var cancellable = args.cancellable;

        if (user_installation == null && system_installation == null) {
            critical ("Error getting flatpak installation");
            job.result = false;
            job.results_ready ();
            return;
        }

        string[] user_updates = {};
        string[] system_updates = {};

        foreach (var updatable in package.change_information.updatable_packages[this]) {
            bool system = false;
            string bundle_id = "";

            var split_success = get_package_list_key_parts (updatable, out system, null, out bundle_id);
            if (!split_success) {
                job.result = Value (typeof (bool));
                job.result.set_boolean (false);
                job.results_ready ();
                return;
            }

            if (system) {
                system_updates += (owned) bundle_id;
            } else {
                user_updates += (owned) bundle_id;
            }
        }

        uint transactions = 0;
        bool run_system = false, run_user = false;
        if (system_updates.length > 0) {
            run_system = true;
            transactions++;
        }

        if (user_updates.length > 0) {
            run_user = true;
            transactions++;
        }

        bool success = true;

        if (run_system) {
            if (!run_updates_transaction (true, system_updates, change_info, cancellable)) {
                success = false;
            }
        }

        if (run_user) {
            if (!run_updates_transaction (false, user_updates, change_info, cancellable)) {
                success = false;
            }
        }

        job.result = Value (typeof (bool));
        job.result.set_boolean (success);
        job.results_ready ();
    }

    private bool run_updates_transaction (bool system, string[] ids, ChangeInformation? change_info, Cancellable? cancellable) {
        Flatpak.Transaction transaction;
        try {
            if (system) {
                transaction = new Flatpak.Transaction.for_installation (system_installation, cancellable);
            } else {
                transaction = new Flatpak.Transaction.for_installation (user_installation, cancellable);
                transaction.add_default_dependency_sources ();
            }
        } catch (Error e) {
            critical ("Error creating transaction for flatpak updates: %s", e.message);
            return false;
        }

        try {
            foreach (unowned string bundle_id in ids) {
                transaction.add_update (bundle_id, null, null);
            }
        } catch (Error e) {
            critical ("Error adding update to flatpak transaction: %s", e.message);
        }

        transaction.choose_remote_for_ref.connect ((@ref, runtime_ref, remotes) => {
            if (remotes.length > 0) {
                return 0;
            } else {
                return -1;
            }
        });

        transaction.new_operation.connect ((operation, progress) => {
            current_operation++;

            progress.changed.connect (() => {
                if (cancellable.is_cancelled ()) {
                    return;
                }

                // Calculate the progress contribution of the previous operations not including the current, hence -1
                double existing_progress = (double)(current_operation - 1) / (double)total_operations;
                double this_op_progress = (double)progress.get_progress () / 100.0f / (double)total_operations;
                change_info.callback (true, _("Updating"), existing_progress + this_op_progress, ChangeInformation.Status.RUNNING);
            });
        });

        bool success = false;

        transaction.operation_error.connect ((operation, e, detail) => {
            warning ("Flatpak installation failed: %s", e.message);
            if (e is GLib.IOError.CANCELLED) {
                change_info.callback (false, _("Cancelling"), 1.0f, ChangeInformation.Status.CANCELLED);
                success = true;
                // The user hit cancel, don't go any further
                return false;
            } else {
                // If there was an error while updating a single package in the transaction, we probably still want
                // the rest updated, continue.
                return true;
            }
        });

        transaction.ready.connect (() => {
            total_operations = transaction.get_operations ().length ();
            return true;
        });

        current_operation = 0;

        try {
            success = transaction.run (cancellable);
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                change_info.callback (false, _("Cancelling"), 1.0f, ChangeInformation.Status.CANCELLED);
                success = true;
            } else {
                success = false;
            }
        }

        return success;
    }

    public async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        var job_args = new UpdatePackageArgs ();
        job_args.package = package;
        job_args.change_info = change_info;
        job_args.cancellable = cancellable;

        var job = yield launch_job (Job.Type.UPDATE_PACKAGE, job_args);
        if (job.error != null) {
            throw job.error;
        }

        return job.result.get_boolean ();
    }

    public async Gee.ArrayList<string> get_updates (Cancellable? cancellable = null) {
        var updatable_ids = new Gee.ArrayList<string> ();

        if (user_installation == null && system_installation == null) {
            critical ("Unable to get flatpak installation when checking for updates");
            return updatable_ids;
        }

        GLib.GenericArray<weak Flatpak.InstalledRef> update_refs;

        if (user_installation != null) {
            try {
                update_refs = user_installation.list_installed_refs_for_update (cancellable);
                for (int i = 0; i < update_refs.length; i++) {
                    unowned Flatpak.InstalledRef updatable_ref = update_refs[i];
                    updatable_ids.add (generate_package_list_key (false, updatable_ref.origin, updatable_ref.format_ref ()));
                }
            } catch (Error e) {
                critical ("Unable to get list of updatable flatpaks: %s", e.message);
                return updatable_ids;
            }
        }

        if (system_installation != null) {
            try {
                update_refs = system_installation.list_installed_refs_for_update (cancellable);

                for (int i = 0; i < update_refs.length; i++) {
                    unowned Flatpak.InstalledRef updatable_ref = update_refs[i];
                    updatable_ids.add (generate_package_list_key (true, updatable_ref.origin, updatable_ref.format_ref ()));
                }
            } catch (Error e) {
                critical ("Unable to get list of updatable flatpaks: %s", e.message);
                return updatable_ids;
            }
        }

        return updatable_ids;
    }

    public Package? lookup_package_by_id (string id) {
        return package_list[id];
    }

    private static GLib.Once<FlatpakBackend> instance;
    public static unowned FlatpakBackend get_default () {
        return instance.once (() => { return new FlatpakBackend (); });
    }
}
