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

public class AppCenter.Widgets.SizeLabel : Gtk.Box {
    public uint64 size { get; construct; }

    private Gtk.Label size_label;
    private Gtk.Image icon;
    private Gtk.Revealer revealer;

    public SizeLabel (uint64 _size = 0) {
        Object (size: _size);
    }

    construct {
        tooltip_markup = "<b>%s</b>\n%s".printf (
            _("Actual Download Size Likely to Be Smaller"),
            _("Only the parts of apps and updates that are needed will be downloaded.")
        );

        size_label = new Gtk.Label (null);

        icon = new Gtk.Image.from_icon_name ("dialog-information-symbolic") {
            margin_start = 6
        };

        var box = new Gtk.Box (HORIZONTAL, 0);
        box.append (size_label);
        box.append (icon);

        revealer = new Gtk.Revealer () {
            transition_type = SLIDE_LEFT,
            child = box
        };

        append (revealer);

        update (size);
    }

    public void update (uint64 size = 0) {
        string human_size = GLib.format_size (size);

        size_label.label = _("Up to %s").printf (human_size);

        revealer.reveal_child = size > 0;
    }
}
