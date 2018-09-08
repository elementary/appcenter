/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.PaymentMethodButton : Gtk.RadioButton {
    public string title { get; construct set; }
    public string icon { get; construct set; }

    public PaymentMethodButton (string title, string icon) {
        Object (
            title: title,
            icon: icon
        );
    }

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_BUTTON);

        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.BUTTON);

        var title_label = new Gtk.Label (title);
        title_label.halign = Gtk.Align.START;
        title_label.hexpand = true;

        var grid = new Gtk.Grid ();
        grid.margin_top = grid.margin_bottom = 6;
        grid.column_spacing = grid.row_spacing = 6;

        grid.attach (title_label, 0, 0);
        grid.attach (image, 1, 0);

        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        add (grid);
        show_all ();
    }
}

