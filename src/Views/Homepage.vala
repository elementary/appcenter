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

#if POP_OS
const int NUM_PACKAGES_IN_BANNER = 15;
const int NUM_PACKAGES_IN_CAROUSEL = 15;
#else
const int NUM_PACKAGES_IN_BANNER = 5;
const int NUM_PACKAGES_IN_CAROUSEL = 5;
#endif

namespace AppCenter {
    public class Homepage : View {
        private Gtk.FlowBox category_flow;
        private Gtk.ScrolledWindow category_scrolled;
        private string current_category;

        public signal void page_loaded ();

        public bool viewing_package { get; private set; default = false; }

        public AppStream.Category currently_viewed_category;
#if HOMEPAGE
#if POP_OS
        private Gtk.Revealer featured_revealer;
        public Widgets.Carousel featured_carousel;
        private AppCenterCore.Package[] featured_apps;
#endif
        public Widgets.Banner newest_banner;
        public Gtk.Revealer switcher_revealer;

        private Widgets.Switcher switcher;
        private Widgets.Carousel recently_updated_carousel;
        private Widgets.Carousel trending_carousel;
        private Gtk.Revealer recently_updated_revealer;
        private Gtk.Revealer trending_revealer;

        construct {
            switcher = new Widgets.Switcher ();
            switcher.halign = Gtk.Align.CENTER;

            switcher_revealer = new Gtk.Revealer ();
            switcher_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            switcher_revealer.set_transition_duration (Widgets.Banner.TRANSITION_DURATION_MILLISECONDS);
            switcher_revealer.add (switcher);

#if POP_OS
            var pop_banner_copy_1 = new Gtk.Label (_("EXPLORE YOUR HORIZONS AND"));
            pop_banner_copy_1.expand = false;
            pop_banner_copy_1.halign = Gtk.Align.START;
            pop_banner_copy_1.margin_start = 48;
            pop_banner_copy_1.margin_top = 38;
            pop_banner_copy_1.yalign = 0;

            // FIXME: For some reason this isn't working right. Toggling it in
            // the inspector fixes the alignment.
            pop_banner_copy_1.vexpand = false;

            var pop_banner_copy_2 = new Gtk.Label (_("UNLEASH YOUR POTENTIAL"));
            pop_banner_copy_2.halign = Gtk.Align.START;
            pop_banner_copy_2.margin_start = 48;
            pop_banner_copy_2.yalign = 0;

            var pop_banner_copy_area = new Gtk.Grid ();
            pop_banner_copy_area.halign = Gtk.Align.CENTER;
            pop_banner_copy_area.hexpand = true;
            pop_banner_copy_area.width_request = 750;
            pop_banner_copy_area.attach (pop_banner_copy_1, 0, 0, 1, 1);
            pop_banner_copy_area.attach (pop_banner_copy_2, 0, 1, 1, 1);

            var pop_banner = new Gtk.Grid ();
            pop_banner.height_request = 300;
            pop_banner.hexpand = true;
            pop_banner.get_style_context ().add_class ("pop-banner");
            pop_banner.attach (pop_banner_copy_area, 0, 0, 1, 1);

            var featured_label = new Gtk.Label (_("Pop!_Picks"));
            featured_label.get_style_context ().add_class ("h4");
            featured_label.xalign = 0;

            featured_carousel = new Widgets.Carousel ();

            var featured_grid = new Gtk.Grid ();
            featured_grid.margin = 12;
            featured_grid.margin_bottom = 0;
            featured_grid.attach (featured_label, 0, 0, 1, 1);
            featured_grid.attach (featured_carousel, 0, 1, 1, 1);

            featured_revealer = new Gtk.Revealer ();
            featured_revealer.add (featured_grid );
#endif
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
            recently_updated_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
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
            trending_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
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
            categories_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            categories_label.xalign = 0;
            categories_label.margin_start = 12;
            categories_label.margin_top = 24;
#else
        construct {
#endif
            category_flow = new Widgets.CategoryFlowBox ();
            category_flow.valign = Gtk.Align.START;

            var grid = new Gtk.Grid ();
#if HOMEPAGE
#if POP_OS
            featured_revealer.margin_start = 12;
            featured_revealer.margin_end = 12;
            categories_label.margin_start = 24;
            categories_label.margin_top = 12;
            category_flow.margin_start = 12;
            category_flow.margin_end = 12;
            grid.attach (pop_banner,        0, 0, 1, 1);
            grid.attach (featured_revealer, 0, 1, 1, 1);
#else
            grid.margin = 12;
            grid.attach (newest_banner, 0, 0, 1, 1);
            grid.attach (switcher_revealer, 0, 1, 1, 1);
            grid.attach (trending_revealer, 0, 2, 1, 1);
            grid.attach (recently_updated_revealer, 0, 3, 1, 1);
#endif
            grid.attach (categories_label, 0, 4, 1, 1);
#endif
            grid.attach (category_flow, 0, 5, 1, 1);

            category_scrolled = new Gtk.ScrolledWindow (null, null);
            category_scrolled.add (grid);

            add (category_scrolled);

#if HOMEPAGE
            var local_package = App.local_package;
            if (local_package != null) {
                newest_banner.add_package (local_package);
            }

            load_banners.begin ();
#endif

            category_flow.child_activated.connect ((child) => {
                var item = child as Widgets.CategoryItem;
                if (item != null) {
                    currently_viewed_category = item.app_category;
                    show_app_list_for_category (item.app_category);
                }
            });

            AppCenterCore.Client.get_default ().installed_apps_changed.connect (() => {
                Idle.add (() => {
                    // Clear the cached categories when the AppStream pool is updated
                    foreach (weak Gtk.Widget child in category_flow.get_children ()) {
                        if (child is Widgets.CategoryItem) {
                            var item = child as Widgets.CategoryItem;
                            var category_components = item.app_category.get_components ();
                            category_components.remove_range (0, category_components.length);
                        }
                    }

                    // Remove any old cached category list views
                    foreach (weak Gtk.Widget child in get_children ()) {
                        if (child is Views.AppListView) {
                            if (child != visible_child) {
                                child.destroy ();
                            } else {
                                // If the category list view is visible, don't delete it, just make the package list right
                                var list_view = child as Views.AppListView;
                                list_view.clear ();

                                unowned Client client = Client.get_default ();
                                var apps = client.get_applications_for_category (currently_viewed_category);
                                list_view.add_packages (apps);
                            }
                        }
                    }

#if HOMEPAGE
#if POP_OS
                    // If the banners weren't populated, try again to populate them
                    if (!featured_revealer.reveal_child) {
                        load_banners.begin ();
                    }

                    return GLib.Source.REMOVE;
                });
            });

            featured_carousel.package_activated.connect ((package) => show_package (package));
        }

        private async void load_banners () {
            var houston = AppCenterCore.Houston.get_default ();
            var packages_for_banner = new Gee.LinkedList<AppCenterCore.Package> ();

            var newest_ids = yield houston.get_app_ids ("/newest/project");
            featured_apps = {};
            foreach (var package in newest_ids) {
                if (packages_for_banner.size >= NUM_PACKAGES_IN_BANNER) {
                    break;
                }


                var candidate_package = AppCenterCore.Client.get_default ().get_package_for_component_id (package);
                if (candidate_package != null) {
                    candidate_package.update_state ();
                    if (candidate_package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                        featured_apps += candidate_package;
                    }
                }
            }

            shuffle_featured_apps ();

            switcher.show_all ();
            switcher_revealer.set_reveal_child (true);

            page_loaded ();
        }

        public void shuffle_featured_apps () {
            featured_carousel.get_children ().foreach ((c) => c.destroy ());
            Utils.shuffle_array (featured_apps);

            if (featured_apps.length != 0) {
                Idle.add (() => {
                    for (int i = 0; i < NUM_PACKAGES_IN_CAROUSEL && i < featured_apps.length; i++) {
                        featured_carousel.add_package (featured_apps[i]);
                    }
                    featured_revealer.reveal_child = true;
                    return false;
                });
            }
        }
#else
                    // If the banners weren't populated, try again to populate them
                    if (!recently_updated_revealer.reveal_child && !trending_revealer.reveal_child && !switcher_revealer.reveal_child) {
                        load_banners.begin ();
                    }

                    return GLib.Source.REMOVE;
                });
            });

            recently_updated_carousel.package_activated.connect ((package) => show_package (package));
            trending_carousel.package_activated.connect ((package) => show_package (package));
        }

        private async void load_banners () {
            var houston = AppCenterCore.Houston.get_default ();
            var packages_for_banner = new Gee.LinkedList<AppCenterCore.Package> ();

            var newest_ids = yield houston.get_app_ids ("/newest/project");
            foreach (var package in newest_ids) {
                if (packages_for_banner.size >= NUM_PACKAGES_IN_BANNER) {
                    break;
                }

                var candidate_package = AppCenterCore.Client.get_default ().get_package_for_component_id (package);

                if (candidate_package != null) {
                    candidate_package.update_state ();

                    if (candidate_package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                        packages_for_banner.add (candidate_package);
                    }
                }
            }

            foreach (var banner_package in packages_for_banner) {
                newest_banner.add_package (banner_package);
            }

            newest_banner.go_to_first ();
            switcher.show_all ();
            switcher_revealer.set_reveal_child (true);

            var updated_ids = yield houston.get_app_ids ("/newest/release");
            Utils.shuffle_array (updated_ids);
            packages_for_banner = new Gee.LinkedList<AppCenterCore.Package> ();
            foreach (var package in updated_ids) {
                if (packages_for_banner.size >= NUM_PACKAGES_IN_CAROUSEL) {
                    break;
                }

                var candidate_package = AppCenterCore.Client.get_default ().get_package_for_component_id (package);

                if (candidate_package != null) {
                    candidate_package.update_state ();
                    if (candidate_package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                        packages_for_banner.add (candidate_package);
                    }
                }
            }

            if (!packages_for_banner.is_empty) {
                foreach (var banner_package in packages_for_banner) {
                    recently_updated_carousel.add_package (banner_package);
                }
                recently_updated_revealer.reveal_child = true;
            }

            var trending_ids = yield houston.get_app_ids ("/newest/downloads");
            Utils.shuffle_array (trending_ids);
            packages_for_banner = new Gee.LinkedList<AppCenterCore.Package> ();
            foreach (var package in trending_ids) {
                if (packages_for_banner.size >= NUM_PACKAGES_IN_CAROUSEL) {
                    break;
                }

                var candidate_package = AppCenterCore.Client.get_default ().get_package_for_component_id (package);

                if (candidate_package != null) {
                    candidate_package.update_state ();
                    if (candidate_package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                        packages_for_banner.add (candidate_package);
                    }
                }
            }

            if (!packages_for_banner.is_empty) {
                foreach (var trending_package in packages_for_banner) {
                    trending_carousel.add_package (trending_package);
                }
                trending_revealer.reveal_child = true;
            }

            page_loaded ();
        }
#endif
#else
                });
            });
        }
#endif

        public override void show_package (
            AppCenterCore.Package package,
            bool remember_history = true,
            Gtk.StackTransitionType transition = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        ) {
            base.show_package (package, remember_history, transition);
            viewing_package = true;
            if (remember_history) {
                current_category = null;
                currently_viewed_category = null;
                subview_entered (_("Home"), false, "");
            }
        }

        public override void return_clicked () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

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
