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
        public bool using_flatpak { get; construct set; }
        public uint64 size { get; construct set; }

        private Gtk.Label size_label;
        private Gtk.Revealer icon_revealer;

        public SizeLabel (uint64 _size = 0, bool _using_flatpak = false) {
            Object (
                size: _size,
                using_flatpak: _using_flatpak
            );
        }

        construct {
            tooltip_markup = "<b>%s</b>\n%s".printf (
                _("Actual Download Size Likely to Be Smaller"),
                _("Only the parts of apps and updates that are needed will be downloaded.")
            );
            size_label = new Gtk.Label (null);
            size_label.hexpand = true;
            size_label.vexpand = true;
            size_label.xalign = 1;
            size_label.show ();

            var icon = new Gtk.Image.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.BUTTON);
            icon.margin_start = 6;
            icon.show ();

            icon_revealer = new Gtk.Revealer ();
            icon_revealer.transition_type = Gtk.RevealerTransitionType.NONE;
            icon_revealer.add (icon);
            icon_revealer.show ();

            add (size_label);
            add (icon_revealer);

            update (size, using_flatpak);
        }

        public void update (uint64 size = 0, bool using_flatpak = false) {
            string human_size = GLib.format_size (size);

            if (using_flatpak) {
                size_label.label = _("Up to %s").printf (human_size);
                has_tooltip = true;
                icon_revealer.reveal_child = true;
            } else {
                size_label.label = "%s".printf (human_size);
                has_tooltip = false;
                icon_revealer.reveal_child = false;
            }

            if (size > 0) {
                no_show_all = false;
                show ();
            } else {
                no_show_all = true;
                hide ();
            }
        }
    }
}

