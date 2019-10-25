/*
 * Copyright (c) 2019 elementary, Inc. (https://elementary.io)
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
 */

public class AppCenter.Widgets.NonCuratedWarningDialog : Granite.MessageDialog {
    public string app_name { get; construct set; }

    public NonCuratedWarningDialog (string _app_name) {
        Object (
            app_name: _app_name,
            image_icon: new ThemedIcon ("dialog-warning"),
            title: _("Non-Curated Warning")
        );
    }

    construct {
        primary_text = _("“%s” is not curated").printf (app_name);
        secondary_text = _("This app is not distributed or updated by elementary, and neither its contents nor app listing have been reviewed. Install at your own risk.");

        var check = new Gtk.CheckButton.with_label (_("Show non-curated warnings"));

        App.settings.bind ("non-curated-warning", check, "active", SettingsBindFlags.DEFAULT);

        add_button (_("Don’t Install"), Gtk.ResponseType.CANCEL);
        var install = add_button (_("Install Anyway"), Gtk.ResponseType.OK);

        custom_bin.add (check);
        custom_bin.show_all ();

        set_default (check);
        check.grab_focus ();
    }
}
