/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
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
    private Gtk.Label package_summary;

    public ListPackageRowGrid (AppCenterCore.Package package) {
        base (package);
        set_up_package ();
    }

    construct {
        var package_name = new Gtk.Label (package.get_name ()) {
            ellipsize = Pango.EllipsizeMode.END,
            lines = 2,
            max_width_chars = 1,
            valign = Gtk.Align.END,
            wrap = true,
            xalign = 0
        };
        package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        package_summary = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            lines = 2,
            max_width_chars = 1,
            valign = Gtk.Align.START,
            width_chars = 20,
            wrap = true,
            xalign = 0
        };
        package_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 3
        };
        grid.attach (app_icon_overlay, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (package_summary, 1, 1);
        grid.attach (action_stack, 2, 0, 1, 2);

        add (grid);
    }

    protected override void set_up_package () {
        package_summary.label = package.get_summary ();

        if (package.is_local) {
            action_stack.no_show_all = true;
            action_stack.visible = false;
        }

        base.set_up_package ();
    }
}
