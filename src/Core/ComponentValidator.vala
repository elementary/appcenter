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
    private Gee.HashSet<string> blacklist;

    private static GLib.Once<ComponentValidator> instance;
    public static unowned ComponentValidator get_default () {
        return instance.once (() => { return new ComponentValidator (); });
    }

    construct {
        blacklist = new Gee.HashSet<string> ();

        string blacklist_path = Path.build_filename (Path.DIR_SEPARATOR_S, Build.CONFIGDIR, Build.BLACKLIST);

        try {
            string contents;
            FileUtils.get_contents (blacklist_path, out contents);
            parse_and_populate (contents);
        } catch (FileError e) {
            warning ("Could not get the contents of blacklist file: %s", e.message);
        }
    }

    private ComponentValidator () {

    }

    public bool validate (AppStream.Component component) {
        if (component.get_kind () == AppStream.ComponentKind.CONSOLE_APP) {
            return false;
        }

        if (component.get_id () in blacklist) {
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
                blacklist.add (token);
            }
        }
    }
}
