// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public errordomain PackageLaunchError {
    DESKTOP_ID_NOT_FOUND,
    APP_INFO_NOT_FOUND
}

public class AppCenterCore.Package : Object {
    public const string APPCENTER_PACKAGE_ORIGIN = "appcenter-xenial-main";
    private const string ELEMENTARY_STABLE_PACKAGE_ORIGIN = "stable-xenial-main";
    private const string ELEMENTARY_DAILY_PACKAGE_ORIGIN = "daily-xenial-main";

    public signal void changing (bool is_changing);
    public signal void info_changed (Pk.Status status);

    public enum State {
        NOT_INSTALLED,
        INSTALLED,
        INSTALLING,
        UPDATE_AVAILABLE,
        UPDATING,
        REMOVING
    }

    public const string OS_UPDATES_ID = "xxx-os-updates";
    public const string LOCAL_ID_SUFFIX = ".appcenter-local";
    public const string DEFAULT_PRICE_DOLLARS = "1";

    public AppStream.Component component { get; construct; }
    public ChangeInformation change_information { public get; private set; }
    public Gee.TreeSet<Pk.Package> installed_packages { public get; private set; }
    public GLib.Cancellable action_cancellable { public get; private set; }
    public State state { public get; private set; default = State.NOT_INSTALLED; }

    public double progress {
        get {
            return change_information.progress;
        }
    }

    public bool installed {
        get {
            if (!installed_packages.is_empty) {
                return true;
            }

            if (component.get_id () == OS_UPDATES_ID) {
                return true;
            }

            Pk.Package? package = find_package ();
            if (package != null && package.info == Pk.Info.INSTALLED) {
                return true;
            }

            return false;
        }
    }

    public bool update_available {
        get {
            return state == State.UPDATE_AVAILABLE;
        }
    }

    public bool should_pay {
        get {
            if (!is_native || is_os_updates) {
                return false;
            }

            if (get_payments_key () == null || get_suggested_amount () == "0") {
                return false;
            }

            if (component.get_id () in AppCenter.Settings.get_default ().paid_apps) {
                return false;
            }

            var newest_release = get_newest_release ();
            if (newest_release != null && newest_release.get_urgency () == AppStream.UrgencyKind.CRITICAL) {
                return false;
            }

            return true;
        }
    }

    public bool should_nag_update {
        get {
            return update_available && should_pay;
        }
    }

    public bool is_updating {
        get {
            return state == State.UPDATING;
        }
    }

    public bool changes_finished {
        get {
            return change_information.status == Pk.Status.FINISHED;
        }
    }

    public bool is_os_updates {
        get {
            return component.id == OS_UPDATES_ID;
        }
    }

    public bool is_driver {
       get {
           return component.get_kind () == AppStream.ComponentKind.DRIVER;
       }
    }

    public bool is_local {
        get {
            return component.get_id ().has_suffix (LOCAL_ID_SUFFIX);
        }
    }

    public bool is_shareable {
        get {
            return !is_driver && !is_os_updates;
        }
    }

    public bool is_native {
        get {
            switch (component.get_origin ()) {
                case APPCENTER_PACKAGE_ORIGIN:
                case ELEMENTARY_STABLE_PACKAGE_ORIGIN:
                case ELEMENTARY_DAILY_PACKAGE_ORIGIN:
                    return true;
                default:
                    return false;
            }
        }
    }

    private string? _author = null;
    public string author {
        get {
            if (_author != null) {
                return _author;
            }

            _author = component.developer_name;

            if (_author == null) {
                var project_group = component.project_group;

                if (project_group != null) {
                    _author = project_group;
                }
            }

            return _author;
        }
    }

    private string? _author_title = null;
    public string author_title {
        get {
            if (_author_title != null) {
                return _author_title;
            }

            _author_title = author;
            if (_author_title == null) {
                _author_title = _("%s Developers").printf (get_name ());
            }

            return _author_title;
        }
    }

    private string? name = null;
    public string? description = null;
    private string? summary = null;
    private string? color_primary = null;
    private string? color_primary_text = null;
    private string? payments_key = null;
    private string? suggested_amount = null;
    private string? _latest_version = null;
    public string? latest_version {
        private get { return _latest_version; }
        internal set { _latest_version = convert_version (value); }
    }

    private Pk.Package? pk_package = null;
    private AppInfo? app_info;
    private bool app_info_retrieved = false;

    construct {
        installed_packages = new Gee.TreeSet<Pk.Package> ();
        change_information = new ChangeInformation ();
        change_information.status_changed.connect (() => info_changed (change_information.status));

        action_cancellable = new GLib.Cancellable ();
    }

    public Package (AppStream.Component component) {
        Object (component: component);
    }

