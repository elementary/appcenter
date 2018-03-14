// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io)
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
 * Authored by: Jeremy Soller <jeremy@system76.com>
 */

[DBus (name = "org.gnome.Shell.SearchProvider2")]
public class SearchProvider : Object {
    public async string[] get_initial_result_set (string[] terms) throws GLib.Error {
        GenericArray<string> result = new GenericArray<string> ();

        string query = string.joinv (" ", terms);

        var client = AppCenterCore.Client.get_default ();
        var packages = client.search_applications (query, null);
        foreach (var package in packages) {
            result.add (package.component.get_id ());
        }

        result.sort (strcmp);
        return result.data;
    }

    public async string[] get_subsearch_result_set (string[] previous_results, string[] terms) throws GLib.Error {
        return yield get_initial_result_set (terms);
    }

    public HashTable<string, Variant>[] get_result_metas (string[] results) throws GLib.Error {
        var result = new GenericArray<HashTable<string, Variant>> ();

        var client = AppCenterCore.Client.get_default ();
        foreach (var str in results) {
            var package = client.get_package_for_component_id (str);
            if (package != null) {
                var meta = new HashTable<string, Variant> (str_hash, str_equal);
                meta.insert ("id", str);
                meta.insert ("icon", package.get_icon ().serialize ());
                meta.insert ("name", package.get_name ());
                meta.insert ("description", package.get_summary ());

                result.add (meta);
            }
        }

        return result.data;
    }

    public void activate_result (string result, string[] terms, uint32 timestamp) throws GLib.Error {
        var file = GLib.File.new_for_uri ("appstream://" + Uri.escape_string (result));
        GLib.Application.get_default ().open ({ file }, "");
    }

    public void launch_search (string[] terms, uint32 timestamp) throws GLib.Error {
        var file = GLib.File.new_for_uri ("appstream://" + Uri.escape_string (string.joinv (" ", terms)));
        GLib.Application.get_default ().open ({ file }, "");
    }
}