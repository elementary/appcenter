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

public class AppCenter.Homepage : AbstractView {
    private const int MAX_PACKAGES_IN_BANNER = 5;
    private const int MAX_PACKAGES_IN_CAROUSEL = 12;

    private Gtk.FlowBox category_flow;
    private Gtk.ScrolledWindow scrolled_window;

    public signal void page_loaded ();

    public bool viewing_package {
        get {
            return visible_child is Views.AppInfoView;
        }
    }

    public AppStream.Category? currently_viewed_category {
        get {
            if (visible_child is CategoryView) {
                return ((CategoryView) visible_child).category;
            }

            return null;
        }
    }

    private Hdy.Carousel banner_carousel;
    private Gtk.Revealer banner_revealer;
    private Gtk.FlowBox recently_updated_carousel;
    private Gtk.Revealer recently_updated_revealer;
    private AppCenter.Views.AppListView search_view;

    private uint banner_timeout_id;

    construct {
        banner_carousel = new Hdy.Carousel () {
            allow_long_swipes = true
        };

        var banner_event_box = new Gtk.EventBox ();
        banner_event_box.events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
        banner_event_box.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        banner_event_box.add (banner_carousel);

        var banner_dots = new Hdy.CarouselIndicatorDots () {
            carousel = banner_carousel
        };

        var banner_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL
        };
        banner_grid.add (banner_event_box);
        banner_grid.add (banner_dots);

        banner_revealer = new Gtk.Revealer ();
        banner_revealer.add (banner_grid);

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

        recently_updated_revealer = new Gtk.Revealer ();
        recently_updated_revealer.add (recently_updated_grid );

        var categories_label = new Granite.HeaderLabel (_("Categories")) {
            margin_start = 24,
            margin_top = 24
        };

        category_flow = new Widgets.CategoryFlowBox () {
            margin_start = 12,
            margin_end =12,
            valign = Gtk.Align.START
        };

        var grid = new Gtk.Grid () {
            column_spacing = 24,
            orientation = Gtk.Orientation.VERTICAL
        };
        grid.add (banner_revealer);
        grid.add (recently_updated_revealer);
        grid.add (categories_label);
        grid.add (category_flow);

        scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        scrolled_window.add (grid);

        add (scrolled_window);

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

        category_flow.child_activated.connect ((child) => {
            var item = child as Widgets.CategoryItem;
            if (item != null) {
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

                return GLib.Source.REMOVE;
            });
        });

        banner_event_box.enter_notify_event.connect (() => {
            banner_timeout_stop ();
        });

        banner_event_box.leave_notify_event.connect (() => {
            banner_timeout_start ();
        });

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

            banner_carousel.add (banner);
        }

        banner_carousel.show_all ();
        banner_revealer.reveal_child = true;

        foreach (var package in packages_by_release_date) {
            if (recently_updated_carousel.get_children ().length () >= MAX_PACKAGES_IN_CAROUSEL) {
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

            if (!installed && !(package in packages_in_banner)) {
                var package_row = new AppCenter.Widgets.ListPackageRowGrid (package);
                recently_updated_carousel.add (package_row);
            }
        }
        recently_updated_carousel.show_all ();
        recently_updated_revealer.reveal_child = recently_updated_carousel.get_children ().length () > 0;

        page_loaded ();
    }

    public override void update_navigation () {
        var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();

        var previous_child = get_adjacent_child (Hdy.NavigationDirection.BACK);

        if (visible_child == scrolled_window) {
            main_window.set_custom_header (null);
            main_window.configure_search (true, _("Search Apps"), "");
        } else if (visible_child is CategoryView) {
            var current_category = ((CategoryView) visible_child).category;
            main_window.set_custom_header (current_category.name);
            main_window.configure_search (true, _("Search %s").printf (current_category.name), "");
        } else if (visible_child == search_view) {
            if (previous_child is CategoryView) {
                var previous_category = ((CategoryView) previous_child).category;
                main_window.configure_search (true, _("Search %s").printf (previous_category.name));
                main_window.set_custom_header (previous_category.name);
            } else {
                main_window.set_custom_header (null);
            }
        }

        if (previous_child == scrolled_window) {
            main_window.set_return_name (_("Home"));
        } else if (previous_child == search_view) {
            /// TRANSLATORS: the name of the Search view
            main_window.set_return_name (C_("view", "Search"));
        }
    }

    public void search (string search_term, bool mimetype = false) {
        if (search_term == "") {
            // Prevent navigating away from category views when backspacing
            if (visible_child == search_view) {
                navigate (Hdy.NavigationDirection.BACK);
            }

            return;
        }

        if (visible_child != search_view) {
            search_view = new AppCenter.Views.AppListView ();
            search_view.show_all ();

            search_view.show_app.connect ((package) => {
                show_package (package);
            });

            add (search_view);
            visible_child = search_view;
        }

        search_view.clear ();
        search_view.current_search_term = search_term;

        unowned var client = AppCenterCore.Client.get_default ();

        Gee.Collection<AppCenterCore.Package> found_apps;

        if (mimetype) {
            found_apps = client.search_applications_mime (search_term);
            search_view.add_packages (found_apps);
        } else {
            AppStream.Category current_category = null;

            var previous_child = get_adjacent_child (Hdy.NavigationDirection.BACK);
            if (previous_child is CategoryView) {
                current_category = ((CategoryView) previous_child).category;
            }

            found_apps = client.search_applications (search_term, current_category);
            search_view.add_packages (found_apps);
        }
    }

    public void show_app_list_for_category (AppStream.Category category) {
        var child = get_child_by_name (category.name);
        if (child != null) {
            visible_child = child;
            return;
        }

        var category_view = new CategoryView (category);

        add (category_view);
        visible_child = category_view;

        category_view.show_app.connect ((package) => {
            base.show_package (package);

            var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();
            main_window.set_return_name (category.name);
        });
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

            banner_carousel.switch_child (new_index, Granite.TRANSITION_DURATION_OPEN);

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
