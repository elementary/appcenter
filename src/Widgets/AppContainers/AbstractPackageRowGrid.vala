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
    protected Gtk.Grid info_grid;

    public AbstractPackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? info_size_group, Gtk.SizeGroup? action_size_group, bool show_uninstall = true) {
        Object (
            package: package,
            show_uninstall: show_uninstall,
            show_open: false
        );

        if (action_size_group != null) {
            action_size_group.add_widget (action_button);
            action_size_group.add_widget (cancel_button);
            action_size_group.add_widget (uninstall_button);
        }

        if (info_size_group != null) {
            info_size_group.add_widget (info_grid);
        }
    }

    construct {
        column_spacing = 24;
        margin = 6;
        margin_start = 12;
        margin_end = 12;

        inner_image.icon_size = Gtk.IconSize.DIALOG;
        /* Needed to enforce size on icons from Filesystem/Remote */
        inner_image.pixel_size = 48;

        package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        package_name.valign = Gtk.Align.END;
        package_name.xalign = 0;

        info_grid = new Gtk.Grid ();
        info_grid.column_spacing = 12;
        info_grid.row_spacing = 6;
        info_grid.valign = Gtk.Align.START;
        info_grid.attach (image, 0, 0, 1, 2);
        info_grid.attach (package_name, 1, 0, 1, 1);

        action_stack.margin_top = 10;
        action_stack.valign = Gtk.Align.START;

        attach (info_grid, 0, 0, 1, 1);
        attach (action_stack, 3, 0, 1, 1);
    }
}
