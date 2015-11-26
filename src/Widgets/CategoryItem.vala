// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
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
    public AppStream.Category app_category;
    private Gtk.Grid grid;
    private Gtk.Image display_image;
    private Gtk.Label name_label;
    private Gtk.Label desc_label;

    public CategoryItem (AppStream.Category app_category) {
        this.app_category = app_category;
        name_label.label = GLib.Markup.escape_text (app_category.name ?? "");
        desc_label.label = GLib.Markup.escape_text (app_category.summary ?? "");
        display_image.icon_name = app_category.icon;
        show_all ();
    }

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.column_spacing = 12;
        grid.valign = Gtk.Align.CENTER;

        display_image = new Gtk.Image ();
        display_image.icon_size = Gtk.IconSize.DIALOG;
        grid.attach (display_image, 0, 0, 1, 2);

        name_label = new Gtk.Label (null);
        name_label.get_style_context ().add_class ("h3");
        name_label.use_markup = true;
        ((Gtk.Misc) name_label).xalign = 0;
        name_label.hexpand = true;
        grid.attach (name_label, 1, 0, 1, 1);

        desc_label = new Gtk.Label (null);
        ((Gtk.Misc) desc_label).xalign = 0;
        desc_label.wrap = true;
        desc_label.hexpand = true;
        grid.attach (desc_label, 1, 1, 1, 1);

        child = grid;
    }
}
