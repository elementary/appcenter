/*-
 * Copyright 2023 elementary, Inc. (https://elementary.io)
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
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class AppCenterCore.RpmOstreeBackend : Backend, Object {
    public Job.Type job_type { get; protected set; }
    public bool working { public get; protected set; }

    public async Gee.Collection<PackageDetails> get_prepared_applications (Cancellable? cancellable = null) {
        var prepared_packages = new Gee.HashSet<PackageDetails> ();

        return prepared_packages;
    }

    public async Gee.Collection<Package> get_installed_applications (Cancellable? cancellable = null) {
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

    public Gee.Collection<Package> get_packages_for_component_id (string id) {
        return new Gee.ArrayList<Package> ();
    }

    public Package? get_package_for_desktop_id (string id) {
        return null;
    }

    public Gee.Collection<Package> get_packages_by_author (string author, int max) {
        return new Gee.ArrayList<Package> ();
    }

    public async uint64 get_download_size (Package package, Cancellable? cancellable, bool is_update = false) throws GLib.Error {
        return 0;
    }

    public async bool is_package_installed (Package package) throws GLib.Error {
        return true;
    }

    public async PackageDetails get_package_details (Package package) throws GLib.Error {
        return new PackageDetails ();
    }

    public async bool refresh_cache (Cancellable? cancellable) throws GLib.Error {
        return true;
    }

    public async bool install_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        return true;
    }

    public async bool remove_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        return true;
    }

    public async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error {
        return true;
    }

    public async bool repair (Cancellable? cancellable = null) {
        return true;
    }

    private static GLib.Once<RpmOstreeBackend> instance;
    public static unowned RpmOstreeBackend get_default () {
        return instance.once (() => { return new RpmOstreeBackend (); });
    }
}
