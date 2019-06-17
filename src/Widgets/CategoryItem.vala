// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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

public class AppCenter.Widgets.CategoryItem : Gtk.FlowBoxChild {
    public AppStream.Category app_category { get; construct; }
    private Gtk.Label name_label;
    private Gtk.Grid themed_grid;

    public CategoryItem (AppStream.Category app_category) {
        Object (app_category: app_category);
    }

    construct {
        var display_image = new Gtk.Image ();
        display_image.icon_size = Gtk.IconSize.DIALOG;
        display_image.valign = Gtk.Align.CENTER;
        display_image.halign = Gtk.Align.END;

        name_label = new Gtk.Label (null);
        name_label.wrap = true;
        name_label.max_width_chars = 15;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.HORIZONTAL;
        grid.column_spacing = 6;
        grid.halign = Gtk.Align.CENTER;
        grid.valign = Gtk.Align.CENTER;
        grid.margin_top = 32;
        grid.margin_end = 16;
        grid.margin_bottom = 32;
        grid.margin_start = 16;
        grid.add (display_image);
        grid.add (name_label);

        var expanded_grid = new Gtk.Grid ();
        expanded_grid.expand = true;
#if POP_OS
        expanded_grid.margin = 6;
#else
        expanded_grid.margin = 12;
#endif

        themed_grid = new Gtk.Grid ();
        themed_grid.get_style_context ().add_class ("category");
        themed_grid.attach (grid, 0, 0, 1, 1);
        themed_grid.attach (expanded_grid, 0, 0, 1, 1);
        themed_grid.margin = 12;

        child = themed_grid;

        tooltip_text = app_category.summary ?? "";

        if (app_category.icon != "") {
            display_image.icon_name = app_category.icon;
            ((Gtk.Misc) name_label).xalign = 0;
            name_label.halign = Gtk.Align.START;
        } else {
            display_image.destroy ();
            name_label.justify = Gtk.Justification.CENTER;
        }

        show_all ();
    }

    public void add_category_class (string theme_name) {
        themed_grid.get_style_context ().add_class (theme_name);

        if (theme_name == "games" || theme_name == "accessibility") {
            name_label.label = app_category.name.up ();
        } else {
            name_label.label = app_category.name;
        }

        if (theme_name == "science") {
            name_label.justify = Gtk.Justification.CENTER;
        }
    }
}
