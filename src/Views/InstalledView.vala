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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class AppCenter.Views.InstalledView : View {
    private Cancellable refresh_cancellable;

    private AppListUpdateView app_list_view;

    private AsyncMutex refresh_mutex = new AsyncMutex ();

    construct {
        refresh_cancellable = new Cancellable ();

        app_list_view = new AppListUpdateView ();
        app_list_view.show_app.connect ((package) => {
            subview_entered (C_("view", "Installed"), false, "");
            show_package (package);
        });

        add (app_list_view);

        unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();

        app_list_view.set_placeholder_loading ();
        get_apps.begin ();

        client.installed_apps_changed.connect (() => {
            Idle.add (() => {
                app_list_view.set_placeholder_loading ();
                get_apps.begin ();
                return GLib.Source.REMOVE;
            });
        });

        destroy.connect (() => {
           app_list_view.clear ();
        });
    }

    public override void return_clicked () {
        if (previous_package != null) {
            show_package (previous_package);
            subview_entered (C_("view", "Installed"), false, null);
        } else {
            set_visible_child (app_list_view);
            subview_entered (null, false);
        }
    }

    public async void get_apps () {
        refresh_cancellable.cancel ();

        yield refresh_mutex.lock ();

        unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();

        var installed_apps = yield client.get_installed_applications (refresh_cancellable);

        // To gain some speedup of the installed applications list, update the state of the packages ahead
        // of adding them to the list. Otherwise, AppCenter will query each one in turn to get the latest
        // verison string from PackageKit. The update_multiple_package state method ignores packages that
        // aren't PackageKit packages, so this is safe to run on the whole list, even if it includes Flatpaks
        if (AppCenterCore.PackageKitBackend.supports_parallel_package_queries && installed_apps != null) {
            try {
                yield AppCenterCore.PackageKitBackend.get_default ().update_multiple_package_state (installed_apps);
            } catch (Error e) {
                warning ("Error while updating state of installed packages, loading of installed list may fail or be slow: %s", e.message);
            }
        }

        if (!refresh_cancellable.is_cancelled ()) {
            app_list_view.clear ();

            var os_updates = AppCenterCore.UpdateManager.get_default ().os_updates;
            app_list_view.add_package (os_updates);
            app_list_view.add_packages (installed_apps);

            if (os_updates == null && installed_apps.size == 0) { // Can this ever happen?
                app_list_view.set_placeholder_no_results ();
            }
        }

        refresh_mutex.unlock ();

        refresh_cancellable.reset ();
    }

    public async void add_app (AppCenterCore.Package package) {
        unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
        var installed_apps = yield client.get_installed_applications ();
        foreach (var app in installed_apps) {
            if (app == package) {
                app_list_view.add_package (app);
                break;
            }
        }
    }

    public async void remove_app (AppCenterCore.Package package) {
        app_list_view.remove_package (package);
    }
}
