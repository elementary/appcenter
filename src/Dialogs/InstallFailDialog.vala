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
    public Error error { get; construct; }
    private const string FALLBACK_ICON = "application-default-icon";

    public InstallFailDialog (AppCenterCore.Package? package, Error error) {
        Object (
            title: "",
            secondary_text: _("• Install all available updates via the Installed tab of the Pop!_Shop, reboot, and try again.\n\n• If the software supports multiple installation types, use the drop-down next to the Install button to select a different option and try again."),
            badge_icon: new ThemedIcon ("dialog-error"),
            window_position: Gtk.WindowPosition.CENTER,
            error: error,
            package: package
        );
    }

    construct {
        if (package == null) {
            primary_text = _("Failed to install Applicaton.\n\nTry the following to resolve this error:\n");
            image_icon = new ThemedIcon (FALLBACK_ICON);
        } else {
            primary_text = _("Failed to install %s.\n\nTry the following to resolve this error:\n").printf(package.get_name ());
            image_icon = package.get_icon (48, get_scale_factor ());
        }
	
	add_button (_("Ignore"), Gtk.ResponseType.CLOSE);
	var updates_button = add_button (_("Check For Updates"), Gtk.ResponseType.OK);
	updates_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
	updates_button.grab_focus ();

        show_error_details (error.message);
    }
}
