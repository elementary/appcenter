/*-
 * Copyright 2019-2021 elementary, Inc. (https://elementary.io)
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

public class AppCenterCore.Job : Object {
    public Type operation { get; construct; }
    public JobArgs? args { get; set; }
    public Error? error { get; set; }

    public Value result;

    public signal void results_ready ();

    public enum Type {
        GET_DETAILS_FOR_PACKAGE_IDS,
        GET_INSTALLED_PACKAGES,
        GET_DOWNLOAD_SIZE,
        REFRESH_CACHE,
        GET_UPDATES,
        INSTALL_PACKAGE,
        UPDATE_PACKAGE,
        REMOVE_PACKAGE,
        IS_PACKAGE_INSTALLED,
        GET_PACKAGE_DETAILS,
        GET_PACKAGE_DEPENDENCIES
    }

    public Job (Type type) {
        Object (operation: type);
    }
}

public abstract class AppCenterCore.JobArgs { }

public class AppCenterCore.GetInstalledPackagesArgs : JobArgs {
    public Cancellable? cancellable;
}

public class AppCenterCore.InstallPackageArgs : JobArgs {
    public Package package;
    public ChangeInformation? change_info;
    public Cancellable? cancellable;
}

public class AppCenterCore.UpdatePackageArgs : JobArgs {
    public Package package;
    public ChangeInformation? change_info;
    public Cancellable? cancellable;
}

public class AppCenterCore.RemovePackageArgs : JobArgs {
    public Package package;
    public ChangeInformation? change_info;
    public Cancellable? cancellable;
}

public class AppCenterCore.GetDownloadSizeArgs : JobArgs {
    public Package package;
    public Cancellable? cancellable;
}

public class AppCenterCore.GetUpdatesArgs : JobArgs {
    public Cancellable? cancellable;
}

public class AppCenterCore.RefreshCacheArgs : JobArgs {
    public Cancellable? cancellable;
}

public class AppCenterCore.IsPackageInstalledArgs : JobArgs {
    public Package package;
}

public class AppCenterCore.GetPackageDetailsArgs : JobArgs {
    public Package package;
}

public class AppCenterCore.GetPackageDependenciesArgs : JobArgs {
    public Package package;
    public Cancellable? cancellable;
}
