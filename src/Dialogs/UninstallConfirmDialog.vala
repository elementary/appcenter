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

public class UninstallConfirmDialog : Granite.MessageDialog {
    public AppCenterCore.Package? package { get; construct; }
    private const string FALLBACK_ICON = "application-default-icon";

    public UninstallConfirmDialog (AppCenterCore.Package? package) {
        Object (
            title: "",
            secondary_text: _("Uninstalling this app may also delete its data."),
            buttons: Gtk.ButtonsType.CANCEL,
            badge_icon: new ThemedIcon ("edit-delete"),
            window_position: Gtk.WindowPosition.CENTER,
            package: package
        );
    }

    construct {
        if (package == null) {
            primary_text = _("Uninstall app?");
            image_icon = new ThemedIcon (FALLBACK_ICON);
        } else {
            primary_text = _("Uninstall “%s”?").printf (package.get_name ());
            image_icon = package.get_icon (48, get_scale_factor ());
        }

        var uninstall_button = add_button (_("Uninstall"), Gtk.ResponseType.ACCEPT);
        uninstall_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
    }
}