    public void update_state () {
        if (installed) {
            if (change_information.has_changes ()) {
                state = State.UPDATE_AVAILABLE;
            } else {
                state = State.INSTALLED;
            }
        } else {
            state = State.NOT_INSTALLED;
        }
    }

    public async bool update () {
        if (state != State.UPDATE_AVAILABLE) {
            return false;
        }

        try {
            return yield perform_operation (State.UPDATING, State.INSTALLED, State.UPDATE_AVAILABLE);
        } catch (Error e) {
            return false;
        }
    }

    public async bool install () {
        if (state != State.NOT_INSTALLED) {
            return false;
        }

        try {
            bool success = yield perform_operation (State.INSTALLING, State.INSTALLED, State.NOT_INSTALLED);
            if (success) {
                var client = AppCenterCore.Client.get_default ();
                client.operation_finished (this, State.INSTALLING, null);
            }

            return success;
        } catch (Error e) {
            var client = AppCenterCore.Client.get_default ();
            client.operation_finished (this, State.INSTALLING, e);
            return false;
        }
    }

    public async bool uninstall () {
        if (state == State.INSTALLED || state == State.UPDATE_AVAILABLE) {
            try {
                return yield perform_operation (State.REMOVING, State.NOT_INSTALLED, state);
            } catch (Error e) {
                return false;
            }
        }

        return false;
    }

    public void launch () throws Error {
        if (app_info == null) {
            throw new PackageLaunchError.APP_INFO_NOT_FOUND ("AppInfo not found for package: %s".printf (get_name ()));
        }

        try {
            app_info.launch (null, null);
        } catch (Error e) {
            throw e;
        }
    }

    private async bool perform_operation (State performing, State after_success, State after_fail) throws GLib.Error {
        var exit_status = Pk.Exit.UNKNOWN;
        prepare_package_operation (performing);
        try {
            exit_status = yield perform_package_operation ();
        } catch (GLib.Error e) {
            warning ("Operation failed for package %s - %s", get_name (), e.message);
            throw e;
        } finally {
            clean_up_package_operation (exit_status, after_success, after_fail);
        }

        return (exit_status == Pk.Exit.SUCCESS);
    }

    private void prepare_package_operation (State initial_state) {
        changing (true);

        action_cancellable.reset ();
        change_information.start ();
        state = initial_state;
    }

    private async Pk.Exit perform_package_operation () throws GLib.Error {
        Pk.ProgressCallback cb = change_information.ProgressCallback;
        var client = AppCenterCore.Client.get_default ();
        switch (state) {
            case State.UPDATING:
                return yield client.update_package (this, cb, action_cancellable);
            case State.INSTALLING:
                return yield client.install_package (this, cb, action_cancellable);
            case State.REMOVING:
                return yield client.remove_package (this, cb, action_cancellable);
            default:
                return Pk.Exit.UNKNOWN;
        }
    }

    private void clean_up_package_operation (Pk.Exit exit_status, State success_state, State fail_state) {
        changing (false);

        installed_packages.add_all (change_information.changes);
        if (exit_status == Pk.Exit.SUCCESS) {
            change_information.complete ();
            state = success_state;
        } else {
            state = fail_state;
            change_information.cancel ();
        }
     }

    public string? get_name () {
        if (name != null) {
            return name;
        }

        name = component.get_name ();
        if (name == null) {
            var package = find_package ();
            if (package != null) {
                name = package.get_name ();
            }
        }

        return name;
    }

    public string? get_description () {
        if (description != null) {
            return description;
        }

        description = component.get_description ();
        if (description == null) {
            var package = find_package ();
            if (package != null) {
                description = package.description;
            }
        }

        return description;
    }

    public string? get_summary () {
        if (summary != null) {
            return summary;
        }

        summary = component.get_summary ();
        if (summary == null) {
            var package = find_package ();
            if (package != null) {
                summary = package.get_summary ();
            }
        }

        return summary;
    }

    public string get_progress_description () {
        return change_information.get_status_string ();
    }

