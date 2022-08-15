/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Views.InstalledView : AbstractView {
    private AppListUpdateView app_list_view;

    construct {
        app_list_view = new AppListUpdateView ();
        app_list_view.show_app.connect ((package) => {
            show_package (package);
        });

        add (app_list_view);

        destroy.connect (() => {
           app_list_view.clear ();
        });
    }

    public override void update_navigation () {
        var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();

        if (visible_child == app_list_view) {
            main_window.set_custom_header (null);
            main_window.configure_search (false);
        }

        if (get_adjacent_child (Hdy.NavigationDirection.BACK) == app_list_view) {
            main_window.set_return_name (C_("view", "Installed"));
        }
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
