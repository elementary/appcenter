/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class AppCenterCore.ComponentValidator : Object {
    private Gee.HashSet<string> hidden_app_list;

    private static GLib.Once<ComponentValidator> instance;
    public static unowned ComponentValidator get_default () {
        return instance.once (() => { return new ComponentValidator (); });
    }

    construct {
        hidden_app_list = new Gee.HashSet<string> ();

        string hidden_app_list_path = Path.build_filename (Path.DIR_SEPARATOR_S, Build.CONFIGDIR, Build.HIDDEN_APP_LIST);
        var file = GLib.File.new_for_path (hidden_app_list_path);
        if (!file.query_exists ()) {
            hidden_app_list_path = hidden_app_list_path.replace (".hiddenapps", ".blacklist");
            file = GLib.File.new_for_path (hidden_app_list_path);
            if (file.query_exists ()) {
                critical ("Using .blacklist files is deprecated and will be removed in next version, please use .hiddenapps instead");
            } else {
                return;
            }
        }

        try {
            string contents;
            FileUtils.get_contents (hidden_app_list_path, out contents);
            parse_and_populate (contents);
        } catch (FileError e) {
            warning ("Could not get the contents of hidden app list file: %s", e.message);
        }
    }

    private ComponentValidator () {

    }

    public bool validate (AppStream.Component component) {
        if (component.get_kind () == AppStream.ComponentKind.CONSOLE_APP) {
            return false;
        }

        if (component.get_kind () == AppStream.ComponentKind.RUNTIME) {
            return false;
        }

        if (component.get_id () in hidden_app_list) {
            return false;
        }

        return true;
    }

    private void parse_and_populate (string contents) {
        foreach (string line in contents.split ("\n")) {
            if (line.has_prefix ("#")) {
                continue;
            }

            string token = line.strip ();
            if (token != "") {
                hidden_app_list.add (token);
            }
        }
    }
}
