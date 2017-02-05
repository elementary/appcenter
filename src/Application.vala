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

    private static string? link = null;

    public static bool show_updates;
    public static bool silent;
    MainWindow main_window;
    construct {
        application_id = "org.pantheon.appcenter";
        flags |= ApplicationFlags.HANDLES_OPEN;
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.textdomain (Build.GETTEXT_PACKAGE);

        program_name = _("App Center");
        app_years = "2015-2016";
        app_icon = Build.DESKTOP_ICON;

        build_data_dir = Build.DATADIR;
        build_pkg_data_dir = Build.PKGDATADIR;
        build_release_name = Build.RELEASE_NAME;
        build_version = Build.VERSION;
        build_version_info = Build.VERSION_INFO;

        app_launcher = "org.pantheon.appcenter.desktop";
        main_url = "https://launchpad.net/appcenter";
        bug_url = "https://bugs.launchpad.net/appcenter";
        help_url = "https://answers.launchpad.net/appcenter";
        translate_url = "https://translations.launchpad.net/appcenter";
        about_authors = { "Marvin Beckers <beckersmarvin@gmail.com>",
                          "Corentin Noël <corentin@elementary.io>" };
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

        if (AppInfo.get_default_for_uri_scheme ("appstream") == null) {
            var appinfo = new DesktopAppInfo (app_launcher);
            try {
                appinfo.set_as_default_for_type ("x-scheme-handler/appstream");
            } catch (Error e) {
                critical ("Unable to set default for the settings scheme: %s", e.message);
            }
        }

        add_action (quit_action);
        add_accelerator ("<Control>q", "app.quit", null);
    }

    public override void open (File[] files, string hint) {
        var file = files[0];
        if (file == null) {
            return;
        }

        if (file.has_uri_scheme ("appstream")) {
            link = file.get_uri ().replace ("appstream://", "");
            if (link.has_suffix ("/")) {
                link = link.substring (0, link.last_index_of_char ('/'));
            }
        }

        activate ();
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
            client.update_cache.begin (true);

            main_window = new MainWindow (this);
            main_window.destroy.connect (() => {
                main_window = null;
            });

            add_window (main_window);
            main_window.show_all ();
            if (show_updates) {
                main_window.go_to_installed ();
            }
        }

        if (link != null) {
            var package = client.get_package_for_id (link);
            if (package != null) {
                main_window.show_package (package);
            } else {
                warning (_("Specified link '%s' could not be found, going back to the main panel").printf (link));
            }
        }

        main_window.present ();
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
}

public static int main (string[] args) {
    var application = new AppCenter.App ();
    return application.run (args);
}
