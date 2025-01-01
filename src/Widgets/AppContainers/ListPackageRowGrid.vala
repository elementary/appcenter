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
    private Gtk.Spinner spinner;

    public ListPackageRowGrid (AppCenterCore.Package package) {
        Object (package: package);
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
        package_name.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        package_summary = new Gtk.Label (package.get_summary ()) {
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            lines = 2,
            max_width_chars = 1,
            valign = Gtk.Align.START,
            width_chars = 20,
            wrap = true,
            xalign = 0
        };
        package_summary.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        if (package.is_local) {
            action_stack.visible = false;
        }

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 3
        };

        spinner = new Gtk.Spinner () {
            margin_top = 1,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            width_request = 40,
            height_request = 40,
            visible = package.has_generic_icon
        };
        spinner.start ();
        spinner.add_css_class ("spinner-small");
        app_icon_overlay.add_overlay (spinner);

        grid.attach (app_icon_overlay, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (package_summary, 1, 1);
        grid.attach (action_stack, 2, 0, 1, 2);

        append (grid);
    }

    public void update_icon (Icon icon) {
        spinner.visible = false;
        Gtk.Image icon_image = app_icon_overlay.child as Gtk.Image;
        if (icon_image != null) {
            icon_image.clear ();
            icon_image.set_from_gicon (icon);
        }
    }
}
