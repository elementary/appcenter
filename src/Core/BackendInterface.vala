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

public enum BackendType {
    PACKAGEKIT,
    UBUNTU_DRIVERS
}

public interface AppCenterCore.Backend : Object {
    public abstract bool working { public get; protected set; }

    public abstract async Gee.Collection<Package> get_installed_applications (Cancellable? cancellable = null);
    public abstract Gee.Collection<Package> get_applications_for_category (AppStream.Category category);
    public abstract Gee.Collection<Package> search_applications (string query, AppStream.Category? category);
    public abstract Gee.Collection<Package> search_applications_mime (string query);
    public abstract Package? get_package_for_component_id (string id);
    public abstract Gee.Collection<Package> get_packages_for_component_id (string id);
    public abstract Package? get_package_for_desktop_id (string id);
    public abstract Gee.Collection<Package> get_packages_by_author (string author, int max);

    public abstract async bool refresh_cache (Cancellable? cancellable) throws GLib.Error;
    public abstract async uint64 get_download_size (Package package, Cancellable? cancellable, bool is_update = false) throws GLib.Error;
    public abstract async bool is_package_installed (Package package) throws GLib.Error;
    public abstract async PackageDetails get_package_details (Package package) throws GLib.Error;
    public abstract async bool install_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error;
    public abstract async bool update_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error;
    public abstract async bool remove_package (Package package, ChangeInformation? change_info, Cancellable? cancellable) throws GLib.Error;
}
