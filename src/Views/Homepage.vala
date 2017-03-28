// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
* Copyright (c) 2016-2017 elementary LLC. (https://elementary.io)
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
* Authored by: Nathan Dyer <mail@nathandyer.me>
*              Dane Henson <thegreatdane@gmail.com>
*/

namespace AppCenter {
    public class Homepage: Gtk.ScrolledWindow {

        public signal void package_selected (AppCenterCore.Package package);

        public Widgets.Banner newest_banner;
        public AppCenter.Views.CategoryView category_view;

        public Homepage () {
            var houston = AppCenterCore.Houston.get_default ();

            newest_banner = new Widgets.Banner ();
            newest_banner.get_style_context ().add_class ("home");
            newest_banner.margin = 12;

            var newest_ids = houston.get_newest ();
            foreach (var package in newest_ids) {
                var candidate = package + ".desktop";
                var candidate_package = AppCenterCore.Client.get_default ().get_package_for_id (candidate);

                if (candidate_package != null) {
                    candidate_package.update_state ();

                    if (candidate_package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                        newest_banner.set_package (candidate_package);
                        newest_banner.clicked.connect (() => {
                            package_selected (candidate_package);
                        });
                        break;
                    }
                }
            }

            if (newest_banner.current_package == null) {
                newest_banner.set_brand ();
            }

            var categories_label = new Gtk.Label (_("Categories"));
            categories_label.get_style_context ().add_class ("h4");
            categories_label.xalign = 0;
            categories_label.margin_start = 12;
            categories_label.margin_top = 12;

            category_view = new Views.CategoryView ();

            var grid = new Gtk.Grid ();
            grid.margin = 12;
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.add (newest_banner);
            grid.add (categories_label);
            grid.add (category_view.category_flow);

            add (grid);
        }
    }
}
