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

    public static bool show_updates;
    public static bool silent;
    MainWindow main_window;
    construct {
        application_id = "org.pantheon.appcenter";
        flags = ApplicationFlags.FLAGS_NONE;
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
    }

    public override void activate () {
        if (silent) {
            silent = false;
            AppCenterCore.Client.get_default ();
            hold ();
            return;
        }

        if (main_window == null) {
            main_window = new MainWindow (this);
            main_window.destroy.connect (() => {
                main_window = null;
            });

            add_window (main_window);
            main_window.show_all ();
            if (show_updates) {
                main_window.go_to_installed ();
            }
        } else {
            AppCenterCore.Client.get_default ().interface_cancellable.reset ();
        }

        main_window.present ();
    }
}

public static int main (string[] args) {
    var application = new AppCenter.App ();
    return application.run (args);
}
