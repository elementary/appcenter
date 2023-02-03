/*
 * Copyright 2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class InstallFailDialog : Granite.MessageDialog {
    public AppCenterCore.Package? package { get; construct; }
    public string error_message { get; construct; }
    private const string FALLBACK_ICON = "application-default-icon";

    public InstallFailDialog (AppCenterCore.Package? package, string error_message) {
        Object (
            title: "",
            secondary_text: _("This may be a temporary issue or could have been caused by external or manually compiled software."),
            buttons: Gtk.ButtonsType.CLOSE,
            badge_icon: new ThemedIcon ("dialog-error"),
            error_message: error_message,
            package: package
        );
    }

    construct {
        if (package == null) {
            primary_text = _("Failed to install app");
            image_icon = new ThemedIcon (FALLBACK_ICON);
        } else {
            primary_text = _("Failed to install “%s”").printf (package.get_name ());
            image_icon = package.get_icon (48, get_scale_factor ());
        }

        if (package.is_flatpak) {
            var repair_button = add_button (_("Repair"), Gtk.ResponseType.ACCEPT);
            repair_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        }

        response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                AppCenter.App.repair_action.activate (null);
            }

            destroy ();
        });

        show_error_details (error_message);
    }
}
