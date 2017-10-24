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
    private const int TRY_AGAIN_RESPONSE_ID = 1;
    AppListUpdateView app_list_view;
    Gtk.InfoBar info_bar;

    construct {
        info_bar = new Gtk.InfoBar ();
        info_bar.message_type = Gtk.MessageType.ERROR;
        info_bar.add_button (_("Try Again"), TRY_AGAIN_RESPONSE_ID);
        info_bar.response.connect (on_info_bar_response);
        set_widget_visibility (info_bar, false);

        var error_label = new Gtk.Label (null);
        error_label.wrap = true;
        error_label.selectable = true;

        var content = info_bar.get_content_area ();
        content.add (error_label);

        app_list_view = new AppListUpdateView ();
        app_list_view.show_app.connect ((package) => {
            subview_entered (C_("view", "Updates"), false, "");
            show_package (package);
        });

        var grid = new Gtk.Grid ();
        grid.attach (info_bar, 0, 0, 1, 1);
        grid.attach (app_list_view, 0, 1, 1, 1);
        add (grid);

        var client = Client.get_default ();
        client.notify["updating-cache"].connect (() => {
            if (client.updating_cache && info_bar.visible) {
                set_widget_visibility (info_bar, false);
            }
        });

        client.cache_update_failed.connect ((error) => {
            string message = format_error_message (error.message);
            error_label.label = _("Failed to fetch updates: %s. This may be caused by external, manually added software repositories or corrupted sources file.").printf (error.message);
            if (!info_bar.visible) {
                set_widget_visibility (info_bar, true);
            }
        });

        client.drivers_detected.connect (() => {
            foreach (var driver in client.driver_list) {
                app_list_view.add_package (driver);
            }
        });

        client.updates_available.connect (update_os_package_visibility);
        client.bind_property ("updating-cache", app_list_view, "updating-cache", GLib.BindingFlags.DEFAULT);
        update_os_package_visibility ();
    }

    public override void return_clicked () {
        if (previous_package != null) {
            show_package (previous_package);
            subview_entered (C_("view", "Updates"), false, null);
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

    private void update_os_package_visibility () {
        var package = Client.get_default ().os_updates;
        if (package.update_available) {
            app_list_view.add_package (package);
        }
    }

    private void on_info_bar_response (int response) {
        if (response == TRY_AGAIN_RESPONSE_ID) {
            set_widget_visibility (info_bar, false);
            Client.get_default ().update_cache.begin (true);
        }
    }

    private static string format_error_message (string message) {
        string msg = message.replace ("\n", " ").strip ();
        if (msg.has_suffix (".")) {
            msg = msg.substring (0, msg.length - 1);
        }

        return msg;
    }
}
