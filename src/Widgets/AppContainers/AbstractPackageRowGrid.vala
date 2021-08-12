// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public abstract class AppCenter.Widgets.AbstractPackageRowGrid : AbstractAppContainer {
    protected Gtk.Label package_name;

    protected Gtk.Overlay image;
    private Gtk.Image inner_image;

    protected AbstractPackageRowGrid (AppCenterCore.Package package) {
        Object (
            package: package
        );
    }

    construct {
        set_up_package ();

        inner_image = new Gtk.Image () {
            icon_size = Gtk.IconSize.DIALOG,
            pixel_size = 48,
            gicon = icon
        };

        image = new Gtk.Overlay ();
        image.add (inner_image);

        if (badge_icon != null) {
            var overlay_image = new Gtk.Image () {
                gicon = badge_icon,
                halign = Gtk.Align.END,
                valign = Gtk.Align.END,
                pixel_size = 24
            };

            image.add_overlay (overlay_image);
        }

        package_name = new Gtk.Label (name_label) {
            valign = Gtk.Align.END,
            xalign = 0
        };
        package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        margin = 6;
        margin_start = 12;
        margin_end = 12;

        show_uninstall = false;
        show_open = false;
    }
}
