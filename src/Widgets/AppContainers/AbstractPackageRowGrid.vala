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
    public signal void changed ();

    protected AbstractPackageRowGrid (AppCenterCore.Package package) {
        Object (
            package: package
        );
    }

    construct {
        inner_image.icon_size = Gtk.IconSize.DIALOG;
        /* Needed to enforce size on icons from Filesystem/Remote */
        inner_image.pixel_size = 48;

        package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        package_name.wrap = true;
        package_name.hexpand = true;
        package_name.xalign = 0;

        margin = 6;
        margin_start = 12;
        margin_end = 12;
        
        // <- Pop!_Shop

        hexpand = true;

        action_stack.homogeneous = false;

        // ->

        show_uninstall = false;
        show_open = false;
    }
}
