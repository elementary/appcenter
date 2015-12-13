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

public class AppCenterCore.Package : Object {
    public const string OS_UPDATES_ID = "xxx-os-updates";
    public signal void changed ();

    public AppStream.Component component { public get; private set; }
    public ChangeInformation change_information { public get; private set; }
    public Gee.TreeSet<Pk.Package> installed_packages { public get; private set; }
    public bool installed {
        public get {
            return !installed_packages.is_empty;
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
    }

    public async void update () throws GLib.Error {
        try {
            yield AppCenterCore.Client.get_default ().update_package (this, (progress, type) => {change_information.ProgressCallback (progress, type);});
        } catch (Error e) {
            throw e;
        }
    }

    public async void install () throws GLib.Error {
        try {
            yield AppCenterCore.Client.get_default ().install_package (this, (progress, type) => {change_information.ProgressCallback (progress, type);});
            installed = true;
        } catch (Error e) {
            throw e;
        }
    }

    public async void uninstall () throws GLib.Error {
        try {
            yield AppCenterCore.Client.get_default ().remove_package (this, (progress, type) => {});
            installed = false;
        } catch (Error e) {
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
