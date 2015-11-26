// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
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

using AppCenterCore;

public class AppCenter.Views.InstalledView : View {
    AppListView app_list_view;

    public InstalledView () {
        // We need this line in order to show the No Update view.
        Client.get_default ().updates_available.connect (() => {
            var package = Client.get_default ().os_updates;
            if (package.update_available) {
                app_list_view.add_package (package);
            }

            app_list_view.updating_cache = false;
            show_update_number ();
        });
        get_apps.begin ();
    }

    construct {
        app_list_view = new AppListView (true);
        add (app_list_view);
        app_list_view.show_app.connect ((package) => {
            subview_entered (C_("view", "Installed"));
            show_package (package);
        });
    }

    public override void return_clicked () {
        set_visible_child (app_list_view);
    }

    private void show_update_number () {
        var applications = app_list_view.get_packages ();
        uint update_numbers = 0U;
        uint64 update_real_size = 0ULL;
        foreach (var package in applications) {
            if (package.update_available) {
                update_numbers++;
                update_real_size += package.update_size;
            }
        }
#if HAVE_UNITY
        var launcher_entry = Unity.LauncherEntry.get_for_desktop_file ("appcenter.desktop");
        launcher_entry.count = update_numbers;
        launcher_entry.count_visible = update_numbers != 0U;
#endif
    }

    private async void get_apps () {
        unowned Client client = Client.get_default ();
        var installed_apps = yield client.get_installed_applications ();
        foreach (var app in installed_apps) {
            app_list_view.add_package (app);
        }

        yield client.get_updates ();
    }
}
