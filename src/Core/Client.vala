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
    public signal void update_check_finished ();
    public signal void drivers_detected ();

    public bool updating_cache { public get; private set; default = false; }

    public AppCenterCore.ScreenshotCache? screenshot_cache { get; construct; }
    public Gee.TreeSet<AppCenterCore.Package> driver_list { get; construct; }

    private GLib.Cancellable cancellable;

    private GLib.DateTime last_cache_update = null;

    public uint updates_number { get; private set; default = 0U; }
    private uint update_cache_timeout_id = 0;
    private bool refresh_in_progress = false;

    private const int SECONDS_BETWEEN_REFRESHES = 60 * 60 * 24;

    private Client () {
        Object (screenshot_cache: AppCenterCore.ScreenshotCache.new_cache ());
    }

    construct {
        driver_list = new Gee.TreeSet<AppCenterCore.Package> ();
        cancellable = new GLib.Cancellable ();
    }

    public void get_drivers () {
        if (driver_list.size > 0) {
            drivers_detected ();
            return;
        }

        string? drivers_exec_path = Environment.find_program_in_path ("ubuntu-drivers");
        if (drivers_exec_path == null) {
            return;
        }

        var command = new Granite.Services.SimpleCommand ("/", "%s list".printf (drivers_exec_path));
        command.done.connect ((command, status) => {
            parse_drivers_output.begin (command.standard_output_str, status);
        });

        command.run ();
    }

    private async void parse_drivers_output (string output, int status) {
        if (status != 0) {
            return;
        }

        string[] tokens = output.split ("\n");
        for (int i = 0; i < tokens.length; i++) {
            unowned string package_name = tokens[i];
            if (package_name.strip () == "") {
                continue;
            }

            foreach (var driver in driver_list) {
                if (driver.component.get_pkgnames ()[0] == package_name) {
                    continue;
                }
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
            if (package.installed) {
                package.mark_installed ();
                package.update_state ();
            }

            driver_list.add (package);
        }

        drivers_detected ();
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications () {
        return yield PackageKitClient.get_default ().get_installed_applications ();
    }

    public Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category) {
        return PackageKitClient.get_default ().get_applications_for_category (category);
    }

    public Gee.Collection<AppCenterCore.Package> search_applications (string query, AppStream.Category? category) {
        return PackageKitClient.get_default ().search_applications (query, category);
    }

    public Gee.Collection<AppCenterCore.Package> search_applications_mime (string query) {
        return PackageKitClient.get_default ().search_applications_mime (query);
    }

    public async void refresh_updates () {
        bool was_empty = updates_number == 0U;
        updates_number = yield UpdateManager.get_default ().get_updates (null);

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
        var launcher_entry = Unity.LauncherEntry.get_for_desktop_file (GLib.Application.get_default ().application_id + ".desktop");
        launcher_entry.count = updates_number;
        launcher_entry.count_visible = updates_number != 0U;
#endif

        update_check_finished ();
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
                    Pk.Results results = yield PackageKitClient.get_default ().refresh_cache (cancellable);
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

    public AppCenterCore.Package? get_package_for_component_id (string id) {
        return PackageKitClient.get_default ().get_package_for_component_id (id);
    }

    public AppCenterCore.Package? get_package_for_desktop_id (string desktop_id) {
        return PackageKitClient.get_default ().get_package_for_desktop_id (desktop_id);
    }

    public Gee.Collection<AppCenterCore.Package> get_packages_by_author (string author, int max) {
        return PackageKitClient.get_default ().get_packages_by_author (author, max);
    }

    private static GLib.Once<Client> instance;
    public static unowned Client get_default () {
        return instance.once (() => { return new Client (); });
    }
}

