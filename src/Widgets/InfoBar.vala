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
    public class InfoBar : Gtk.InfoBar {
        private Gtk.Box             box;
        private Gtk.Label           label;
        private Gtk.ProgressBar     progress_bar;
        private Gtk.Button          cancel_button;

        public InfoBar () {
            build_ui ();

            set_no_show_all (true);
            hide ();

            change_connection ();

            Client.get_default ().connection_changed.connect (() => change_connection ());

            Client.get_default ().operation_changed.connect ((operation, running, info) => {
                if (operation != Operation.UPDATE_REFRESH) {
                    if (running) change_operation (info, operation);
                    else toggle ();
                }
            });

            Client.get_default ().operation_progress.connect ((operation, progress) => change_progress (progress));
        }

        public void toggle () {
            if (no_show_all) {
                set_no_show_all (false);
                show_all ();
            } else {
                set_no_show_all (true);
                hide ();
            }
        }

        private void change_connection () {
            if (!Client.get_default ().connected) {
                label.set_label (
                    _("There is no internet connection available. You can browse and remove applications, but you cannot install anything currently."));
                progress_bar.set_no_show_all (true);
                cancel_button.set_no_show_all (true);

                set_message_type (Gtk.MessageType.WARNING);
                set_no_show_all (false);
                show_all ();
            } else if (Client.get_default ().connected){
                progress_bar.set_no_show_all (false);
                cancel_button.set_no_show_all (false);

                set_message_type (Gtk.MessageType.INFO);
            }
        }

        public void change_operation (string package_name, Operation operation) {
            if (no_show_all && operation != Operation.UPDATE_REFRESH)
                toggle ();

            switch (operation) {
                case Operation.CACHE_REFRESH:
                    label.set_label (_("Refreshing database and cache"));
                    break;
                case Operation.PACKAGE_UPDATE:
                    label.set_label (_("Updating package '%s'").printf (package_name));
                    break;
                case Operation.PACKAGE_INSTALL:
                    label.set_label (_("Installing package '%s'").printf (package_name));
                    break;
                case Operation.PACKAGE_REMOVAL:
                    label.set_label (_("Removing package '%s'").printf (package_name));
                    break;
                default: break;
            }
        }

        public void change_progress (int progress) {
            progress_bar.pulse ();
            progress_bar.set_fraction ((double)progress / 100);
        }

        private void build_ui () {
            box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            box.hexpand = true;

            label = new Gtk.Label ("");
            label.halign = Gtk.Align.START;
            box.pack_start (label);

            progress_bar = new Gtk.ProgressBar ();
            progress_bar.halign = Gtk.Align.END;
            progress_bar.valign = Gtk.Align.CENTER;
            box.pack_end (progress_bar);

            get_content_area ().add (box);

            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            cancel_button.set_sensitive (false);
            add_action_widget (cancel_button, 0);
        }
    }
}
