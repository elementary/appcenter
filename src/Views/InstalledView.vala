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

using AppCenterCore;

public class AppCenter.Views.InstalledView : View {
    AppListUpdateView app_list_view;

    construct {
        app_list_view = new AppListUpdateView ();
        app_list_view.show_app.connect ((package) => {
            subview_entered (C_("view", "Installed"), false, "");
            show_package (package);
        });

        add (app_list_view);

        var client = Client.get_default ();
        client.drivers_detected.connect (() => {
            foreach (var driver in client.driver_list) {
                app_list_view.add_package (driver);
            }
        });

        var os_updates = Client.get_default ().os_updates;
        app_list_view.add_package (os_updates);
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
        unowned Client client = Client.get_default ();

        var installed_apps = yield client.get_installed_applications ();
        app_list_view.add_packages (installed_apps);

        client.get_drivers ();

        var settings = Settings.get_default ();

        if (settings.reset_paid_apps) {
            settings.paid_apps = new string[] {};
            foreach (var app in installed_apps) {
                if (app.component.get_origin () == AppCenterCore.Package.APPCENTER_PACKAGE_ORIGIN) {
                    settings.add_paid_app (app.component.get_id ());
                }
            }

            settings.reset_paid_apps = false;
        }
    }

    public async void add_app (AppCenterCore.Package package) {
        unowned Client client = Client.get_default ();
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
