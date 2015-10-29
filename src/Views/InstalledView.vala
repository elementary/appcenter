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

public class AppCenter.Views.InstalledView : Gtk.ScrolledWindow {
    AppListView app_list_view;
    public InstalledView () {
        get_apps.begin ();
    }

    construct {
        app_list_view = new AppListView ();
        add (app_list_view);
    }

    private async void get_apps () {
        unowned Client client = Client.get_default ();
        var installed_apps = yield client.get_installed_applications ();
        foreach (var app in installed_apps) {
            app_list_view.add_package (app);
        }
    }
}
