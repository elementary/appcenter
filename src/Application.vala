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

public class AppCenter.App : Granite.Application {
    const OptionEntry[] appcenter_options =  {
        { "show-updates", 'u', 0, OptionArg.NONE, out show_updates,
        "Display the Installed Panel", null},
        { "silent", 's', 0, OptionArg.NONE, out silent,
        "Run the Application in background", null},
        { null }
    };

    private const int SECONDS_AFTER_NETWORK_UP = 60;

    public static bool show_updates;
    public static bool silent;
    private MainWindow? main_window;

    private uint registration_id = 0;

    construct {
        application_id = "io.elementary.appcenter";
        flags |= ApplicationFlags.HANDLES_OPEN;
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.textdomain (Build.GETTEXT_PACKAGE);

        program_name = _("App Center");
        app_years = "2015-2017";
        app_icon = Build.DESKTOP_ICON;

        build_data_dir = Build.DATADIR;
        build_pkg_data_dir = Build.PKGDATADIR;
        build_release_name = Build.RELEASE_NAME;
        build_version = Build.VERSION;
        build_version_info = Build.VERSION_INFO;

        app_launcher = "io.elementary.appcenter.desktop";
        main_url = "https://elementary.io";
        bug_url = "https://github.com/elementary/appcenter/issues";
        help_url = "https://elementary.io/support";
        translate_url = "https://l10n.elementary.io/projects/appcenter";
        about_authors = { "Corentin Noël <corentin@elementary.io>" };
        about_comments = "";
        about_translators = _("translator-credits");
        about_license_type = Gtk.License.GPL_3_0;
        add_main_option_entries (appcenter_options);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });
        
        var show_updates_action = new SimpleAction ("show-updates", null);
        show_updates_action.activate.connect(() => {
            silent = false;
            show_updates = true;
            activate ();
        });

        var client = AppCenterCore.Client.get_default ();
        client.operation_finished.connect (on_operation_finished);

        if (AppInfo.get_default_for_uri_scheme ("appstream") == null) {
            var appinfo = new DesktopAppInfo (app_launcher);
            try {
                appinfo.set_as_default_for_type ("x-scheme-handler/appstream");
            } catch (Error e) {
                critical ("Unable to set default for the settings scheme: %s", e.message);
            }
        }

        add_action (quit_action);
        add_action (show_updates_action);
        add_accelerator ("<Control>q", "app.quit", null);
    }

    public override void open (File[] files, string hint) {
        activate ();

        var file = files[0];
        if (file == null) {
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
        var client = AppCenterCore.Client.get_default ();
        if (silent) {
            NetworkMonitor.get_default ().network_changed.connect ((available) => {
                schedule_cache_update (!available);
            });

            client.update_cache.begin (true);
            silent = false;
            hold ();
            return;
        }

        if (main_window == null) {
            main_window = new MainWindow (this);

            main_window.homepage_loaded.connect (() => {
                client.update_cache.begin (true);
            });
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
            DBusServer.init ();
            try {
                registration_id = connection.register_object ("/io/elementary/appcenter", DBusServer.get_default ());    
            } catch (Error e) {
                warning (e.message);
            }
        }

        return true;
    }

    public override void dbus_unregister (DBusConnection connection, string object_path) {
        if (registration_id != 0) {
            connection.unregister_object (registration_id);
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
                    // Check if window is focused
                    if (main_window != null) {
                        var win = main_window.get_window ();
                        if (win != null && (win.get_state () & Gdk.WindowState.FOCUSED) != 0) {
                            break;
                        }
                    }

                    var notification = new Notification (_("Application installed"));
                    notification.set_body (_("%s has been successfully installed").printf (package.get_name ()));
                    notification.set_icon (new ThemedIcon ("system-software-install"));
                    notification.set_default_action ("app.open-application");

                    send_notification ("installed", notification);                 
                } else {
                    // Check if permission was denied or the operation was cancelled
                    if (error.matches (IOError.quark (), 19) || error.matches (Pk.ClientError.quark (), 303)) {
                        break;
                    }

                    string body = error.message;
                    if (!body.has_suffix (".")) {
                        body += ".";
                    }

                    var close_button = new Gtk.Button.with_label (_("Close"));

                    var dialog = new MessageDialog (_("There Was An Error Installing %s").printf (package.get_name ()), body, "dialog-error");
                    dialog.add_action_widget (close_button, 0);
                    dialog.show_all ();
                    dialog.run ();
                    dialog.destroy ();
                }

                break;
            default:
                break;
        }
    }    
}

public static int main (string[] args) {
    var application = new AppCenter.App ();
    return application.run (args);
}
