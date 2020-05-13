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

public class AppCenter.Widgets.ListPackageRowGrid : AbstractPackageRowGrid {
    public ListPackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? action_size_group) {
        base (package, action_size_group);

        set_up_package ();
    }

    construct {
        package_summary = new Gtk.Label (null);
        package_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        package_summary.hexpand = true;
        package_summary.valign = Gtk.Align.START;
        ((Gtk.Misc) package_summary).xalign = 0;

        var info_grid = new Gtk.Grid ();
        info_grid.column_spacing = 12;
        info_grid.row_spacing = 6;
        info_grid.valign = Gtk.Align.START;
        info_grid.attach (image, 0, 0, 1, 2);
        info_grid.attach (package_name, 1, 0);
        info_grid.attach (package_summary, 1, 1);

        var grid = new Gtk.Grid ();
        grid.column_spacing = 24;
        grid.attach (info_grid, 0, 0);
        grid.attach (action_stack, 1, 0);

        add (grid);
    }

    protected override void set_up_package (uint icon_size = 48) {
        package_summary.label = package.get_summary ();
        package_summary.ellipsize = Pango.EllipsizeMode.END;

        if (package.is_local) {
            action_stack.no_show_all = true;
            action_stack.visible = false;
        }

        base.set_up_package (icon_size);
    }
}
