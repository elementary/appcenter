/*
* Copyright 2016–2021 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Homepage : Gtk.Box {
    public signal void show_package (AppCenterCore.Package package);
    public signal void show_category (AppStream.Category category);

    private const int MAX_PACKAGES_IN_BANNER = 5;
    private const int MAX_PACKAGES_IN_CAROUSEL = 12;

    private Widgets.CategoryFlowBox category_flow;
    private Gtk.ScrolledWindow scrolled_window;

    private Adw.Carousel banner_carousel;
    private Gtk.Revealer banner_revealer;
    private Gtk.FlowBox recently_updated_carousel;
    private Gtk.Revealer recently_updated_revealer;

    private uint banner_timeout_id;

    construct {
        add_css_class (Granite.STYLE_CLASS_VIEW);
        hexpand = true;
        vexpand = true;

        banner_carousel = new Adw.Carousel () {
            allow_long_swipes = true
        };

        var banner_dots = new Adw.CarouselIndicatorDots () {
            carousel = banner_carousel
        };

        var banner_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        banner_box.append (banner_carousel);
        banner_box.append (banner_dots);

        banner_revealer = new Gtk.Revealer () {
            child = banner_box
        };

        var recently_updated_label = new Granite.HeaderLabel (_("Recently Updated")) {
            margin_start = 12
        };

        recently_updated_carousel = new Gtk.FlowBox () {
            activate_on_single_click = true,
            column_spacing = 12,
            row_spacing = 12,
            homogeneous = true,
            max_children_per_line = 5
        };

        var recently_updated_grid = new Gtk.Grid () {
            margin_end = 12,
            margin_start = 12
        };
        recently_updated_grid.attach (recently_updated_label, 0, 0);
        recently_updated_grid.attach (recently_updated_carousel, 0, 1);

        recently_updated_revealer = new Gtk.Revealer () {
            child = recently_updated_grid
        };

        var categories_label = new Granite.HeaderLabel (_("Categories")) {
            margin_start = 24,
            margin_top = 24
        };

        category_flow = new Widgets.CategoryFlowBox () {
            margin_start = 12,
            margin_end =12,
            margin_bottom = 12,
            valign = Gtk.Align.START
        };

        var box = new Gtk.Box (orientation = Gtk.Orientation.VERTICAL, 0);
        box.append (banner_revealer);
        box.append (recently_updated_revealer);
        box.append (categories_label);
        box.append (category_flow);

        scrolled_window = new Gtk.ScrolledWindow () {
            child = scrolled_window,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        append (scrolled_window);

        var local_package = App.local_package;
        if (local_package != null) {
            var banner = new Widgets.Banner (local_package);

            banner_carousel.prepend (banner);

            banner.clicked.connect (() => {
                show_package (local_package);
            });
        }

        banner_timeout_start ();
        load_banners_and_carousels.begin ();

        category_flow.show_category.connect ((category) => {
            show_category (category);
        });

        AppCenterCore.Client.get_default ().installed_apps_changed.connect (() => {
            Idle.add (() => {
                // Clear the cached categories when the AppStream pool is updated
                // foreach (weak Gtk.Widget child in category_flow.get_children ()) {
                //     var item = (Widgets.CategoryFlowBox.AbstractCategoryCard) child;
                //     var category_components = item.category.get_components ();
                //     category_components.remove_range (0, category_components.length);
                // }

                return GLib.Source.REMOVE;
            });
        });

        // banner_event_box.enter_notify_event.connect (() => {
        //     banner_timeout_stop ();
        // });

        // banner_event_box.leave_notify_event.connect (() => {
        //     banner_timeout_start ();
        // });

        recently_updated_carousel.child_activated.connect ((child) => {
            var package_row_grid = (AppCenter.Widgets.ListPackageRowGrid) child.get_child ();

            show_package (package_row_grid.package);
        });

        destroy.connect (() => {
            banner_timeout_stop ();
        });
    }

    private async void load_banners_and_carousels () {
        unowned var fp_client = AppCenterCore.FlatpakBackend.get_default ();
        var packages_by_release_date = fp_client.get_featured_packages_by_release_date ();
        var packages_in_banner = new Gee.LinkedList<AppCenterCore.Package> ();

        int package_count = 0;
        foreach (var package in packages_by_release_date) {
            if (package_count >= MAX_PACKAGES_IN_BANNER) {
                break;
            }

            var installed = false;
            foreach (var origin_package in package.origin_packages) {
                try {
                    if (yield origin_package.backend.is_package_installed (origin_package)) {
                        installed = true;
                        break;
                    }
                } catch (Error e) {
                    continue;
                }
            }

            if (!installed) {
                packages_in_banner.add (package);
                package_count++;
            }
        }

        foreach (var package in packages_in_banner) {
            var banner = new Widgets.Banner (package);
            banner.clicked.connect (() => {
                show_package (package);
            });

            banner_carousel.append (banner);
        }

        banner_revealer.reveal_child = true;

        foreach (var package in packages_by_release_date) {
            // if (recently_updated_carousel.get_children ().length () >= MAX_PACKAGES_IN_CAROUSEL) {
            //     break;
            // }

            var installed = false;
            foreach (var origin_package in package.origin_packages) {
                try {
                    if (yield origin_package.backend.is_package_installed (origin_package)) {
                        installed = true;
                        break;
                    }
                } catch (Error e) {
                    continue;
                }
            }

            if (!installed && !(package in packages_in_banner)) {
                var package_row = new AppCenter.Widgets.ListPackageRowGrid (package);
                recently_updated_carousel.append (package_row);
            }
        }
        recently_updated_revealer.reveal_child = recently_updated_carousel.get_first_child () != null;
    }

    private void banner_timeout_start () {
        if (banner_timeout_id != 0) {
            Source.remove (banner_timeout_id);
        }

        banner_timeout_id = Timeout.add (MILLISECONDS_BETWEEN_BANNER_ITEMS, () => {
            if (!banner_carousel.is_visible ()) {
                return Source.CONTINUE;
            }

            var new_index = (uint) banner_carousel.position + 1;
            var max_index = banner_carousel.n_pages - 1; // 0-based index

            if (banner_carousel.position >= max_index) {
                new_index = 0;
            }

            // banner_carousel.switch_child (new_index, Granite.TRANSITION_DURATION_OPEN);

            return Source.CONTINUE;
        });
    }

    private void banner_timeout_stop () {
        if (banner_timeout_id != 0) {
            Source.remove (banner_timeout_id);
            banner_timeout_id = 0;
        }
    }
}
