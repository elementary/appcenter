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

using AppCenterCore;

const int NUM_PACKAGES_IN_BANNER = 5;
const int NUM_PACKAGES_IN_CAROUSEL = 5;

namespace AppCenter {
    public class Homepage : View {
        private Gtk.FlowBox category_flow;
        private Gtk.ScrolledWindow category_scrolled;
        private string current_category;
        private Widgets.Switcher switcher;
        private Gtk.Revealer recently_updated_revealer;
        private Widgets.Carousel recently_updated_carousel;
        private Gtk.Revealer trending_revealer;
        private Widgets.Carousel trending_carousel;

        public bool viewing_package { get; private set; default = false; }

        public AppStream.Category currently_viewed_category;
        public MainWindow main_window { get; construct; }
        public Widgets.Banner newest_banner;
        public Gtk.Revealer switcher_revealer;

        public Homepage (MainWindow main_window) {
            Object (main_window: main_window);
        }

        construct {
            switcher = new Widgets.Switcher ();
            switcher.halign = Gtk.Align.CENTER;

            switcher_revealer = new Gtk.Revealer ();
            switcher_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            switcher_revealer.set_transition_duration (Widgets.Banner.TRANSITION_DURATION_MILLISECONDS);
            switcher_revealer.add (switcher);

            newest_banner = new Widgets.Banner (switcher);
            newest_banner.get_style_context ().add_class ("home");
            newest_banner.margin = 12;
            newest_banner.clicked.connect (() => {
                var package = newest_banner.get_package ();
                if (package != null) {
                    show_package (package);
                }
            });

            var recently_updated_label = new Gtk.Label (_("Recently Updated"));
            recently_updated_label.get_style_context ().add_class ("h4");
            recently_updated_label.xalign = 0;
            recently_updated_label.margin_start = 10;

            recently_updated_carousel = new Widgets.Carousel ();

            var recently_updated_grid = new Gtk.Grid ();
            recently_updated_grid.margin = 2;
            recently_updated_grid.margin_top = 12;
            recently_updated_grid.attach (recently_updated_label, 0, 0, 1, 1);
            recently_updated_grid.attach (recently_updated_carousel, 0, 1, 1, 1);

            recently_updated_revealer = new Gtk.Revealer ();
            recently_updated_revealer.add (recently_updated_grid );

            var trending_label = new Gtk.Label (_("Trending"));
            trending_label.get_style_context ().add_class ("h4");
            trending_label.xalign = 0;
            trending_label.margin_start = 10;

            trending_carousel = new Widgets.Carousel ();

            var trending_grid = new Gtk.Grid ();
            trending_grid.margin = 2;
            trending_grid.margin_top = 12;
            trending_grid.attach (trending_label, 0, 0, 1, 1);
            trending_grid.attach (trending_carousel, 0, 1, 1, 1);

            trending_revealer = new Gtk.Revealer ();
            trending_revealer.add (trending_grid );

            var categories_label = new Gtk.Label (_("Categories"));
            categories_label.get_style_context ().add_class ("h4");
            categories_label.xalign = 0;
            categories_label.margin_start = 12;
            categories_label.margin_top = 24;

            category_flow = new Widgets.CategoryFlowBox ();
            category_flow.valign = Gtk.Align.START;

            var grid = new Gtk.Grid ();
            grid.margin = 12;
            grid.attach (newest_banner, 0, 0, 1, 1);
            grid.attach (switcher_revealer, 0, 1, 1, 1);
            grid.attach (trending_revealer, 0, 2, 1, 1);
            grid.attach (recently_updated_revealer, 0, 3, 1, 1);
            grid.attach (categories_label, 0, 4, 1, 1);
            grid.attach (category_flow, 0, 5, 1, 1);

            category_scrolled = new Gtk.ScrolledWindow (null, null);
            category_scrolled.add (grid);

            add (category_scrolled);

            var local_package = App.local_package;
            if (local_package != null) {
                newest_banner.add_package (local_package);
            }

            populate_carousels.begin ();

            category_flow.child_activated.connect ((child) => {
                var item = child as Widgets.CategoryItem;
                if (item != null) {
                    currently_viewed_category = item.app_category;
                    show_app_list_for_category (item.app_category);
                }
            });

            category_flow.set_sort_func ((child1, child2) => {
                var item1 = child1 as Widgets.CategoryItem;
                var item2 = child2 as Widgets.CategoryItem;
                if (item1 != null && item2 != null) {
                    return item1.app_category.name.collate (item2.app_category.name);
                }

                return 0;
            });

            recently_updated_carousel.package_activated.connect (show_package);
            trending_carousel.package_activated.connect (show_package);
        }

