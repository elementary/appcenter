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

namespace AppCenter {
    public class Homepage : View {
        private Gtk.FlowBox category_flow;
        private Gtk.ScrolledWindow category_scrolled;
        private string current_category;

        public signal void package_selected (AppCenterCore.Package package);

        public AppStream.Category currently_viewed_category;
        public MainWindow main_window { get; construct; }
        public Widgets.Banner newest_banner;

        public Homepage (MainWindow main_window) {
            Object (main_window: main_window);
        }

        construct {
            var houston = AppCenterCore.Houston.get_default ();

            newest_banner = new Widgets.Banner ();
            newest_banner.get_style_context ().add_class ("home");
            newest_banner.margin = 12;

            newest_banner.clicked.connect (() => {
                var package = newest_banner.get_package ();
                if (package != null) {
                    package_selected (package);
                }
            });
            newest_banner.set_default_brand ();

            houston.get_newest.begin ((obj, res) => {
                var newest_ids = houston.get_newest.end (res);
                ThreadFunc<void*> run = () => {
                    foreach (var package in newest_ids) {
                        var candidate = package + ".desktop";
                        var candidate_package = AppCenterCore.Client.get_default ().get_package_for_id (candidate);

                        if (candidate_package != null) {
                            candidate_package.update_state ();
                            if (candidate_package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                                Idle.add (() => {
                                    newest_banner.set_package (candidate_package);
                                    return false;
                                });
                                break;
                            }
                        }
                    }
                    main_window.homepage_loaded ();
                    return null;
                };
                new Thread<void*> ("update-banner", run);
            });

            var categories_label = new Gtk.Label (_("Categories"));
            categories_label.get_style_context ().add_class ("h4");
            categories_label.xalign = 0;
            categories_label.margin_start = 12;
            categories_label.margin_top = 12;

            category_flow = new Widgets.CategoryFlowBox ();
            category_flow.valign = Gtk.Align.START;

            var grid = new Gtk.Grid ();
            grid.margin = 12;
            grid.attach (newest_banner, 0, 0, 1, 1);
            grid.attach (categories_label, 0, 1, 1, 1);
            grid.attach (category_flow, 0, 2, 1, 1);

            category_scrolled = new Gtk.ScrolledWindow (null, null);
            category_scrolled.add (grid);

            add (category_scrolled);

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
        }

        public override void return_clicked () {
            if (current_category == null) {
                set_visible_child (category_scrolled);
                currently_viewed_category = null;
            } else {
                subview_entered (_("Home"), true, current_category);
                set_visible_child_name (current_category);
                current_category = null;
            }
        }

        private void show_app_list_for_category (AppStream.Category category) {
            subview_entered (_("Home"), true, category.name);
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
                current_category = category.name;
                subview_entered (category.name, false, "");
                show_package (package);
            });

            unowned Client client = Client.get_default ();
            var apps = client.get_applications_for_category (category);
            app_list_view.add_packages (apps);

        }
    }
}
