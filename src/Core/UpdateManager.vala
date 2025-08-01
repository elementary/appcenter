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

    private GLib.Cancellable cancellable;
    private GLib.DateTime last_cache_update = null;
    private uint update_cache_timeout_id = 0;
    private bool refresh_in_progress = false;

    construct {
        cancellable = new GLib.Cancellable ();

        last_cache_update = new DateTime.from_unix_utc (AppCenter.App.settings.get_int64 ("last-refresh-time"));

        unowned var fp_client = FlatpakBackend.get_default ();
        fp_client.notify["n-updatable-packages"].connect (() => notify_property ("can-update-all"));
        fp_client.notify["n-unpaid-updatable-packages"].connect (() => notify_property ("can-update-all"));
    }

    public async void get_updates (Cancellable? cancellable = null) {
        unowned FlatpakBackend fp_client = FlatpakBackend.get_default ();

        yield fp_client.get_updates ();

        if (AppCenter.App.settings.get_boolean ("automatic-updates")) {
            try {
                yield update_all (cancellable);
            } catch (Error e) {} // update_all () already logs error message
            //TODO Should we send a notification that automatic-updates had an error?
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

            try {
                yield Granite.Services.Application.set_badge (n_updatable_packages);
                yield Granite.Services.Application.set_badge_visible (n_updatable_packages != 0);
            } catch (Error e) {
                warning ("Error setting updates badge: %s", e.message);
            }
        }
    }

    public async void update_all (Cancellable? cancellable) throws Error {
        updating_all = true;
        try {
            yield run_update_all (cancellable);
        } catch (IOError.CANCELLED e) {
            // Cancelled don't throw an error
        } catch (Error e) {
            throw (e);
        } finally {
            updating_all = false;
        }
    }

    private async void run_update_all (Cancellable? cancellable) throws Error {
        var updates = FlatpakBackend.get_default ().updatable_packages;
        for (int i = (int) updates.get_n_items () - 1; i >= 0; i--) {
            if (cancellable != null && cancellable.is_cancelled ()) {
                return;
            }

            var package = (Package) updates.get_item (i);
            if (!package.should_pay) {
                debug ("Update: %s", package.name);
                yield package.update ();
            }
        }
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

        /* One cache update a day, keeps the doctor away! */
        var seconds_since_last_refresh = new DateTime.now_utc ().difference (last_cache_update) / GLib.TimeSpan.SECOND;
        bool last_cache_update_is_old = seconds_since_last_refresh >= SECONDS_BETWEEN_REFRESHES;

        if (!force && !last_cache_update_is_old) {
            debug ("Too soon to refresh and not forced");
            return;
        }

        var nm = NetworkMonitor.get_default ();
        if (!nm.get_network_available ()) {
            return;
        }

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

        var next_refresh = SECONDS_BETWEEN_REFRESHES - (uint)seconds_since_last_refresh;
        debug ("Setting a timeout for a refresh in %f minutes", next_refresh / 60.0f);
        update_cache_timeout_id = GLib.Timeout.add_seconds (next_refresh, () => {
            update_cache_timeout_id = 0;
            update_cache.begin (true);

            return GLib.Source.REMOVE;
        });

        get_updates.begin (cancellable);
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
