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
    public signal void cache_update_failed (Error error);

    private const int SECONDS_BETWEEN_REFRESHES = 60 * 60 * 24;

    public bool refreshing { get; private set; default = false; }

    public bool can_update_all {
        get {
            unowned var fp_client = FlatpakBackend.get_default ();
            return !updating_all && fp_client.n_updatable_packages - fp_client.n_unpaid_updatable_packages > 0;
        }
    }

    private bool _updating_all = false;
    public bool updating_all {
        get { return _updating_all; }
        private set {
            _updating_all = value;
            notify_property ("can-update-all");
        }
    }

    private GLib.DateTime last_refresh_time;
    private bool refresh_required = false;
    private uint refresh_timeout_id = 0;

    construct {
        last_refresh_time = new DateTime.from_unix_utc (AppCenter.App.settings.get_int64 ("last-refresh-time"));

        unowned var fp_client = FlatpakBackend.get_default ();
        fp_client.notify["n-updatable-packages"].connect (on_n_updatable_packages_changed);
        fp_client.notify["n-unpaid-updatable-packages"].connect (() => notify_property ("can-update-all"));

        start_refresh_timeout ();

        NetworkMonitor.get_default ().network_changed.connect (on_network_changed);
    }

    private void on_n_updatable_packages_changed () {
        notify_property ("can-update-all");
        update_badge.begin ();
    }

    private async void update_badge () {
        var n_updatable_packages = FlatpakBackend.get_default ().n_updatable_packages;

        try {
            yield Granite.Services.Application.set_badge (n_updatable_packages);
            yield Granite.Services.Application.set_badge_visible (n_updatable_packages != 0);
        } catch (Error e) {
            warning ("Error setting updates badge: %s", e.message);
        }
    }

    private void start_refresh_timeout () {
        if (refresh_timeout_id != 0) {
            Source.remove (refresh_timeout_id);
            refresh_timeout_id = 0;
        }

        var seconds_since_last_refresh = new DateTime.now_utc ().difference (last_refresh_time) / GLib.TimeSpan.SECOND;

        if (seconds_since_last_refresh >= SECONDS_BETWEEN_REFRESHES) {
            refresh.begin ();
            return;
        }

        var seconds_to_next_refresh = SECONDS_BETWEEN_REFRESHES - (uint) seconds_since_last_refresh;

        refresh_timeout_id = Timeout.add_seconds_once (seconds_to_next_refresh, () => {
            refresh_timeout_id = 0;
            refresh.begin ();
        });
    }

    private void on_network_changed (bool network_available) {
        if (network_available && refresh_required) {
            refresh_required = false;
            Timeout.add_seconds_once (60, () => refresh.begin ());
        }
    }

    /**
     * This always forces a cache refresh and an update check, optionally starting the updates
     * if automatic updates are enabled. Since that is a very expensive operation
     * that also has effects on the browsing experience (blocking install jobs, etc.),
     * calls to this should be carefully considered.
     */
    public async void refresh () {
        if (Utils.is_running_in_demo_mode () || Utils.is_running_in_guest_session ()) {
            return;
        }

        if (refreshing) {
            return;
        }

        if (!NetworkMonitor.get_default ().network_available) {
            refresh_required = true;
            return;
        }

        unowned var app = Application.get_default ();
        ((SimpleAction) app.lookup_action ("refresh")).set_enabled (false);
        refreshing = true;

        unowned var fp_client = FlatpakBackend.get_default ();

        var success = false;
        try {
            success = yield fp_client.refresh_cache (null);
        } catch (Error e) {
            critical ("Refresh cache failed: %s", e.message);
            cache_update_failed (e);
        }

        yield get_updates ();

        last_refresh_time = new DateTime.now_utc ();

        // If the refresh failed don't save the time so that we try again
        // immediately after app restart or system reboot
        if (success) {
            AppCenter.App.settings.set_int64 ("last-refresh-time", last_refresh_time.to_unix ());
        }

        start_refresh_timeout ();

        ((SimpleAction) app.lookup_action ("refresh")).set_enabled (true);
        refreshing = false;
    }

    private async void get_updates () {
        unowned FlatpakBackend fp_client = FlatpakBackend.get_default ();

        yield fp_client.get_updates ();

        if (AppCenter.App.settings.get_boolean ("automatic-updates")) {
            yield update_all ();
        } else {
            var application = Application.get_default ();
            var n_updatable_packages = fp_client.n_updatable_packages;
            if (n_updatable_packages > 0) {
                var title = ngettext ("Update Available", "Updates Available", n_updatable_packages);
                var body = ngettext (
                    "%u app update is available",
                    "%u app updates are available",
                    n_updatable_packages
                ).printf (n_updatable_packages);

                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("software-update-available"));
                notification.set_default_action ("app.show-updates");

                application.send_notification ("io.elementary.appcenter.updates", notification);
            } else {
                application.withdraw_notification ("io.elementary.appcenter.updates");
            }
        }
    }

    public async void update_all () {
        if (!can_update_all) {
            return;
        }

        updating_all = true;
        try {
            var updates = FlatpakBackend.get_default ().updatable_packages;
            for (int i = (int) updates.get_n_items () - 1; i >= 0; i--) {
                var package = (Package) updates.get_item (i);
                if (!package.should_pay) {
                    debug ("Update: %s", package.name);
                    yield package.update ();
                }
            }
        } catch (IOError.CANCELLED e) {
            // Cancelled so just ignore and don't throw an error
        } catch (Error e) {
            var fail_dialog = new UpgradeFailDialog (null, e.message) {
                modal = true,
                transient_for = ((Gtk.Application) GLib.Application.get_default ()).active_window
            };
            fail_dialog.present ();
        } finally {
            updating_all = false;
        }
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
