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
    public bool using_flatpak { get; construct; }
    public uint64 size { get; construct; }

    private Gtk.Label size_label;
    private Gtk.Revealer icon_revealer;
    private Gtk.Stack stack;

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

        var icon = new Gtk.Image.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.BUTTON);
        icon.margin_start = 6;

        icon_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.NONE,
            child = icon
        };

        var box = new Gtk.Box (HORIZONTAL, 0);
        box.add (size_label);
        box.add (icon_revealer);

        stack = new Gtk.Stack () {
            transition_type = SLIDE_LEFT
        };
        stack.add_named (box, "box");
        stack.add_named (new Gtk.Grid (), "placeholder");

        add (stack);
        show_all ();

        update (size, using_flatpak);
    }

    public void update (uint64 size = 0, bool using_flatpak = false) {
        has_tooltip = using_flatpak;
        icon_revealer.reveal_child = using_flatpak;

        string human_size = GLib.format_size (size);

        if (using_flatpak) {
            size_label.label = _("Up to %s").printf (human_size);
        } else {
            size_label.label = "%s".printf (human_size);
        }

        if (size > 0) {
            stack.visible_child_name = "box";
        } else {
            stack.visible_child_name = "placeholder";
        }
    }
}
