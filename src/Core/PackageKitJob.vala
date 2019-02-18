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

public class AppCenterCore.PackageKitJob : Object {
    public Type operation { get; construct; }
    public JobArgs? args { get; set; }
    public Error error { get; set; }

    public Value result;

    public signal void results_ready ();

    public enum Type {
        GET_PACKAGE_BY_NAME,
        GET_DETAILS_FOR_PACKAGE_IDS,
        GET_INSTALLED_PACKAGES,
        GET_NOT_INSTALLED_DEPS_FOR_PACKAGE,
        REFRESH_CACHE,
        GET_UPDATES,
        INSTALL_PACKAGES,
        UPDATE_PACKAGES,
        REMOVE_PACKAGES
    }

    public PackageKitJob (Type type) {
        Object (operation: type);
    }
}

public abstract class AppCenterCore.JobArgs { }

public class AppCenterCore.InstallPackagesArgs : JobArgs {
    public Gee.ArrayList<string> package_ids;
    public Pk.ProgressCallback cb;
    public Cancellable cancellable;
}

public class AppCenterCore.UpdatePackagesArgs : JobArgs {
    public Gee.ArrayList<string> package_ids;
    public Pk.ProgressCallback cb;
    public Cancellable cancellable;
}

public class AppCenterCore.RemovePackagesArgs : JobArgs {
    public Gee.ArrayList<string> package_ids;
    public Pk.ProgressCallback cb;
    public Cancellable cancellable;
}

public class AppCenterCore.GetNotInstalledDepsForPackageArgs : JobArgs {
    public Pk.Package package;
    public Cancellable cancellable;
}

public class AppCenterCore.GetPackageByNameArgs : JobArgs {
    public string name;
    public Pk.Bitfield additional_filters;
}

public class AppCenterCore.GetDetailsForPackageIDsArgs : JobArgs {
    public Gee.ArrayList<string> package_ids;
    public Cancellable cancellable;
}

public class AppCenterCore.GetUpdatesArgs : JobArgs {
    public Cancellable cancellable;
}

public class AppCenterCore.RefreshCacheArgs : JobArgs {
    public Cancellable cancellable;
}
