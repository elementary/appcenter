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

namespace AppCenter {
    const string appcenter = N_("About App Center");
    public class AppCenter : Granite.Application {
        construct {
            application_id = "org.pantheon.appcenter";
            flags = ApplicationFlags.FLAGS_NONE;

            program_name = _("App Center");
            app_years = "2015";
            app_icon = Build.DESKTOP_ICON;

            build_data_dir = Build.DATADIR;
            build_pkg_data_dir = Build.PKGDATADIR;
            build_release_name = Build.RELEASE_NAME;
            build_version = Build.VERSION;
            build_version_info = Build.VERSION_INFO;

            app_launcher = "appcentre.desktop";
            main_url = "https://launchpad.net/appcenter";
            bug_url = "https://bugs.launchpad.net/appcenter";
            help_url = "https://answers.launchpad.net/appcenter"; 
            translate_url = "https://translations.launchpad.net/appcenter";
            about_authors = { "Marvin Beckers <beckersmarvin@gmail.com>",
                              "Corentin Noël <corentin@elementary.io>" };
            about_comments = "";
            about_license_type = Gtk.License.GPL_3_0;

            Intl.setlocale (LocaleCategory.ALL, "");
        }

        public override void activate () {
            var window = new MainWindow ();
            this.add_window (window);
        }
    }

    public static int main (string[] args) {
        var application = new AppCenter ();
        return application.run (args);
    }
}
