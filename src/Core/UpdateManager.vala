/*
 * Copyright 2017–2021 elementary, Inc. (https://elementary.io)
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
    /**
     * This signal is likely to be fired from a non-main thread. Ensure any UI
     * logic driven from this runs on the GTK thread
     */
    public signal void installed_apps_changed ();
    public signal void cache_update_failed (Error error);

    public ListStore updates_liststore { public get; private set; }
    public Package runtime_updates { public get; private set; }
    public int unpaid_apps_number { get; private set; default = 0; }
    public uint updates_number { get; set; default = 0U; }
    public uint64 updates_size { get; private set; default = 0ULL; }

    private const int SECONDS_BETWEEN_REFRESHES = 60 * 60 * 24;

    private GLib.Cancellable cancellable;
    private GLib.DateTime last_cache_update = null;
    private uint update_cache_timeout_id = 0;
    private bool refresh_in_progress = false;

    construct {
        updates_liststore = new ListStore (typeof (AppCenterCore.Package));
        updates_liststore.bind_property ("n-items", this, "updates-number");

        var runtime_icon = new AppStream.Icon ();
        runtime_icon.set_name ("application-vnd.flatpak");
        runtime_icon.set_kind (AppStream.IconKind.STOCK);

        var runtime_updates_component = new AppStream.Component ();
        runtime_updates_component.id = AppCenterCore.Package.RUNTIME_UPDATES_ID;
        runtime_updates_component.name = _("Runtime Updates");
        runtime_updates_component.summary = _("Updates to app runtimes");
        runtime_updates_component.add_icon (runtime_icon);

        runtime_updates = new AppCenterCore.Package (runtime_updates_component);

        cancellable = new GLib.Cancellable ();

        last_cache_update = new DateTime.from_unix_utc (AppCenter.App.settings.get_int64 ("last-refresh-time"));
    }

    public async uint get_updates (Cancellable? cancellable = null) {
        updates_liststore.remove_all ();
        unpaid_apps_number = 0;
        updates_size = 0ULL;

        // Clear any packages previously marked as updatable
        var installed_packages = yield FlatpakBackend.get_default ().get_installed_applications ();
        foreach (var installed_package in installed_packages) {
            installed_package.change_information.clear_update_info ();
            installed_package.update_state ();
        }

        uint runtime_count = 0;
        string runtime_desc = "";

        unowned FlatpakBackend fp_client = FlatpakBackend.get_default ();
        var flatpak_updates = yield fp_client.get_updates ();
        debug ("Flatpak backend reports %d updates", flatpak_updates.size);

        foreach (var flatpak_update in flatpak_updates) {
            var appcenter_package = fp_client.lookup_package_by_id (flatpak_update);
            if (appcenter_package != null) {
                debug ("Added %s to app updates", flatpak_update);
                updates_liststore.insert_sorted (appcenter_package, compare_package_func);

                if (appcenter_package.should_pay) {
                    unpaid_apps_number++;
                }

                updates_size += appcenter_package.change_information.size;

                appcenter_package.change_information.updatable_packages.add (flatpak_update);
                appcenter_package.update_state ();
                try {
                    appcenter_package.change_information.size = yield fp_client.get_download_size (appcenter_package, null, true);
                } catch (Error e) {
                    warning ("Unable to get flatpak download size: %s", e.message);
                }
            } else {
                debug ("Added %s to runtime updates", flatpak_update);
                string bundle_id;
                if (!FlatpakBackend.get_package_list_key_parts (flatpak_update, null, null, out bundle_id)) {
                    continue;
                }

                Flatpak.Ref @ref;
                try {
                    @ref = Flatpak.Ref.parse (bundle_id);
                } catch (Error e) {
                    warning ("Error parsing flatpak bundle ID: %s", e.message);
                    continue;
                }

                runtime_count++;

                runtime_desc += Markup.printf_escaped (
                    " • %s\n\t%s\n",
                    @ref.get_name (),
                    _("Version: %s").printf (@ref.get_branch ())
                );

                uint64 dl_size = 0;
                try {
                    dl_size = yield fp_client.get_download_size_by_id (flatpak_update, null, true);
                } catch (Error e) {
                    warning ("Unable to get flatpak download size: %s", e.message);
                }

                updates_size += dl_size;
                runtime_updates.change_information.size += dl_size;
                runtime_updates.change_information.updatable_packages.add (flatpak_update);
            }
        }

        var runtime_updates_size = yield runtime_updates.get_download_size_including_deps ();
        if (runtime_updates_size > 0) {
            updates_liststore.insert_sorted (runtime_updates, compare_package_func);
        }

        if (runtime_count == 0) {
            debug ("No runtime updates found");
            var latest_version = _("No runtimes with updates");
            runtime_updates.latest_version = latest_version;
            runtime_updates.description = GLib.Markup.printf_escaped ("%s\n", latest_version);
        } else {
            debug ("%u runtime updates found", runtime_count);
            var latest_version = ngettext ("%u runtimes with updates", "%u runtimes with updates", runtime_count).printf (runtime_count);
            runtime_updates.latest_version = latest_version;
            runtime_updates.description = "%s\n%s\n".printf (GLib.Markup.printf_escaped (_("%s:"), latest_version), runtime_desc);
        }

        debug ("%u app updates found", updates_number);

        if (!AppCenter.App.settings.get_boolean ("automatic-updates")) {
            var application = Application.get_default ();
            if (updates_number > 0) {
                var title = ngettext ("Update Available", "Updates Available", updates_number);
                var body = ngettext (
                    "%u app update is available",
                    "%u app updates are available",
                    updates_number
                ).printf (updates_number);

                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("software-update-available"));
                notification.set_default_action ("app.show-updates");

                application.send_notification ("io.elementary.appcenter.updates", notification);
            } else {
                application.withdraw_notification ("io.elementary.appcenter.updates");
            }

            try {
                yield Granite.Services.Application.set_badge (updates_number);
                yield Granite.Services.Application.set_badge_visible (updates_number != 0);
            } catch (Error e) {
                warning ("Error setting updates badge: %s", e.message);
            }
        }

        runtime_updates.update_state ();

        installed_apps_changed ();

        return updates_number;
    }

    public void cancel_updates (bool cancel_timeout) {
        cancellable.cancel ();

        if (update_cache_timeout_id > 0 && cancel_timeout) {
            Source.remove (update_cache_timeout_id);
            update_cache_timeout_id = 0;
        }
    }

    public async void update_cache (bool force = false) {
        cancellable.reset ();

        if (Utils.is_running_in_demo_mode () || Utils.is_running_in_guest_session ()) {
            return;
        }

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
                return;
            }
        }

        var nm = NetworkMonitor.get_default ();

        /* One cache update a day, keeps the doctor away! */
        var seconds_since_last_refresh = new DateTime.now_utc ().difference (last_cache_update) / GLib.TimeSpan.SECOND;
        bool last_cache_update_is_old = seconds_since_last_refresh >= SECONDS_BETWEEN_REFRESHES;
        if (force || last_cache_update_is_old) {
            if (nm.get_network_available ()) {
                debug ("New refresh task");

                refresh_in_progress = true;
                try {
                    success = yield FlatpakBackend.get_default ().refresh_cache (cancellable);

                    if (success) {
                        last_cache_update = new DateTime.now_utc ();
                        AppCenter.App.settings.set_int64 ("last-refresh-time", last_cache_update.to_unix ());
                    }

                    seconds_since_last_refresh = 0;
                } catch (Error e) {
                    if (!(e is GLib.IOError.CANCELLED)) {
                        critical ("Update_cache: Refesh cache async failed - %s", e.message);
                        cache_update_failed (e);
                    }
                } finally {
                    refresh_in_progress = false;
                }
            }
        } else {
            debug ("Too soon to refresh and not forced");
        }


        var next_refresh = SECONDS_BETWEEN_REFRESHES - (uint)seconds_since_last_refresh;
        debug ("Setting a timeout for a refresh in %f minutes", next_refresh / 60.0f);
        update_cache_timeout_id = GLib.Timeout.add_seconds (next_refresh, () => {
            update_cache_timeout_id = 0;
            update_cache.begin (true);

            return GLib.Source.REMOVE;
        });

        if (nm.get_network_available ()) {
            if ((force || last_cache_update_is_old) && AppCenter.App.settings.get_boolean ("automatic-updates")) {
                yield get_updates ();
                debug ("Update Flatpaks");
                var installed_apps = yield FlatpakBackend.get_default ().get_installed_applications (cancellable);
                foreach (var app in installed_apps) {
                    if (app.update_available && !app.should_pay) {
                        debug ("Update: %s", app.get_name ());
                        try {
                            yield app.update (false);
                        } catch (Error e) {
                            warning ("Updating %s failed: %s", app.get_name (), e.message);
                        }
                    }
                }
            }

            get_updates.begin ();
        }
    }

    private int compare_package_func (Object object1, Object object2) {
        var package1 = (AppCenterCore.Package) object1;
        var package2 = (AppCenterCore.Package) object2;

        bool a_is_runtime = false;
        bool a_is_updating = false;
        string a_package_name = "";
        if (package1 != null) {
            a_is_runtime = package1.is_runtime_updates;
            a_is_updating = package1.is_updating;
            a_package_name = package1.get_name ();
        }

        bool b_is_runtime = false;
        bool b_is_updating = false;
        string b_package_name = "";
        if (package2 != null) {
            b_is_runtime = package2.is_runtime_updates;
            b_is_updating = package2.is_updating;
            b_package_name = package2.get_name ();
        }

        // The currently updating package is always top of the list
        if (a_is_updating || b_is_updating) {
            return a_is_updating ? -1 : 1;
        }

        // Ensures runtime updates are sorted to the top amongst up-to-date packages but below OS updates
        if (a_is_runtime || b_is_runtime) {
            return a_is_runtime ? -1 : 1;
        }

        return a_package_name.collate (b_package_name); /* Else sort in name order */
    }

    public async void add_app (AppCenterCore.Package package) {
        var installed_apps = yield AppCenterCore.FlatpakBackend.get_default ().get_installed_applications ();
        foreach (var app in installed_apps) {
            if (app == package) {
                updates_liststore.insert_sorted (package, compare_package_func);
                break;
            }
        }
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
