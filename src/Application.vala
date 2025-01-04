/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 *                         2015 Marvin Beckers <beckersmarvin@gmail.com>
 */

public class AppCenter.App : Gtk.Application {
    public const OptionEntry[] APPCENTER_OPTIONS = {
        { "show-updates", 'u', 0, OptionArg.NONE, out show_updates,
        "Display the Installed Panel", null},
        { "silent", 's', 0, OptionArg.NONE, out silent,
        "Run the Application in background", null},
        { "load-local", 'l', 0, OptionArg.FILENAME, out local_path,
        "Add a local AppStream XML file to the package list", "FILENAME" },
        { "fake-package-update", 'f', 0, OptionArg.STRING_ARRAY, out fake_update_packages,
        "Add the package name to update results so that it is shown as an update", "PACKAGES…" },
        { null }
    };

    private const int SECONDS_AFTER_NETWORK_UP = 60;

    public static bool show_updates;
    public static bool silent;
    public static string? local_path;
    public static AppCenterCore.Package? local_package;

    // Add "AppCenter" to the translation catalog
    public const string APPCENTER = N_("AppCenter");

    [CCode (array_length = false, array_null_terminated = true)]
    public static string[]? fake_update_packages = null;
    private Granite.MessageDialog? update_fail_dialog = null;

    private uint registration_id = 0;

    private SearchProvider search_provider;
    private uint search_provider_id = 0;

    public static GLib.Settings settings;

    public static SimpleAction refresh_action;
    public static SimpleAction repair_action;

    private bool first_activation = true;

    static construct {
        settings = new GLib.Settings ("io.elementary.appcenter.settings");
    }

    construct {
        application_id = Build.PROJECT_NAME;
        flags |= HANDLES_OPEN | ALLOW_REPLACEMENT;
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.textdomain (Build.GETTEXT_PACKAGE);
        Intl.bindtextdomain (Build.GETTEXT_PACKAGE, Build.LOCALEDIR);
        Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");

        add_main_option_entries (APPCENTER_OPTIONS);

        search_provider = new SearchProvider ();
    }

    public override void open (File[] files, string hint) {
        activate ();

        var file = files[0];
        if (file == null) {
            return;
        }

        var main_window = (MainWindow) active_window;

        if (file.has_uri_scheme ("type")) {
            string? mimetype = mimetype_from_file (file);
            if (mimetype != null) {
                main_window.search (mimetype, true);
            } else {
                info (_("Could not parse the media type %s").printf (mimetype));
            }

            return;
        }

        if (!file.has_uri_scheme ("appstream")) {
            return;
        }

        string link = file.get_uri ().replace ("appstream://", "");
        if (link.has_suffix ("/")) {
            link = link.substring (0, link.last_index_of_char ('/'));
        }

        var package = AppCenterCore.FlatpakBackend.get_default ().get_package_for_component_id (link);
        if (package != null) {
            main_window.show_package (package);
        } else {
            info (_("Specified link '%s' could not be found, searching instead").printf (link));
            string? search_term = Uri.unescape_string (link);
            if (search_term != null) {
                main_window.search (search_term);
            }
        }
    }

