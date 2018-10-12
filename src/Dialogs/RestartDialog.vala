// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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
    public class RestartDialog : Gtk.Dialog {
        private SystemInterface system_interface;

        public RestartDialog () {
            Object (title: "", deletable: false, skip_taskbar_hint: true, skip_pager_hint: true, type_hint: Gdk.WindowTypeHint.DIALOG);
        }

        construct {
            try {
                system_interface = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
            } catch (IOError e) {
                stderr.printf ("%s\n", e.message);
            }

            /*
            * the restart type is currently used by the indicator for what is
            * labelled shutdown because of unity's implementation of it
            * apparently. So we got to adjust to that until they fix this.
            */
            string icon_name = "system-shutdown";
            string heading_text = _("Are you sure you want to Restart?");
            string content_text = _("This will close all open applications and restart this device.");
            string button_text = _("Restart");

            set_position (Gtk.WindowPosition.CENTER_ALWAYS);
            set_keep_above (true);
            stick ();
            set_resizable (false);

            var heading = new Gtk.Label ("<span weight='bold' size='larger'>" + heading_text + "</span>");
            heading.get_style_context ().add_class ("larger");
            heading.use_markup = true;
            heading.halign = Gtk.Align.START;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.margin_start = grid.margin_end = grid.margin_bottom = 12;
            grid.attach (new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG), 0, 0, 1, 2);
            grid.attach (heading, 1, 0, 1, 1);
            grid.attach (new Gtk.Label (content_text), 1, 1, 1, 1);

            var cancel = add_button (_("Cancel"), Gtk.ResponseType.CANCEL) as Gtk.Button;
            cancel.clicked.connect (() => { destroy (); });

            var confirm = add_button (button_text, Gtk.ResponseType.OK) as Gtk.Button;
            confirm.get_style_context ().add_class ("destructive-action");
            confirm.clicked.connect (() => {
                try {
                    system_interface.reboot (false);
                } catch (Error e) {
                    critical ("Failed to reboot: %s", e.message);
                }

                destroy ();
            });

            set_default (confirm);

            get_content_area ().add (grid);

            var action_area = get_action_area ();
            action_area.margin_end = 6;
            action_area.margin_start = 6;
            action_area.margin_bottom = 6;
        }
    }
}

