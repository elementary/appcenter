// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
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

[DBus (name="io.elementary.appcenter")]
public class DBusServer : Object {
    private static GLib.Once<DBusServer> instance;
    public static unowned DBusServer get_default () {
        return instance.once (() => { return new DBusServer (); });
    }

    public static void init () {
        var client = AppCenterCore.Client.get_default ();
        var loop = new MainLoop ();

        client.get_installed_applications.begin ((obj, res) => {
            client.get_installed_applications.end (res);
            loop.quit ();
        });

        loop.run (); // wait until async method finishes
    }

    private DBusServer () {

    }

    /**
     * Installs a package that's id is component_id and also
     * sends a notification when installation finishes or shows
     * a dialog when installation fails
     *
     * @param compontent_id  the component ID to install
     */
    public void install (string component_id) throws Error {
        var client = AppCenterCore.Client.get_default ();
        var package = client.get_package_for_component_id (component_id);
        if (package == null) {
            throw new IOError.FAILED ("Failed to find package for '%s' component ID".printf (component_id));
        }

        package.install.begin ();
    }

    /**
     * Uninstalls a package that's id is component_id
     *
     * @param compontent_id  the component ID to uninstall
     */
    public void uninstall (string component_id) throws Error {
        var client = AppCenterCore.Client.get_default ();
        var package = client.get_package_for_component_id (component_id);
        if (package == null) {
            throw new IOError.FAILED ("Failed to find package for '%s' component ID".printf (component_id));
        }

        package.uninstall.begin ();
    }

    /**
     * Updates a package that's id is component_id
     *
     * @param compontent_id  the component ID to update
     */
    public void update (string component_id) throws Error {
        var client = AppCenterCore.Client.get_default ();
        var package = client.get_package_for_component_id (component_id);
        if (package == null) {
            throw new IOError.FAILED ("Failed to find package for '%s' component ID".printf (component_id));
        }

        package.update.begin ();
    }

    /**
     * Gets the component ID for the specified desktop ID
     *
     * @param desktop_id  the desktop ID (must include ".desktop" extension)
     * @return the component ID, if not found returns empty string
     */
    public string get_component_from_desktop_id (string desktop_id) throws Error {
        var client = AppCenterCore.Client.get_default ();
        var package = client.get_package_for_desktop_id (desktop_id);
        if (package != null) {
            return package.component.get_id ();
        }

        return "";
    }

    /**
     * Searches for a query in the AppStream database
     *
     * @param query  the query to search for
     * @return a list of component ID's that match the query
     */
    public string[] search_components (string query) throws Error {
        var client = AppCenterCore.Client.get_default ();
        var packages = client.search_applications (query, null);
        string[] components = {};
        foreach (var package in packages) {
            components += package.component.get_id ();
        }

        return components;
    }
}
