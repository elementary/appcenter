/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
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
    private MainWindow? main_window;

    private uint registration_id = 0;

    private SearchProvider search_provider;
    private uint search_provider_id = 0;

    public static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.appcenter.settings");
    }

    construct {
        application_id = Build.PROJECT_NAME;
        flags |= ApplicationFlags.HANDLES_OPEN;
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.textdomain (Build.GETTEXT_PACKAGE);
        Intl.bindtextdomain (Build.GETTEXT_PACKAGE, Build.LOCALEDIR);
        Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");

        add_main_option_entries (APPCENTER_OPTIONS);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });

        var show_updates_action = new SimpleAction ("show-updates", null);
        show_updates_action.activate.connect (() => {
            silent = false;
            show_updates = true;
            activate ();
        });

        var client = AppCenterCore.Client.get_default ();
        client.operation_finished.connect (on_operation_finished);
        client.cache_update_failed.connect (on_cache_update_failed);
        client.installed_apps_changed.connect (on_updates_available);

        if (AppInfo.get_default_for_uri_scheme ("appstream") == null) {
            var appinfo = new DesktopAppInfo (application_id + ".desktop");
            try {
                appinfo.set_as_default_for_type ("x-scheme-handler/appstream");
            } catch (Error e) {
                critical ("Unable to set default for the settings scheme: %s", e.message);
            }
        }

        add_action (quit_action);
        add_action (show_updates_action);
        set_accels_for_action ("app.quit", {"<Control>q"});

        search_provider = new SearchProvider ();
    }

    public override void open (File[] files, string hint) {
        activate ();

        var file = files[0];
        if (file == null) {
            return;
        }

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

        var client = AppCenterCore.Client.get_default ();
        var package = client.get_package_for_component_id (link);
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

    public override void activate () {
        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("io/elementary/appcenter/application.css");
        Gtk.StyleContext.add_provider_for_screen (
          Gdk.Screen.get_default (),
          provider,
          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var fallback_provider = new Gtk.CssProvider ();
        fallback_provider.load_from_resource ("io/elementary/appcenter/fallback.css");
        Gtk.StyleContext.add_provider_for_screen (
          Gdk.Screen.get_default (),
          fallback_provider,
          Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK
        );

        var client = AppCenterCore.Client.get_default ();

#if PACKAGEKIT_BACKEND
        if (fake_update_packages != null) {
            AppCenterCore.PackageKitBackend.get_default ().fake_packages = fake_update_packages;
        }
#endif

        if (silent) {
            NetworkMonitor.get_default ().network_changed.connect ((available) => {
                schedule_cache_update (!available);
            });

            // Don't force a cache refresh for the silent daemon, it'll run if it was >24 hours since the last one
            client.update_cache.begin (false);
            silent = false;
            hold ();
            return;
        }

#if PACKAGEKIT_BACKEND
        if (local_path != null) {
            var file = File.new_for_commandline_arg (local_path);

            try {
                local_package = AppCenterCore.PackageKitBackend.get_default ().add_local_component_file (file);
            } catch (Error e) {
                warning ("Failed to load local AppStream XML file: %s", e.message);
            }
        }
#endif

        if (main_window == null) {
            main_window = new MainWindow (this);


            // Force a cache refresh when the window opens, so we get new apps
#if HOMEPAGE
            main_window.homepage_loaded.connect (() => {
                client.update_cache.begin (true);
            });
#else
            client.update_cache.begin (true);
#endif

            main_window.destroy.connect (() => {
                main_window = null;
            });

            add_window (main_window);
            main_window.show_all ();
            if (show_updates) {
                main_window.go_to_installed ();
            }
        } else {
            if (show_updates) {
                main_window.go_to_installed ();
                main_window.present ();
            }
        }

        main_window.present ();
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
        var client = AppCenterCore.Client.get_default ();

        if (cache_update_timeout_id > 0) {
            Source.remove (cache_update_timeout_id);
            cache_update_timeout_id = 0;
        }

        if (cancel) {
            client.cancel_updates (true); // Also stops timeouts.
            return;
        } else {
            cache_update_timeout_id = Timeout.add_seconds (SECONDS_AFTER_NETWORK_UP, () => {
                client.update_cache.begin ();
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
                        if (main_window != null) {
                            var win = main_window.get_window ();
                            if (win != null && (win.get_state () & Gdk.WindowState.FOCUSED) != 0) {
                                main_window.send_installed_toast (package);

                                break;
                            }
                        }

                        var notification = new Notification (_("The app has been installed"));
                        notification.set_body (_("“%s” has been installed").printf (package.get_name ()));
                        notification.set_icon (new ThemedIcon ("process-completed"));
                        notification.set_default_action ("app.open-application");

                        send_notification ("installed", notification);
                    }
                } else {
                    // Check if permission was denied or the operation was cancelled
                    if (error.matches (IOError.quark (), 19) || error.matches (Pk.ClientError.quark (), 303)) {
                        break;
                    }

                    var dialog = new InstallFailDialog (package, error);

                    dialog.show_all ();
                    dialog.run ();
                    dialog.destroy ();
                }

                break;
            default:
                break;
        }
    }

    public void on_updates_available () {
        var client = AppCenterCore.Client.get_default ();
        Idle.add (() => {
            if (main_window != null) {
                main_window.show_update_badge (client.updates_number);
            }

            return GLib.Source.REMOVE;
        });
    }

    private void on_cache_update_failed (Error error) {
        if (main_window == null) {
            return;
        }

        if (update_fail_dialog == null) {
            update_fail_dialog = new UpdateFailDialog (format_error_message (error.message));
            update_fail_dialog.transient_for = main_window;

            update_fail_dialog.destroy.connect (() => {
                update_fail_dialog = null;
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
