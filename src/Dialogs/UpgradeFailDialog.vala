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

public class UpgradeFailDialog : Granite.MessageDialog {
    public AppCenterCore.Package? package { get; construct; }
    public string error_message { get; construct; }
    private const string FALLBACK_ICON = "application-default-icon";
    private const int REPAIR_RESPONSE_ID = 1;

    public UpgradeFailDialog (AppCenterCore.Package? package, string error_message) {
        Object (
            title: "",
            secondary_text: _("This may have been caused by sideloaded or manually compiled software, a third-party software source, or a package manager error. Manually refreshing updates may resolve the issue."),
            buttons: Gtk.ButtonsType.CLOSE,
            badge_icon: new ThemedIcon ("dialog-error"),
            error_message: error_message,
            package: package
        );
    }

    construct {
        if (package == null) {
            primary_text = _("Failed to update app");
            image_icon = new ThemedIcon (FALLBACK_ICON);
        } else {
            primary_text = _("Failed to update “%s”").printf (package.name);
            image_icon = package.get_icon (48, get_scale_factor ());
        }

        var refresh_button = add_button (_("Refresh Updates"), Gtk.ResponseType.ACCEPT);

        var repair_button = add_button (_("Repair"), REPAIR_RESPONSE_ID);
        repair_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);

        show_error_details (error_message);

        response.connect ((response_type) => {
            if (response_type == Gtk.ResponseType.ACCEPT) {
                Application.get_default ().activate_action ("app.refresh", null);
            } else if (response_type == REPAIR_RESPONSE_ID) {
                AppCenter.App.repair_action.activate (null);
            }

            destroy ();
        });
    }
}
