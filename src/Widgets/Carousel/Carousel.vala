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

public class AppCenter.Widgets.Carousel : Gtk.FlowBox {
        public Carousel () {
            Object (activate_on_single_click : true,
                    column_spacing: 12,
                    row_spacing: 12,
                    hexpand: true,
                    homogeneous: true,
                    max_children_per_line: 5,
                    min_children_per_line: 2);
        }

        public void add_package (AppCenterCore.Package? package) {
            var carousel_item = new CarouselItem (package);
            add (carousel_item);    
            show_all ();
        }
}
