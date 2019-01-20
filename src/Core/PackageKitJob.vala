/*-
 * Copyright (c) 2019 elementary LLC. (https://elementary.io)
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

public class AppCenterCore.PackageKitJob : Object {
    public Value[] args;
    public Value result;
    public Error error;
    public signal void results_ready ();

    public enum Type {
        STOP_THREAD,
        GET_INSTALLED_PACKAGES,
        GET_NOT_INSTALLED_DEPS_FOR_PACKAGE,
        INSTALL_PACKAGES
    }

    public Type operation;

    public PackageKitJob (Type type) {
        operation = type;
    }
}

public class AppCenterCore.InstallPackagesJob : Object {
    public Gee.ArrayList<string> package_ids;
    public Pk.ProgressCallback cb;
    public Cancellable cancellable;
}

