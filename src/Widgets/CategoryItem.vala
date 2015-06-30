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
        public weak Category app_category { public get; private set; }

        private Gtk.Grid grid;
        private Gtk.Image display_image;

        public CategoryItem (Category app_category) {
            this.app_category = app_category;

            set_relief (Gtk.ReliefStyle.NONE);
            set_size_request (250, 0);

            build_ui ();
            show_all ();
        }

        private void build_ui () {
            grid = new Gtk.Grid ();
            grid.margin = 10;
            grid.set_column_spacing (10);

            display_image = new Gtk.Image.from_icon_name (app_category.icon_name, Gtk.IconSize.DIALOG);
            grid.attach (display_image, 0, 0, 1, 2);

            Gtk.Label name_label = new Gtk.Label
                (@"<span font_weight=\"bold\" size=\"x-large\">%s</span>".printf (app_category.category_name));
            name_label.use_markup = true;
            name_label.halign = Gtk.Align.START;
            grid.attach (name_label, 1, 0, 1, 1);

            Gtk.Label desc_label = new Gtk.Label (app_category.description);
            desc_label.halign = Gtk.Align.START;
            grid.attach (desc_label, 1, 1, 1, 1);

            child = grid;
        }
    }
}
