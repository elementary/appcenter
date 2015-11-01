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
    public signal void changed ();

    public string package_id { public get; private set; }
    public Pk.Package pk_package { public get; private set; }
    public Pk.Package? update_package { public get; public set; }
    public bool update_available {
        public get {
            return update_package != null;
        }
    }
    public Gee.TreeSet<AppStream.Component> components { public get; private set; }
    public bool installed { public get; public set; }

    public Package (Pk.Package package) {
        pk_package = package;
        package_id = package.get_id ();
        components = new Gee.TreeSet<AppStream.Component> ();
    }

    public void find_components () {
        components.add_all (Client.get_default ().get_component_for_app (pk_package.get_name ()));
        changed ();
    }

    public static string get_strict_version (string version) {
        string returned = version;
        returned = returned.split ("+", 2)[0];
        returned = returned.split ("-", 2)[0];
        returned = returned.split ("~", 2)[0];
        if (":" in returned) {
            returned = returned.split (":", 2)[1];
        }
        return returned;
    }
}
