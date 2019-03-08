/*
 * Copyright (c) 2014-2019 elementary, Inc. (https://elementary.io)
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

namespace AppCenter.Widgets {
    public class RestartDialog : Granite.MessageDialog {
        private SystemInterface system_interface;

        public RestartDialog () {
            Object (
                image_icon: new ThemedIcon ("system-shutdown"),
                primary_text: _("Are you sure you want to Restart?"),
                secondary_text: _("This will close all open applications and restart this device."),
                buttons: Gtk.ButtonsType.CANCEL
            );
        }

        construct {
            try {
                system_interface = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
            } catch (IOError e) {
                critical (e.message);
            }

            set_position (Gtk.WindowPosition.CENTER_ALWAYS);
            set_keep_above (true);
            stick ();

            var confirm = add_button (_("Restart"), Gtk.ResponseType.OK);
            confirm.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            set_default (confirm);

            response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.OK) {
                    try {
                        system_interface.reboot (false);
                    } catch (Error e) {
                        critical ("Failed to reboot: %s", e.message);
                    }
                }
                destroy ();
            });
        }
    }
}

