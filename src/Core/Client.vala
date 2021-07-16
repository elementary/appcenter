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
    /**
     * This signal is likely to be fired from a non-main thread. Ensure any UI
     * logic driven from this runs on the GTK thread
     */
    public signal void installed_apps_changed ();

    public AppCenterCore.ScreenshotCache? screenshot_cache { get; private set; default = new ScreenshotCache (); }

    private GLib.Cancellable cancellable;

    private GLib.DateTime last_cache_update = null;

    public uint updates_number { get; private set; default = 0U; }
    private uint update_cache_timeout_id = 0;
    private bool refresh_in_progress = false;

    private const int SECONDS_BETWEEN_REFRESHES = 60 * 60 * 24;

    private AsyncMutex update_notification_mutex = new AsyncMutex ();

    private Client () { }

    construct {
        cancellable = new GLib.Cancellable ();

        last_cache_update = new DateTime.from_unix_utc (AppCenter.App.settings.get_int64 ("last-refresh-time"));
    }

    public async Gee.Collection<AppCenterCore.Package> get_installed_applications (Cancellable? cancellable = null) {
        return yield BackendAggregator.get_default ().get_installed_applications (cancellable);
    }

    public Gee.Collection<Package> get_applications_for_category (AppStream.Category category) {
        return BackendAggregator.get_default ().get_applications_for_category (category);
    }

    public Gee.Collection<Package> search_applications (string query, AppStream.Category? category) {
        return BackendAggregator.get_default ().search_applications (query, category);
    }

    public Gee.Collection<Package> search_applications_mime (string query) {
        return BackendAggregator.get_default ().search_applications_mime (query);
    }

    public async void refresh_updates () {
        yield update_notification_mutex.lock ();

        bool was_empty = updates_number == 0U;
        updates_number = yield UpdateManager.get_default ().get_updates (null);

        var application = Application.get_default ();
        if (was_empty && updates_number != 0U) {
            string title = ngettext ("Update Available", "Updates Available", updates_number);
            string body = ngettext ("%u update is available for your system", "%u updates are available for your system", updates_number).printf (updates_number);

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

        update_notification_mutex.unlock ();

        installed_apps_changed ();
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
        if (force || seconds_since_last_refresh >= SECONDS_BETWEEN_REFRESHES) {
            if (nm.get_network_available ()) {
                debug ("New refresh task");

                refresh_in_progress = true;
                try {
                    success = yield BackendAggregator.get_default ().refresh_cache (cancellable);
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

        if (nm.get_network_available ()) {
            refresh_updates.begin ();
        }

        var next_refresh = SECONDS_BETWEEN_REFRESHES - (uint)seconds_since_last_refresh;
        debug ("Setting a timeout for a refresh in %f minutes", next_refresh / 60.0f);
        update_cache_timeout_id = GLib.Timeout.add_seconds (next_refresh, () => {
            update_cache_timeout_id = 0;
            update_cache.begin (true);

            return GLib.Source.REMOVE;
        });
    }

    public Package? get_package_for_component_id (string id) {
        return BackendAggregator.get_default ().get_package_for_component_id (id);
    }

    public Package? get_package_for_desktop_id (string desktop_id) {
        return BackendAggregator.get_default ().get_package_for_desktop_id (desktop_id);
    }

    public Gee.Collection<Package> get_packages_by_author (string author, int max) {
        return BackendAggregator.get_default ().get_packages_by_author (author, max);
    }

    private static GLib.Once<Client> instance;
    public static unowned Client get_default () {
        return instance.once (() => { return new Client (); });
    }
}