        private async void populate_carousels () {
            var houston = AppCenterCore.Houston.get_default ();
            var client = AppCenterCore.Client.get_default ();

            string[] project_packages = yield houston.get_app_ids ("/newest/project");
            string[] release_packages = yield houston.get_app_ids ("/newest/release");
            string[] downloads_packages = yield houston.get_app_ids ("/newest/downloads");

            string[] package_query = {};
            foreach (var package in project_packages) {
                package_query += package + ".desktop";
            }

            foreach (var package in release_packages) {
                package_query += package + ".desktop";
            }

            foreach (var package in downloads_packages) {
                package_query += package + ".desktop";
            }

            var carousel_packages = yield client.get_app_packages (package_query);

            uint package_count = 0;
            foreach (var package in project_packages) {
                if (package_count >= NUM_PACKAGES_IN_BANNER) {
                    break;
                }

                var component_name = package + ".desktop";
                if (carousel_packages[component_name].info == Pk.Info.AVAILABLE) {
                    var candidate_package = client.get_package_for_component_id (component_name);
                    if (candidate_package != null) {
                        newest_banner.add_package (candidate_package);
                        package_count++;
                    }
                }
            }

            newest_banner.go_to_first ();
            switcher.show_all ();
            switcher_revealer.set_reveal_child (true);
            main_window.homepage_loaded ();

            package_count = 0;
            foreach (var package in release_packages) {
                if (package_count >= NUM_PACKAGES_IN_CAROUSEL) {
                    break;
                }

                var component_name = package + ".desktop";
                if (carousel_packages[component_name].info == Pk.Info.AVAILABLE) {
                    var candidate_package = client.get_package_for_component_id (component_name);
                    if (candidate_package != null) {
                        recently_updated_carousel.add_package (candidate_package);
                        package_count++;
                    }
                }
            }

            recently_updated_revealer.reveal_child = true;

            package_count = 0;
            foreach (var package in downloads_packages) {
                if (package_count >= NUM_PACKAGES_IN_CAROUSEL) {
                    break;
                }

                var component_name = package + ".desktop";
                if (carousel_packages[component_name].info == Pk.Info.AVAILABLE) {
                    var candidate_package = client.get_package_for_component_id (component_name);
                    if (candidate_package != null) {
                        trending_carousel.add_package (candidate_package);
                        package_count++;
                    }
                }
            }

            trending_revealer.reveal_child = true;
        }

        public override void show_package (AppCenterCore.Package package) {
            base.show_package (package);
            viewing_package = true;
            current_category = null;
            currently_viewed_category = null;
            subview_entered (_("Home"), false, "");
        }

        public override void return_clicked () {
            if (previous_package != null) {
                show_package (previous_package);
                if (current_category != null) {
                    subview_entered (current_category, false, "");
                } else {
                    subview_entered (_("Home"), false, "");
                }
            } else if (viewing_package && current_category != null) {
                set_visible_child_name (current_category);
                viewing_package = false;
                subview_entered (_("Home"), true, current_category, _("Search %s").printf (current_category));
            } else {
                set_visible_child (category_scrolled);
                viewing_package = false;
                currently_viewed_category = null;
                current_category = null;
                subview_entered (null, true);
            }
        }

        private void show_app_list_for_category (AppStream.Category category) {
            subview_entered (_("Home"), true, category.name, _("Search %s").printf (category.name));
            current_category = category.name;
            var child = get_child_by_name (category.name);
            if (child != null) {
                set_visible_child (child);
                return;
            }

            var app_list_view = new Views.AppListView ();
            app_list_view.show_all ();
            add_named (app_list_view, category.name);
            set_visible_child (app_list_view);

            app_list_view.show_app.connect ((package) => {
                viewing_package = true;
                base.show_package (package);
                subview_entered (category.name, false, "");
            });

            unowned Client client = Client.get_default ();
            var apps = client.get_applications_for_category (category);
            app_list_view.add_packages (apps);
        }
    }
}
