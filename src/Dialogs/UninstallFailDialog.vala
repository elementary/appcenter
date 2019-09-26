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
    public Error error { get; construct; }

    public UninstallFailDialog (AppCenterCore.Package package, Error error) {
        Object (
            title: "",
            primary_text: _("Uninstall failed for %s").printf (package.get_name ()),
            secondary_text: _("This may have been caused by external,
                manually added software repositories or a corrupted sources file."),
            image_icon: package.get_icon (
                48,
                (Application.get_default () as Gtk.Application).active_window.get_scale_factor ()
            ),
            buttons: Gtk.ButtonsType.CLOSE,
            badge_icon: new ThemedIcon ("dialog-error"),
            error: error,
            window_position: Gtk.WindowPosition.CENTER
        );
    }

    construct {
        debug ("Using new dialog");
        stick ();
        show_error_details (error.message);
        response.connect (() => destroy ());
    }
}
