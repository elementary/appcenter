// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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
 * Authored by: Fabian Thoma <fabian@elementary.io>
 */

public class AppCenterCore.Client : Object {
	public signal void operation_finished (Package package, Package.State operation, Error? error);
    public signal void cache_update_failed (Error error);
    public signal void updates_available ();
    public signal void drivers_detected ();

	public bool restart_required { public get; private set; }
	public bool connected {public get; private set; }
	public uint task_count { public get; private set; }
	public bool updating_cache { public get; private set; default = false; }
    public bool has_tasks {
        public get {
            return task_count > 0;
        }
    }

    public uint updates_number;

    private Gee.HashMap<string, Backend> backends;
    private const string RESTART_REQUIRED_FILE = "/var/run/reboot-required";
    private File restart_file;
    private bool restart_notified;

    private const string DEFAULT_BACKEND = "PackageKit";

    construct {
        restart_file = File.new_for_path (RESTART_REQUIRED_FILE);
    }

    public Client () {
        // Load Backends, for now only PackageKit
        backends = new Gee.HashMap<string, Backend> ();
        backends.set(PkBackend.backend_identifier, PkBackend.get_default());
        register_backends ();
    }

    private void register_backends () {
        var it = backends.map_iterator ();
        for (var has_next = it.next (); has_next; has_next = it.next ()) {
            var backend = it.get_value ();
            backend.operation_finished.connect (on_operation_finished);
            backend.cache_update_failed.connect (on_cache_update_failed);
            backend.updates_available.connect (on_updates_available);
            backend.drivers_detected.connect (on_drivers_detected);
        }
    }

    public void on_operation_finished (Backend backend, Package package, Package.State operation, Error? error) {
        operation_finished (package, operation, error);
    }

    public void on_cache_update_failed (Backend backend, Error error) {
        cache_update_failed (error);
    }
    public void on_updates_available (Backend backend) {
        updates_available ();
    }
    public void on_drivers_detected (Backend backend) {
        drivers_detected ();
    }


	public async Gee.Collection<Package> get_updates (Cancellable? cancellable) throws Error {

    }

	public async Gee.Collection<Package> get_installed_applications () throws Error {

    }


    public Gee.Collection<AppCenterCore.Package> search_applications (string query, AppStream.Category? category) {
        //TODO: Implement this ...
        return null;
    }

    public Gee.Collection<Package> get_drivers () {
        var it = backends.map_iterator ();
        for (var has_next = it.next (); has_next; has_next = it.next ()) {
            var backend = it.get_value ();
            backend.get_drivers ();
        }
    }

    public Gee.Collection<Package> get_os_updates () {
        var it = backends.map_iterator ();
        for (var has_next = it.next (); has_next; has_next = it.next ()) {
            var backend = it.get_value ();
            backend.get_os_updates ();
        }
    }

// TODO: Implement in Packages Interface: get_needed_deps_for_package
// TODO: Why does the UI need this? get_pk_client


    public Gee.Collection<AppCenterCore.Package> get_packages_by_author (string author, int max, string backend = "default") {
        if( backend == "default") {
            backend = DEFAULT_BACKEND;
        }
        return backends.get (backend).get_packages_by_author (author, max);
    }


    public Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category, string backend = "default") {
        if( backend == "default") {
            backend = DEFAULT_BACKEND;
        }
        return backends.get (backend).get_applications_for_category (category);
    }



    public AppCenterCore.Package? get_package_for_desktop_id (string desktop_id) {
        //TODO: Implement this ...
        return null;
    }

    public AppCenterCore.Package? get_package_for_component_id (string id) {
        //TODO: Implement this ...
        return null;
    }

    public void cancel_updates (bool cancel_timeout) {
        // TODO Implement this ...
    }

    public async void update_cache (bool force = false) {
        // TODO Implement this ...
    }

	public void update_restart_state () {
        restart_required = restart_file.query_exists ();
        var it = backends.map_iterator ();
        for (var has_next = it.next (); has_next; has_next = it.next ()) {
            var backend = it.get_value ();
            backend.update_restart_state ();
            restart_required |= backend.restart_required;
        }

        if (restart_required & !restart_notified) {
            string title = _("Restart Required");
            string body = _("Please restart your system to finalize updates");
            var notification = new Notification (title);
            notification.set_body (body);
            notification.set_icon (new ThemedIcon ("system-software-install"));
            notification.set_priority (NotificationPriority.URGENT);
            notification.set_default_action ("app.open-application");
            Application.get_default ().send_notification ("restart", notification);
            restart_notified = true;
        }
    }

    private static GLib.Once<Client> instance;
    public static unowned Client get_default () {
        return instance.once (() => { return new Client (); });
    }

}