    public GLib.Icon get_icon (uint size, uint scale_factor) {
        GLib.Icon? icon = null;
        uint current_size = 0;
        uint current_scale = 0;
        uint pixel_size = size * scale_factor;

        weak GenericArray<AppStream.Icon> icons = component.get_icons ();
        for (int i = 0; i < icons.length; i++) {
            weak AppStream.Icon _icon = icons[i];
            switch (_icon.get_kind ()) {
                case AppStream.IconKind.STOCK:
                    unowned string icon_name = _icon.get_name ();
                    if (Gtk.IconTheme.get_default ().has_icon (icon_name)) {
                        return new ThemedIcon (icon_name);
                    }

                    break;
                case AppStream.IconKind.CACHED:
                case AppStream.IconKind.LOCAL:
                    var icon_scale = _icon.get_scale ();
                    var icon_width = _icon.get_width () * icon_scale;
                    bool is_bigger = (icon_width > current_size && current_size < pixel_size);
                    bool has_better_dpi = (icon_width == current_size && current_scale < icon_scale && scale_factor <= icon_scale);
                    if (is_bigger || has_better_dpi) {
                        var file = File.new_for_path (_icon.get_filename ());
                        icon = new FileIcon (file);
                        current_size = icon_width;
                        current_scale = icon_scale;
                    }

                    break;
                case AppStream.IconKind.REMOTE:
                    var icon_scale = _icon.get_scale ();
                    var icon_width = _icon.get_width () * icon_scale;
                    bool is_bigger = (icon_width > current_size && current_size < pixel_size);
                    bool has_better_dpi = (icon_width == current_size && current_scale < icon_scale && scale_factor <= icon_scale);
                    if (is_bigger || has_better_dpi) {
                        var file = File.new_for_uri (_icon.get_url ());
                        icon = new FileIcon (file);
                        current_size = icon_width;
                        current_scale = icon_scale;
                    }

                    break;
            }
        }

        if (icon == null) {
            if (component.get_kind () == AppStream.ComponentKind.ADDON) {
                icon = new ThemedIcon ("extension");
            } else {
                icon = new ThemedIcon ("application-default-icon");
            }
        }

        return icon;
    }

    public string? get_version () {
        if (latest_version != null) {
            return latest_version;
        }

        var package = find_package ();
        if (package != null) {
            latest_version = package.get_version ();
        }

        return latest_version;
    }

    public string? get_color_primary () {
        if (color_primary != null) {
            return color_primary;
        } else {
            color_primary = component.get_custom_value ("x-appcenter-color-primary");
            return color_primary;
        }
    }

    public string? get_color_primary_text () {
        if (color_primary_text != null) {
            return color_primary_text;
        } else {
            color_primary_text = component.get_custom_value ("x-appcenter-color-primary-text");
            return color_primary_text;
        }
    }

    public string? get_payments_key () {
        if (payments_key != null) {
            return payments_key;
        } else {
            payments_key = component.get_custom_value ("x-appcenter-stripe");
            return payments_key;
        }
    }

    public string get_suggested_amount () {
        if (suggested_amount != null) {
            return suggested_amount;
        } else {
            suggested_amount = component.get_custom_value ("x-appcenter-suggested-price");
            return suggested_amount == null ? DEFAULT_PRICE_DOLLARS : suggested_amount;
        }
    }

    private string convert_version (string version) {
        if (is_os_updates) {
            return version;
        }

        string returned = version;
        returned = returned.split ("+", 2)[0];
        returned = returned.split ("-", 2)[0];
        returned = returned.split ("~", 2)[0];
        if (":" in returned) {
            returned = returned.split (":", 2)[1];
        }

        return returned;
    }

    public bool get_can_launch () {
        if (app_info_retrieved) {
            return app_info != null;
        }

        string? desktop_id = component.get_desktop_id ();
        if (desktop_id != null) {
            app_info = new DesktopAppInfo (desktop_id);
        }

        app_info_retrieved = true;
        return app_info != null;
    }

    public Gee.ArrayList<AppStream.Release> get_newest_releases (int min_releases, int max_releases) {
        var list = new Gee.ArrayList<AppStream.Release> ();

        var releases = component.get_releases ();
        if (releases.length < min_releases) {
            return list;
        }

        releases.sort_with_data ((a, b) => {
            return b.vercmp (a);
        });

        string installed_version = get_version ();

        int start_index = 0;
        int end_index = min_releases;

        if (installed) {
            for (int i = 0; i < releases.length; i++) {
                var release = releases.@get (i);
                unowned string release_version = release.get_version ();
                if (release_version == null) {
                    continue;
                }

                if (AppStream.utils_compare_versions (release_version, installed_version) == 0) {
                    end_index = i.clamp (min_releases, max_releases);
                    break;
                }
            }
        }

        for (int j = start_index; j < end_index; j++) {
            list.add (releases.get (j));
        }

        return list;
    }

    public AppStream.Release? get_newest_release () {
        var releases = component.get_releases ();
        releases.sort_with_data ((a, b) => {
            return b.vercmp (a);
        });

        if (releases.length > 0) {
            return releases[0];
        }

        return null;
    }

    public Pk.Package? find_package () {
        if (component.id == OS_UPDATES_ID || is_local) {
            return null;
        }

        if (pk_package != null) {
            return pk_package;
        }

        try {
            pk_package = AppCenterCore.Client.get_default ().get_app_package (component.get_pkgnames ()[0], 0);
        } catch (Error e) {
            warning (e.message);
            return null;
        }

        return pk_package;
    }
}
