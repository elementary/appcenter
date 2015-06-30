/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

using AppCenterCore;

namespace AppCenter.Widgets {
    public class ActionButton : Gtk.Button {
        private bool locked = false;

        public ActionButton () {
            connect_signals ();
        }

        public ActionButton.from_icon_name (string icon_name, Gtk.IconSize size) {
            Gtk.Image icon = new Gtk.Image.from_icon_name (icon_name, size);
            set_image (icon);
            connect_signals ();
        }

        public ActionButton.with_label (string label) {
            set_label (label);
            connect_signals ();
        }

        private void connect_signals () {
            Client.get_default ().operation_changed.connect ((operation, running) => {
                if (running)
                    set_sensitive (false);
                else if (!running && !locked)
                    set_sensitive (true);
            });

            Client.get_default ().connection_changed.connect (() => lock_button ());

            lock_button ();
        }

        private void lock_button () {
            if (Client.get_default ().connected) {
                locked = false;
                if (!Client.get_default ().operation_running)
                    set_sensitive (true);
            } else {
                locked = true;
                set_sensitive (false);
            }
        }
    }
}
