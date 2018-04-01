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
	public signal void operation_finished (Backend backend, Package package, Package.State operation, Error? error);
    public signal void cache_update_failed (Error error);
    public signal void updates_available ();
    public signal void drivers_detected ();

	public bool restart_required { public get; private set; }
	public bool connected {}
	public uint task_count {}
	public bool updating_cache { public get; private set; default = false; }

    private Gee.HashMap<string, Backend> backends;
    private const string RESTART_REQUIRED_FILE = "/var/run/reboot-required";
    private File restart_file;
    private bool restart_notified;

    construct {
        restart_file = File.new_for_path (RESTART_REQUIRED_FILE);
    }

    public Client () {
        // Load Backends, for now only PackageKit
        backends = new Gee.HashMap<string, Backend> ();
        backends.set(PkBackend.BACKEND_IDENTIFIER, PkBackend.get_default());
        register_backends ();
    }

    private void register_backends () {
        var it = backends.map_iterator ();
        for (var has_next = it.next (); has_next; has_next = it.next ()) {
            var backend = it.get_value ();
            backend.operation_finished.connect (operation_finished);
            backend.cache_update_failed.connect (cache_update_failed);
            backend.updates_available.connect (updates_available);
            backend.drivers_detected.connect (drivers_detected);
        }
    }

	public async Package get_updates (Cancellable? cancellable) throws Error {

    }

	public async Package get_installed (Cancellable? cancellable) throws Error {

    }

	public void update_restart_state () {
        restart_required = restart_file.query_exists ();
        for (var has_next = it.next (); has_next; has_next = it.next ()) {
            var backend = it.get_value ();
            backend.update_restart_state ();
            restart_required |= backend.restart_required
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