    protected override void startup () {
        base.startup ();

        Granite.init ();

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (active_window != null) {
                active_window.close ();
            }
        });

        var show_updates_action = new SimpleAction ("show-updates", null);
        show_updates_action.activate.connect (() => {
            silent = false;
            show_updates = true;
            activate ();
        });

        unowned var flatpak_backend = AppCenterCore.FlatpakBackend.get_default ();
        flatpak_backend.operation_finished.connect (on_operation_finished);

        var update_manager = AppCenterCore.UpdateManager.get_default ();
        update_manager.cache_update_failed.connect (on_cache_update_failed);

        refresh_action = new SimpleAction ("refresh", null);
        refresh_action.set_enabled (!Utils.is_running_in_guest_session ());
        refresh_action.activate.connect (() => {
            update_manager.update_cache.begin (true);
        });

        repair_action = new SimpleAction ("repair", null);
        repair_action.activate.connect (() => {
            flatpak_backend.repair.begin (null, (obj, res) => {
                bool success = false;
                string message = "";
                try {
                    success = flatpak_backend.repair.end (res);
                } catch (Error e) {
                    success = false;
                    message = e.message;
                }

                if (!success) {
                    var fail_dialog = new RepairFailDialog (message) {
                        transient_for = active_window
                    };
                    fail_dialog.present ();
                }
            });
        });

        add_action (quit_action);
        add_action (show_updates_action);
        add_action (refresh_action);
        add_action (repair_action);
        set_accels_for_action ("app.quit", {"<Control>q"});
        set_accels_for_action ("app.refresh", {"<Control>r"});

        if (AppInfo.get_default_for_uri_scheme ("appstream") == null) {
            var appinfo = new DesktopAppInfo (application_id + ".desktop");
            try {
                appinfo.set_as_default_for_type ("x-scheme-handler/appstream");
            } catch (Error e) {
                critical ("Unable to set default for the settings scheme: %s", e.message);
            }
        }
    }

    public override void activate () {
        unowned var update_manager = AppCenterCore.UpdateManager.get_default ();

        if (first_activation) {
            first_activation = false;
            hold ();
        }

        if (silent) {
            request_background.begin ();

            NetworkMonitor.get_default ().network_changed.connect ((available) => {
                schedule_cache_update (!available);
            });

            // Don't force a cache refresh for the silent daemon, it'll run if it was >24 hours since the last one
            update_manager.update_cache.begin (false);
            silent = false;
            return;
        }

        if (active_window == null) {
            // Force a Flatpak cache refresh when the window is created, so we get new apps
            update_manager.update_cache.begin (true);

            var main_window = new MainWindow (this);
            add_window (main_window);

            /*
            * This is very finicky. Bind size after present else set_titlebar gives us bad sizes
            * Set maximize after height/width else window is min size on unmaximize
            * Bind maximize as SET else get get bad sizes
            */
            settings.bind ("window-height", main_window, "default-height", SettingsBindFlags.DEFAULT);
            settings.bind ("window-width", main_window, "default-width", SettingsBindFlags.DEFAULT);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            settings.bind ("window-maximized", main_window, "maximized", SettingsBindFlags.SET);
        }

        if (show_updates) {
            ((MainWindow) active_window).go_to_installed ();
            show_updates = false;
        }

        active_window.present ();
    }

    public async void request_background () {
        var portal = new Xdp.Portal ();

        Xdp.Parent? parent = active_window != null ? Xdp.parent_new_gtk (active_window) : null;

        var command = new GenericArray<weak string> ();
        command.add ("io.elementary.appcenter");
        command.add ("--silent");

        try {
            if (!yield portal.request_background (
                parent,
                _("AppCenter will automatically start when this device turns on and run when its window is closed so that it can automatically check and install updates."),
                (owned) command,
                Xdp.BackgroundFlags.AUTOSTART,
                null
            )) {
                release ();
            }
        } catch (Error e) {
            if (e is IOError.CANCELLED) {
                debug ("Request for autostart and background permissions denied: %s", e.message);
                release ();
            } else {
                warning ("Failed to request autostart and background permissions: %s", e.message);
            }
        }
    }

    public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
        base.dbus_register (connection, object_path);

        if (silent) {
            try {
                registration_id = connection.register_object ("/io/elementary/appcenter", DBusServer.get_default ());
            } catch (Error e) {
                warning (e.message);
            }

            try {
                search_provider_id = connection.register_object ("/io/elementary/appcenter/SearchProvider", search_provider);
            } catch (Error e) {
                warning (e.message);
            }
        }

        return true;
    }

    public override void dbus_unregister (DBusConnection connection, string object_path) {
        if (registration_id != 0) {
            connection.unregister_object (registration_id);
            registration_id = 0;
        }

        if (search_provider_id != 0) {
            connection.unregister_object (search_provider_id);
            search_provider_id = 0;
        }

        base.dbus_unregister (connection, object_path);
    }

    private uint cache_update_timeout_id = 0;
    private void schedule_cache_update (bool cancel = false) {
        unowned var update_manager = AppCenterCore.UpdateManager.get_default ();

        if (cache_update_timeout_id > 0) {
            Source.remove (cache_update_timeout_id);
            cache_update_timeout_id = 0;
        }

        if (cancel) {
            update_manager.cancel_updates (true); // Also stops timeouts.
            return;
        } else {
            cache_update_timeout_id = Timeout.add_seconds (SECONDS_AFTER_NETWORK_UP, () => {
                update_manager.update_cache.begin ();
                cache_update_timeout_id = 0;
                return false;
            });
        }
    }

    private void on_operation_finished (AppCenterCore.Package package, AppCenterCore.Package.State operation, Error? error) {
        switch (operation) {
            case AppCenterCore.Package.State.INSTALLING:
                if (error == null) {
                    if (package.get_can_launch ()) {
                        // Check if window is focused
                        if (active_window != null && active_window.is_active) {
                            ((MainWindow) active_window).send_installed_toast (package);
                            break;
                        }

                        var notification = new Notification (_("The app has been installed"));
                        notification.set_body (_("“%s” has been installed").printf (package.get_name ()));
                        notification.set_icon (new ThemedIcon ("process-completed"));
                        notification.set_default_action ("app.open-application");

                        send_notification ("installed", notification);
                    }
                } else {
                    // Check if permission was denied or the operation was cancelled
                    if (error.matches (IOError.quark (), 19)) {
                        break;
                    }

                    var dialog = new InstallFailDialog (package, (owned) error.message);
                    dialog.present ();
                }

                break;
            default:
                break;
        }
    }

    private void on_cache_update_failed (Error error) {
        if (active_window == null) {
            return;
        }

        if (update_fail_dialog == null) {
            update_fail_dialog = new UpdateFailDialog (format_error_message (error.message)) {
                transient_for = active_window
            };

            update_fail_dialog.close_request.connect (() => {
                update_fail_dialog = null;
                return Gdk.EVENT_PROPAGATE;
            });
        }

        update_fail_dialog.present ();
    }

    private static string format_error_message (string message) {
        string msg = message.strip ();
        if (msg.has_suffix (".")) {
            msg = msg.substring (0, msg.length - 1);
        }

        return msg;
    }

    private static string? mimetype_from_file (File file) {
        string uri = file.get_uri ();
        string[] tokens = uri.split (Path.DIR_SEPARATOR_S);
        if (tokens.length < 2) {
            return null;
        }

        return "%s/%s".printf (tokens[tokens.length - 2], tokens[tokens.length - 1]);
    }

    public static void add_paid_app (string id) {
        var paid_apps = settings.get_strv ("paid-apps");
        if (!(id in paid_apps)) {
            paid_apps += id;
            settings.set_strv ("paid-apps", paid_apps);
        }
    }
}

public static int main (string[] args) {
    var application = new AppCenter.App ();
    return application.run (args);
}
