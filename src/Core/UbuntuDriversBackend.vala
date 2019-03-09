/*-
 * Copyright 2019 elementary, Inc. (https://elementary.io)
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class AppCenterCore.UbuntuDriversBackend : Object {
    private async bool get_drivers_output (out string? output) {
        output = null;
        string? drivers_exec_path = Environment.find_program_in_path ("ubuntu-drivers");
        if (drivers_exec_path == null) {
            return false;
        }

        Subprocess command;
        try {
            command = new Subprocess (SubprocessFlags.STDOUT_PIPE, drivers_exec_path, "list");
            yield command.communicate_utf8_async (null, null, out output, null);
        } catch (Error e) {
            return false;
        }

        return command.get_exit_status () == 0;
    }

    public async Gee.TreeSet<Package> get_drivers () {
        var driver_list = new Gee.TreeSet<Package> ();
        string? command_output;
        var result = yield get_drivers_output (out command_output);
        if (!result || command_output == null) {
            return driver_list;
        }

        string[] tokens = command_output.split ("\n");
        for (int i = 0; i < tokens.length; i++) {
            unowned string package_name = tokens[i];
            if (package_name.strip () == "") {
                continue;
            }

            var driver_component = new AppStream.Component ();
            driver_component.set_kind (AppStream.ComponentKind.DRIVER);
            driver_component.set_pkgnames ({ package_name });
            driver_component.set_id (package_name);

            var icon = new AppStream.Icon ();
            icon.set_name ("application-x-firmware");
            icon.set_kind (AppStream.IconKind.STOCK);
            driver_component.add_icon (icon);

            var package = new Package (driver_component);
            if (package.installed) {
                package.mark_installed ();
                package.update_state ();
            }

            driver_list.add (package);
        }

        return driver_list;
    }

    private static GLib.Once<UbuntuDriversBackend> instance;
    public static unowned UbuntuDriversBackend get_default () {
        return instance.once (() => { return new UbuntuDriversBackend (); });
    }
}
