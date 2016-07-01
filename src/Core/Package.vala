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

public class AppCenterCore.Package : Object {
    public const string OS_UPDATES_ID = "xxx-os-updates";
    public signal void changed ();

    public AppStream.Component component { public get; private set; }
    public ChangeInformation change_information { public get; private set; }
    public Gee.TreeSet<Pk.Package> installed_packages { public get; private set; }
    public GLib.Cancellable action_cancellable { public get; private set; }
    public bool changing { public get; private set; default= false; }

    public bool installed {
        public get {
            return !installed_packages.is_empty || component.get_id () == OS_UPDATES_ID;
        }
        private set {
            
        }
    }

    public bool update_available {
        public get {
            return installed && change_information.has_changes ();
        }
    }

    public Package (AppStream.Component component) {
        this.component = component;
        installed_packages = new Gee.TreeSet<Pk.Package> ();
        change_information = new ChangeInformation ();
        action_cancellable = new GLib.Cancellable ();
    }

    public async void update () throws GLib.Error {
        action_cancellable.reset ();
        changing = true;
        changed ();
        try {
            yield AppCenterCore.Client.get_default ().update_package (this, (progress, type) => {change_information.ProgressCallback (progress, type);}, action_cancellable);
            installed_packages.add_all (change_information.changes);
            change_information.clear ();
            notify_property ("update-available");
            changing = false;
        } catch (Error e) {
            change_information.reset ();
            changing = false;
            throw e;
        }
    }

    public async void install () throws GLib.Error {
        action_cancellable.reset ();
        changing = true;
        changed ();
        try {
            var application = (Gtk.Application)Application.get_default ();
            var window = application.get_active_window ().get_window ();

            var exit_status = yield AppCenterCore.Client.get_default ().install_package (this, (progress, type) => {change_information.ProgressCallback (progress, type);}, action_cancellable);
            if (exit_status == Pk.Exit.SUCCESS && (window.get_state () & Gdk.WindowState.FOCUSED) == 0) {
                var notification = new Notification (_("Application installed"));
                notification.set_body (_("%s has been successfully installed").printf (get_name ()));
                notification.set_icon (new ThemedIcon ("system-software-install"));
                notification.set_default_action ("app.open-application");

                application.send_notification ("installed", notification);
            }

            installed_packages.add_all (change_information.changes);
            change_information.clear ();
            installed = true;
            changing = false;
        } catch (Error e) {
            change_information.reset ();
            changing = false;
            throw e;
        }
    }

    public async void uninstall () throws GLib.Error {
        action_cancellable.reset ();
        changing = true;
        changed ();
        try {
            yield AppCenterCore.Client.get_default ().remove_package (this, (progress, type) => {change_information.ProgressCallback (progress, type);}, action_cancellable);
            installed_packages.clear ();
            change_information.clear ();
            installed = false;
            changing = false;
        } catch (Error e) {
            change_information.reset ();
            changing = false;
            throw e;
        }
    }

    public string? get_name () {
        var _name = component.get_name ();
        if (_name != null) {
            return _name;
        }

        var package = find_package ();
        if (package != null) {
            return package.get_name ();
        }

        return null;
    }

    public string? get_summary () {
        var summary = component.get_summary ();
        if (summary != null) {
            return summary;
        }

        var package = find_package ();
        if (package != null) {
            return package.get_summary ();
        }

        return null;
    }

    public GLib.Icon get_icon (uint size = 32) {
        GLib.Icon? icon = null;
        uint current_size = 0;

        bool is_stock = false;
        component.get_icons ().foreach ((_icon) => {
            if (is_stock) {
                return;
            }            

            switch (_icon.get_kind ()) {
                case AppStream.IconKind.STOCK:
                    if (Gtk.IconTheme.get_default ().has_icon (_icon.get_name ())) {
                        is_stock = true;
                        icon = new ThemedIcon (_icon.get_name ());
                    }
                    
                    break;
                case AppStream.IconKind.CACHED:
                case AppStream.IconKind.LOCAL:
                    if (_icon.get_width () > current_size && current_size < size) {
                        var file = File.new_for_path (_icon.get_filename ());
                        icon = new FileIcon (file);
                        current_size = _icon.get_width ();
                    }

                    break;
                case AppStream.IconKind.REMOTE:
                    if (_icon.get_width () > current_size && current_size < size) {
                        var file = File.new_for_uri (_icon.get_url ());
                        icon = new FileIcon (file);
                        current_size = _icon.get_width ();
                    }

                    break;
            }
        });

        if (icon == null) {
            if (component.get_kind () == AppStream.ComponentKind.ADDON) {
                icon = new ThemedIcon ("extension");
            } else {
                icon = new ThemedIcon ("application-default-icon");
            }
        }

        return icon;
    }

    public string? get_version () {
        var package = find_package ();
        if (package != null) {
            string returned = package.get_version ();
            returned = returned.split ("+", 2)[0];
            returned = returned.split ("-", 2)[0];
            returned = returned.split ("~", 2)[0];
            if (":" in returned) {
                returned = returned.split (":", 2)[1];
            }

            return returned;
        }

        return null;
    }

    private Pk.Package? find_package (bool installed = false) {
        if (component.id == OS_UPDATES_ID) {
            return null;
        }

        try {
            Pk.Bitfield filter = 0;
            if (installed) {
                filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED);
            }

            return AppCenterCore.Client.get_default ().get_app_package (component.get_pkgnames ()[0], filter);
        } catch (Error e) {
            critical (e.message);
            return null;
        }
    }
}
