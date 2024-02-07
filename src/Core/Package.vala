/*
 * Copyright 2014–2021 elementary, Inc. (https://elementary.io)
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

public errordomain PackageUninstallError {
    APP_STATE_NOT_INSTALLED
}

public class AppCenterCore.PackageDetails : Object {
    public string? name { get; set; }
    public string? description { get; set; }
    public string? summary { get; set; }
    public string? version { get; set; }
}

public enum RuntimeStatus {
    UP_TO_DATE,
    END_OF_LIFE,
    MAJOR_OUTDATED,
    MINOR_OUTDATED,
    UNSTABLE;
}

public class AppCenterCore.Package : Object {
    public const string APPCENTER_PACKAGE_ORIGIN = "appcenter";
    private const string ELEMENTARY_STABLE_PACKAGE_ORIGIN = "elementary-stable-jammy-main";

    public PermissionsFlags permissions_flags { get; set; default = PermissionsFlags.UNKNOWN; }
    public RuntimeStatus runtime_status { get; set; default = RuntimeStatus.UP_TO_DATE; }

    /* Note: These are just a stopgap, and are not a replacement for a more
     * fleshed out parental control system. We assume any of these "moderate"
     * or above is considered explicit for our naive warning.
     *
     * See https://hughsie.github.io/oars/generate.html for ratings.
     */
    private const string[] EXPLICIT_TAGS = {
        "violence-realistic",
        "violence-bloodshed",
        "violence-sexual",
        "drugs-narcotics",
        "sex-nudity",
        "sex-themes",
        "sex-prostitution",
        "language-profanity",
        "language-humor",
        "language-discrimination"
    };

    public signal void changing (bool is_changing);
    /**
     * This signal is likely to be fired from a non-main thread. Ensure any UI
     * logic driven from this runs on the GTK thread
     */
    public signal void info_changed (ChangeInformation.Status status);

    public enum State {
        NOT_INSTALLED,
        INSTALLED,
        INSTALLING,
        UPDATE_AVAILABLE,
        UPDATING,
        REMOVING
    }

    [Flags]
    public enum PermissionsFlags {
        AUTOSTART,
        DEVICES,
        DOWNLOADS_FULL,
        DOWNLOADS_READ,
        ESCAPE_SANDBOX,
        FILESYSTEM_FULL,
        FILESYSTEM_OTHER,
        FILESYSTEM_READ,
        HOME_FULL,
        HOME_READ,
        LOCATION,
        NETWORK,
        NONE,
        NOTIFICATIONS,
        SESSION_BUS,
        SETTINGS,
        SYSTEM_BUS,
        UNKNOWN,
        X11
    }

    public const string OS_UPDATES_ID = "xxx-os-updates";
    public const string RUNTIME_UPDATES_ID = "xxx-runtime-updates";
    public const string LOCAL_ID_SUFFIX = ".appcenter-local";
    public const string DEFAULT_PRICE_DOLLARS = "1";

    public AppStream.Component component { get; protected set; }
    public ChangeInformation change_information { public get; private set; }
    public GLib.Cancellable action_cancellable { public get; private set; }
    public State state { public get; private set; default = State.NOT_INSTALLED; }

    public Backend backend { public get; construct; }

    public double progress {
        get {
            return change_information.progress;
        }
    }

    private bool _installed = false;
    public bool installed {
        get {
            if (is_os_updates || is_runtime_updates) {
                return true;
            }

            return _installed;
        }
    }

    public void mark_installed () {
        _installed = true;
        update_state ();
    }

    public void clear_installed () {
        _installed = false;
        update_state ();
    }

    public bool update_available {
        get {
            return state == State.UPDATE_AVAILABLE;
        }
    }

    /**
     * The component ID of the package with the .desktop suffix removed if it exists.
     * This is used for comparing two packages to see if they have a matching ID
     */
    private string? _component_id = null;
    public string normalized_component_id {
        get {
            if (_component_id != null) {
                return _component_id;
            }

            _component_id = component.id;
            if (_component_id.has_suffix (".desktop")) {
                // ".desktop" is always 8 bytes in UTF-8 so we can just chop 8 bytes off the end
                _component_id = _component_id.substring (0, _component_id.length - 8);
            }

            return _component_id;
        }
    }

    public bool should_pay {
        get {
            if (component.get_origin () != APPCENTER_PACKAGE_ORIGIN) {
                return false;
            }

            if (get_payments_key () == null || get_suggested_amount () == "0") {
                return false;
            }

            if (component.get_id () in AppCenter.App.settings.get_strv ("paid-apps")) {
                return false;
            }

            var newest_release = get_newest_release ();
            if (newest_release != null && newest_release.get_urgency () == AppStream.UrgencyKind.CRITICAL) {
                return false;
            }

            return true;
        }
    }

    public bool is_updating {
        get {
            return state == State.UPDATING;
        }
    }

    public bool changes_finished {
        get {
            return change_information.status == ChangeInformation.Status.FINISHED;
        }
    }

    public bool is_os_updates {
        get {
            return component.id == OS_UPDATES_ID;
        }
    }

    public bool is_runtime_updates {
        get {
            return component.id == RUNTIME_UPDATES_ID;
        }
    }

    public AppStream.ComponentKind kind {
        get {
            return component.get_kind ();
        }
    }

    public bool is_local {
        get {
            return component.get_id ().has_suffix (LOCAL_ID_SUFFIX);
        }
    }

    public bool is_shareable {
        get {
            return is_native && component.get_kind () != AppStream.ComponentKind.DRIVER && !is_os_updates && !is_runtime_updates;
        }
    }

    public bool is_native {
        get {
            switch (component.get_origin ()) {
                case APPCENTER_PACKAGE_ORIGIN:
                case ELEMENTARY_STABLE_PACKAGE_ORIGIN:
                    return true;
                default:
                    return false;
            }
        }
    }

    public bool is_compulsory {
        get {
            unowned string? _current = Environment.get_variable ("XDG_SESSION_DESKTOP");
            if (_current == null) {
                return false;
            }

            string current = _current.down ();
            unowned GenericArray<string> compulsory = component.get_compulsory_for_desktops ();
            for (int i = 0; i < compulsory.length; i++) {
                if (current == compulsory[i].down ()) {
                    return true;
                }
            }

            return false;
        }
    }

    private bool _explicit = false;
    private bool _check_explicit = true;
    public bool is_explicit {
        get {
            if (_check_explicit) {
                _check_explicit = false;
                var ratings = component.get_content_ratings ();
                for (int i = 0; i < ratings.length; i++) {
                    var rating = ratings[i];

                    foreach (string tag in EXPLICIT_TAGS) {
                        var rating_value = rating.get_value (tag);
                        if (rating_value > AppStream.ContentRatingValue.MILD) {
                            _explicit = true;
                            return _explicit;
                        }
                    }
                }
            }

            return _explicit;
        }
    }

    public bool is_flatpak {
        get {
            return (backend is FlatpakBackend)
                || change_information.updatable_packages.contains (FlatpakBackend.get_default ());
        }
    }

    private string? _author = null;
    public string author {
        get {
            if (_author != null) {
                return _author;
            }

#if HAS_APPSTREAM_1_0
            _author = component.get_developer ().get_name ();
#else
            _author = component.developer_name;
#endif

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

    public Gee.Collection<Package> origin_packages {
        owned get {
            return BackendAggregator.get_default ().get_packages_for_component_id (component.get_id ());
        }
    }

    public bool has_multiple_origins {
        get {
            return origin_packages.size > 1;
        }
    }

    public string origin_description {
        owned get {
            unowned string origin = component.get_origin ();
            if (backend is FlatpakBackend) {
                var fp_package = this as FlatpakPackage;
                if (fp_package == null) {
                    return origin;
                }

                return fp_package.remote_title;
            }
#if PACKAGEKIT_BACKEND
            else if (backend is PackageKitBackend) {
                if (origin == APPCENTER_PACKAGE_ORIGIN) {
                    return _("AppCenter");
                } else if (origin == ELEMENTARY_STABLE_PACKAGE_ORIGIN) {
                    return _("elementary Updates");
                } else if (origin.has_prefix ("ubuntu-")) {
                    return _("Ubuntu (non-curated)");
                }
            }
#endif
#if UBUNTU_DRIVERS_BACKEND
            else if (backend is UbuntuDriversBackend) {
                return _("Ubuntu Drivers");
            }
#endif

            return _("Unknown Origin (non-curated)");
        }
    }

    public int origin_score {
        get {
            int score = 0;

            if (installed) {
                score += 10;
            }

            if (is_native) {
                score += 5;
            }

            if (is_flatpak) {
                score++;

                var fp_package = this as FlatpakPackage;
                if (fp_package != null && fp_package.installation == FlatpakBackend.user_installation) {
                    score++;
                }
            }

            return score;
        }
    }

    public string hash {
        owned get {
            string key = "";
            if (backend is FlatpakBackend) {
                var fp_package = this as FlatpakPackage;
                if (fp_package.installation != null && fp_package.installation == FlatpakBackend.system_installation) {
                    key += "system/";
                } else {
                    key += "user/";
                }
            }

            key += component.get_origin () + "/";
            key += component.get_id ();

            return key;
        }
    }

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

    private PackageDetails? backend_details = null;
    private AppInfo? app_info;
    private bool app_info_retrieved = false;

    construct {
        change_information = new ChangeInformation ();
        change_information.status_changed.connect (() => info_changed (change_information.status));

        action_cancellable = new GLib.Cancellable ();
    }

    public Package (Backend backend, AppStream.Component component) {
        Object (backend: backend, component: component);
    }

    public void replace_component (AppStream.Component component) {
        name = null;
        description = null;
        summary = null;
        color_primary = null;
        color_primary_text = null;
        payments_key = null;
        suggested_amount = null;
        _author = null;
        _author_title = null;
        backend_details = null;

#if PACKAGEKIT_BACKEND
        // The version on a PackageKit package comes from the package not AppStream, so only reset the version
        // on other backends
        if (!(backend is PackageKitBackend)) {
            _latest_version = null;
        }
#endif

        this.component = component;
    }

    public void update_state () {
        State new_state;

        if (installed) {
            if (change_information.has_changes ()) {
                new_state = State.UPDATE_AVAILABLE;
            } else {
                new_state = State.INSTALLED;
            }
        } else {
            new_state = State.NOT_INSTALLED;
        }

        // Only trigger a notify if the state has changed, quite a lot of things listen to this
        if (state != new_state) {
            state = new_state;
        }
    }

    /**
     * Instructs the backend to update this package
     *
     * @refresh_updates_after: Whether to run the check for updates (and update the badges etc...) after
     * this method succeeds. This is fine after updating a single package, but for efficiency, it's better to
     * do this only once at the end of updating a batch of packages, so this should be set to false if updating
     * multiple packages in a loop.
     *
     */
    public async bool update (bool refresh_updates_after = true) throws GLib.Error {
        if (state != State.UPDATE_AVAILABLE) {
            return false;
        }

        var success = yield perform_operation (State.UPDATING, State.INSTALLED, State.UPDATE_AVAILABLE);
        if (success && refresh_updates_after) {
            unowned Client client = Client.get_default ();
            yield client.refresh_updates ();
        }

        return success;
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

    public async bool uninstall () throws Error {
        // We possibly don't know if this package is installed or not yet, so trigger that check first
        _installed = yield backend.is_package_installed (this);

        update_state ();

        if (state == State.INSTALLED || state == State.UPDATE_AVAILABLE) {
            try {
                return yield perform_operation (State.REMOVING, State.NOT_INSTALLED, state);
            } catch (Error e) {
                throw e;
            }
        }

        throw new PackageUninstallError.APP_STATE_NOT_INSTALLED (_("Application state not set as installed in AppCenter for package: %s").printf (get_name ()));
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
        bool success = false;
        prepare_package_operation (performing);
        try {
            success = yield perform_package_operation ();
        } catch (GLib.Error e) {
            warning ("Operation failed for package %s - %s", get_name (), e.message);
            throw e;
        } finally {
            clean_up_package_operation (success, after_success, after_fail);
        }

        return success;
    }

    private void prepare_package_operation (State initial_state) {
        changing (true);

        action_cancellable.reset ();
        change_information.start ();
        state = initial_state;
    }

    private async bool perform_package_operation () throws GLib.Error {
        var client = AppCenterCore.Client.get_default ();

        switch (state) {
            case State.UPDATING:
                var success = yield backend.update_package (this, change_information, action_cancellable);
                if (success) {
                    change_information.clear_update_info ();
                    update_state ();
                }

                return success;
            case State.INSTALLING:
                var success = yield backend.install_package (this, change_information, action_cancellable);
                _installed = success;
                update_state ();
                return success;
            case State.REMOVING:
                var success = yield backend.remove_package (this, change_information, action_cancellable);
                _installed = !success;
                update_state ();
                yield client.refresh_updates ();
                return success;
            default:
                return false;
        }
    }

    private void clean_up_package_operation (bool success, State success_state, State fail_state) {
        changing (false);

        if (success) {
            change_information.complete ();
            state = success_state;
        } else {
            state = fail_state;
            change_information.cancel ();
        }
    }

    private string? name = null;
    public string? get_name () {
        if (name != null) {
            return name;
        }

        name = component.get_name ();
        if (name == null) {
            if (backend_details == null) {
                populate_backend_details_sync ();
            }

            name = backend_details.name;
        }

        name = Utils.unescape_markup (name);

        return name;
    }

    public void set_name (string? new_name) {
        name = Utils.unescape_markup (new_name);
    }

    public string? get_description () {
        if (description == null) {
            description = component.get_description ();

            if (description == null) {
                if (backend_details == null) {
                    populate_backend_details_sync ();
                }

                description = backend_details.description;
            }

            if (description == null) {
                return null;
            }

            try {
                // Condense double spaces
                var space_regex = new Regex ("\\s+");
                description = space_regex.replace (description, description.length, 0, " ");
            } catch (Error e) {
               warning ("Failed to condense spaces: %s", e.message);
            }

            try {
#if HAS_APPSTREAM_1_0
                description = AppStream.markup_convert (description, TEXT);
#else
                description = AppStream.markup_convert_simple (description);
#endif
            } catch (Error e) {
                warning ("Failed to convert description to markup: %s", e.message);
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
            if (backend_details == null) {
                populate_backend_details_sync ();
            }

            summary = backend_details.summary;
        }

        return summary;
    }

    public void set_summary (string? new_summary) {
        summary = new_summary;
    }

    public string get_progress_description () {
        return change_information.status_description;
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

                case AppStream.IconKind.UNKNOWN:
                    warning ("'%s' is an unknown kind of AppStream icon", _icon.get_name ());
                    break;
            }
        }

        if (icon == null) {
            switch (component.get_kind ()) {
                case AppStream.ComponentKind.ADDON:
                    icon = new ThemedIcon ("extension");
                    break;
                case AppStream.ComponentKind.FONT:
                    icon = new ThemedIcon ("font-x-generic");
                    break;
                case AppStream.ComponentKind.ICON_THEME:
                    icon = new ThemedIcon ("preferences-desktop-theme");
                    break;
                case AppStream.ComponentKind.CODEC:
                case AppStream.ComponentKind.CONSOLE_APP:
                case AppStream.ComponentKind.DESKTOP_APP:
                case AppStream.ComponentKind.DRIVER:
                case AppStream.ComponentKind.FIRMWARE:
                case AppStream.ComponentKind.GENERIC:

                case AppStream.ComponentKind.INPUT_METHOD: //ComponentKind.INPUTMETHOD is deprecated has same value so cannot be included
                case AppStream.ComponentKind.LOCALIZATION:
                case AppStream.ComponentKind.OPERATING_SYSTEM:
                case AppStream.ComponentKind.REPOSITORY:
                case AppStream.ComponentKind.RUNTIME:
                case AppStream.ComponentKind.SERVICE:
                case AppStream.ComponentKind.UNKNOWN:
                case AppStream.ComponentKind.WEB_APP:
                    debug ("component kind not handled %s", component.get_kind ().to_string ());
                    icon = new ThemedIcon ("application-default-icon");
                    break;
            }
        }

        return icon;
    }

    public Package? get_plugin_host_package () {
        var extends = component.get_extends ();

        if (extends == null || extends.length < 1) {
            return null;
        }

        for (int i = 0; i < extends.length; i++) {
            var package = backend.get_package_for_component_id (extends[i]);
            if (package != null) {
                return package;
            }
        }

        return null;
    }

    public string? get_version () {
        if (latest_version != null) {
            return latest_version;
        }

        if (backend_details == null) {
            populate_backend_details_sync ();
        }

        if (backend_details.version != null) {
            latest_version = backend_details.version;
        }

        return latest_version;
    }

    public string? get_color_primary () {
        if (color_primary != null) {
            return color_primary;
        } else {
            var branding = component.get_branding ();
            if (branding != null) {
                color_primary = branding.get_color (AppStream.ColorKind.PRIMARY, AppStream.ColorSchemeKind.UNKNOWN);
            }

            if (color_primary == null) {
                color_primary = component.get_custom_value ("x-appcenter-color-primary");
            }

            return color_primary;
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
        if (is_os_updates || is_runtime_updates) {
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

        if (is_compulsory) {
            return false;
        }

        var launchable = component.get_launchable (AppStream.LaunchableKind.DESKTOP_ID);
        if (launchable != null) {
            var launchables = launchable.get_entries ();
            for (int i = 0; i < launchables.length; i++) {
                app_info = new DesktopAppInfo (launchables[i]);
                // A bit strange in Vala, but the DesktopAppInfo constructor does indeed return null if the desktop
                // file isn't found: https://valadoc.org/gio-unix-2.0/GLib.DesktopAppInfo.DesktopAppInfo.html
                if (app_info != null) {
                    break;
                }
            }
        }

        if (app_info != null) {
            app_info_retrieved = true;
            return true;
        }

        // Fallback to trying Appstream ID as desktop ID for applications that haven't updated to the newest spec yet
        string? desktop_id = component.id;
        if (desktop_id != null) {
            app_info = new DesktopAppInfo (desktop_id);
        }

        app_info_retrieved = true;
        return app_info != null;
    }

    public AppStream.Release? get_newest_release () {
#if HAS_APPSTREAM_1_0
        var releases = component.get_releases_plain ().get_entries ();
#else
        var releases = component.get_releases ();
#endif
        releases.sort_with_data ((a, b) => {
            if (a.get_version () == null || b.get_version () == null) {
                if (a.get_version () != null) {
                    return -1;
                } else if (b.get_version () != null) {
                    return 1;
                } else {
                    return 0;
                }
            }

            return b.vercmp (a);
        });

        if (releases.length > 0) {
            return releases[0];
        }

        return null;
    }

    public async uint64 get_download_size_including_deps () {
        uint64 size = 0;
        try {
            size = yield backend.get_download_size (this, null);
        } catch (Error e) {
            warning ("Error getting download size: %s", e.message);
        }

        return size;
    }

    private void populate_backend_details_sync () {
        if (is_os_updates || is_runtime_updates || is_local) {
            backend_details = new PackageDetails ();
            return;
        }

        var loop = new MainLoop ();
        PackageDetails? result = null;
        backend.get_package_details.begin (this, (obj, res) => {
            try {
                result = backend.get_package_details.end (res);
            } catch (Error e) {
                warning (e.message);
            } finally {
                loop.quit ();
            }
        });

        loop.run ();
        backend_details = result;
        if (backend_details == null) {
            backend_details = new PackageDetails ();
        }
    }
}
