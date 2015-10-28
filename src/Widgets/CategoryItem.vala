/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

using AppCenterCore;

namespace AppCenter.Widgets {
    public class CategoryItem : Gtk.Button {
        private Category app_category;
        private Gtk.Grid grid;
        private Gtk.Image display_image;
        private Gtk.Label name_label;
        private Gtk.Label desc_label;

        public CategoryItem (Category app_category) {
            this.app_category = app_category;
            name_label.label = app_category.category_name;
            desc_label.label = app_category.description;
            display_image.icon_name = app_category.icon_name;
            show_all ();
        }

        construct {
            get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            grid = new Gtk.Grid ();
            grid.margin = 6;
            grid.column_spacing = 12;

            display_image = new Gtk.Image ();
            display_image.icon_size = Gtk.IconSize.DIALOG;
            grid.attach (display_image, 0, 0, 1, 2);

            name_label = new Gtk.Label (null);
            name_label.get_style_context ().add_class ("h3");
            name_label.use_markup = true;
            name_label.halign = Gtk.Align.START;
            grid.attach (name_label, 1, 0, 1, 1);

            desc_label = new Gtk.Label (null);
            desc_label.halign = Gtk.Align.START;
            grid.attach (desc_label, 1, 1, 1, 1);

            child = grid;
        }
    }
}
