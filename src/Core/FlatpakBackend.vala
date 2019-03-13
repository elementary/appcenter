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

public class AppCenterCore.FlatpakBackend : Backend, Object {

    public async Gee.Collection<Package> get_installed_applications () {
        return new Gee.ArrayList<Package> ();
    }

    public Gee.Collection<Package> get_applications_for_category (AppStream.Category category) {
        return new Gee.ArrayList<Package> ();
    }

    public Gee.Collection<Package> search_applications (string query, AppStream.Category? category) {
        return new Gee.ArrayList<Package> ();
    }

    public Gee.Collection<Package> search_applications_mime (string query) {
        return new Gee.ArrayList<Package> ();
    }

    public Package? get_package_for_component_id (string id) {
        return null;
    }

    public Package? get_package_for_desktop_id (string id) {
        return null;
    }

    public Gee.Collection<Package> get_packages_by_author (string author, int max) {
        return new Gee.ArrayList<Package> ();
    }

    public async uint64 get_download_size (Package package, Cancellable? cancellable) throws GLib.Error {
        return 0;
    }

    public async bool is_package_installed (Package package) throws GLib.Error {
        return false;
    }

    public async PackageDetails get_package_details (Package package) throws GLib.Error {
        return new PackageDetails ();
    }

    public async bool install_package (Package package, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        return false;
    }

    public async bool remove_package (Package package, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        return false;
    }

    public async bool update_package (Package package, owned Pk.ProgressCallback cb, Cancellable cancellable) throws GLib.Error {
        return false;
    }

    private static GLib.Once<UbuntuDriversBackend> instance;
    public static unowned UbuntuDriversBackend get_default () {
        return instance.once (() => { return new UbuntuDriversBackend (); });
    }
}
