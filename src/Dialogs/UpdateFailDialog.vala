/*
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
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

public class UpdateFailDialog : Granite.MessageDialog {
    private const int TRY_AGAIN_RESPONSE_ID = 1;
    public string error_message { get; construct; }

    public UpdateFailDialog (string error_message) {
        Object (
            title: "",
            primary_text: _("Failed to Fetch Updates"),
            secondary_text: _("This may have been caused by external, manually added software repositories or a corrupted sources file."),
            image_icon: new ThemedIcon ("dialog-error"),
            buttons: Gtk.ButtonsType.NONE,
            error_message: error_message
        );
    }

    construct {
        add_button (_("Ignore"), Gtk.ResponseType.CLOSE);
        add_button (_("Try Again"), TRY_AGAIN_RESPONSE_ID);
        show_error_details (error_message);

        response.connect ((response_id) => {
            if (response_id == TRY_AGAIN_RESPONSE_ID) {
                AppCenterCore.UpdateManager.get_default ().update_cache.begin (true);
            }
            destroy ();
        });
    }
}
