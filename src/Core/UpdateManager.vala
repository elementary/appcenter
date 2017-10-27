// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class AppCenterCore.UpdateManager : Object {
    public bool restart_required { public get; private set; default = false; }
    public string[] fake_packages { get; set; }

    private const string FAKE_PACKAGE_ID = "%s;fake.version;amd64;installed:xenial-main";
    private const string RESTART_REQUIRED_FILE = "/var/run/reboot-required";

    private File restart_file;

    construct {
        restart_file = File.new_for_path (RESTART_REQUIRED_FILE);
    }

    private UpdateManager () {

    }

    public async Pk.Results get_updates (Cancellable? cancellable) throws Error {
        var client = AppCenterCore.Client.get_pk_client ();

        try {
            Pk.Results update_results = yield client.get_updates_async (0, cancellable, (t, p) => { });

            if (fake_packages.length > 0) {
                foreach (string name in fake_packages) {
                    var package = new Pk.Package ();
                    if (package.set_id (FAKE_PACKAGE_ID.printf (name))) {
                        update_results.add_package (package);
                    } else {
                        warning ("Could not add a fake package '%s' to the update list".printf (name));
                    }
                }

                fake_packages = {};
            }

            string[] packages_array = {};
            update_results.get_package_array ().foreach ((pk_package) => {
                packages_array += pk_package.get_id ();
            });

            if (packages_array.length > 0) {
                packages_array += null;

                Pk.Results details_results = yield client.get_details_async (packages_array, cancellable, (t, p) => { });

                details_results.get_details_array ().foreach ((details) => {
                    update_results.add_details (details);
                });
            }

            return update_results;
        } catch (Error e) {
            throw e;
        }
    }

    public void update_restart_state () {
        if (restart_file.query_exists ()) {
            if (!restart_required) {
                string title = _("Restart Required");
                string body = _("Please restart your system to finalize updates");
                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("system-software-install"));
                notification.set_priority (NotificationPriority.URGENT);
                notification.set_default_action ("app.open-application");
                Application.get_default ().send_notification ("restart", notification);
            }

            restart_required = true;
        } else if (restart_required) {
            restart_required = false;
        }
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
