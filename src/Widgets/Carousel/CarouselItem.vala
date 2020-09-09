/*
* Copyright (c) 2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class AppCenter.Widgets.CarouselItem : Gtk.FlowBoxChild {
    public AppCenterCore.Package package { get; construct; }

    public CarouselItem (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        var icon = new Gtk.Image ();
        icon.gicon = package.get_icon (64, get_scale_factor ());
        icon.pixel_size = 64;

        var name_label = new Gtk.Label (package.get_name ());
        name_label.wrap = true;
        name_label.xalign = 0;
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var category_label = new Gtk.Label (package.component.developer_name);
        category_label.xalign = 0;
        category_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.row_spacing = 3;
        grid.margin = 6;
        grid.attach (icon, 0, 0, 1, 2);
        grid.attach (name_label, 1, 0, 1, 1);
        grid.attach (category_label, 1, 1, 1, 1);

        add (grid);
    }
}
