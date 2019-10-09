/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
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

public class UninstallFailDialog : Granite.MessageDialog {
    public AppCenterCore.Package? package { get; construct; }
    public Error error { get; construct; }
    private const string FALLBACK_ICON = "application-default-icon";

    public UninstallFailDialog (AppCenterCore.Package? package, Error error) {
        Object (
            title: "",
            secondary_text: _("This may have been caused by external or manually compiled software."),
            buttons: Gtk.ButtonsType.CLOSE,
            badge_icon: new ThemedIcon ("dialog-error"),
            window_position: Gtk.WindowPosition.CENTER,
            error: error,
            package: package
        );
    }

    construct {
        if (package == null) {
            primary_text = _("Failed to uninstall app");
            image_icon = new ThemedIcon (FALLBACK_ICON);
        } else {
            primary_text = _("Failed to uninstall “%s”").printf (package.get_name ());
            image_icon = package.get_icon (48, get_scale_factor ());
        }

        response.connect (() => destroy ());

        show_error_details (error.message);
    }
}
