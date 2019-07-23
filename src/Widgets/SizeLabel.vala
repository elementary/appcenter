/*
 * Copyright (c) 2019 elementary, Inc. (https://elementary.io)
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
 *
 */

namespace AppCenter.Widgets {
    public class SizeLabel : Gtk.Grid {
        public uint64 size { get; construct set; }

        private Gtk.Label size_label;

        public SizeLabel (uint64 _size = 0) {
            Object (
                column_spacing: 6,
                size: _size
            );
        }

        construct {
            // TODO: Only show "Up to", info icon, and tooltip if using Flatpak
            tooltip_markup = "<b>%s</b>\n%s".printf (
                _("Actual download size likely to be smaller."),
                _("AppCenter only downloads the parts of apps and updates that are needed.")
            );
            size_label = new Gtk.Label (null);
            size_label.use_markup = true;

            add (size_label);
            add (new Gtk.Image.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.LARGE_TOOLBAR));

            update (size);
        }

        public void update (uint64 size = 0) {
            size_label.label = _("Up to <b>%s</b>").printf (GLib.format_size (size));

            if (size > 0) {
                no_show_all = false;
                show_all ();
            } else {
                no_show_all = true;
                hide ();
            }
        }
    }
}

