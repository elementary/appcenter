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

public class AppCenter.Homepage : Adw.NavigationPage {
    public signal void show_package (AppCenterCore.Package package);
    public signal void show_category (AppStream.Category category);

    private const int MAX_PACKAGES_IN_BANNER = 5;
    private const int MAX_PACKAGES_IN_CAROUSEL = 12;

    private Gtk.FlowBox category_flow;
    private Gtk.ScrolledWindow scrolled_window;

    private Adw.Carousel banner_carousel;
    private Gtk.FlowBox recently_updated_carousel;
    private Gtk.Revealer recently_updated_revealer;
    private Widgets.Banner appcenter_banner;

    private Gtk.Label updates_badge;
    private Gtk.Revealer updates_badge_revealer;

    private uint banner_timeout_id;

    class construct {
        set_css_name ("homepage");
    }

    construct {
        add_css_class (Granite.STYLE_CLASS_VIEW);
        hexpand = true;
        vexpand = true;

        unowned var fp_client = AppCenterCore.FlatpakBackend.get_default ();

        var banner_motion_controller = new Gtk.EventControllerMotion ();

        banner_carousel = new Adw.Carousel () {
            allow_long_swipes = true,
            overflow = VISIBLE
        };
        banner_carousel.add_controller (banner_motion_controller);

        var banner_dots = new Adw.CarouselIndicatorDots () {
            carousel = banner_carousel
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

        category_flow = new Gtk.FlowBox () {
            activate_on_single_click = true,
            homogeneous = true,
            margin_start = 12,
            margin_end =12,
            margin_bottom = 12,
            valign = Gtk.Align.START
        };

        category_flow.set_sort_func ((child1, child2) => {
            var item1 = (CategoryCard) child1;
            var item2 = (CategoryCard) child2;
            if (item1 != null && item2 != null) {
                return item1.category.name.collate (item2.category.name);
            }

            return 0;
        });

        foreach (unowned var category in CategoryManager.get_default ().categories) {
            category_flow.append (new CategoryCard (category));
        }

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (banner_carousel);
        box.append (banner_dots);
        box.append (recently_updated_revealer);
        box.append (categories_label);
        box.append (category_flow);

        scrolled_window = new Gtk.ScrolledWindow () {
            child = box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        var search_button = new Gtk.Button.from_icon_name ("edit-find") {
            action_name = "win.search",
            /// TRANSLATORS: the action of searching
            tooltip_text = C_("action", "Search"),
            valign = CENTER
        };
        search_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var updates_button = new Gtk.Button.from_icon_name ("software-update-available") {
            action_name = "app.show-updates",
            tooltip_text = C_("view", "Updates & installed apps")
        };
        updates_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        updates_badge = new Gtk.Label ("!");
        updates_badge.add_css_class (Granite.STYLE_CLASS_BADGE);
        fp_client.bind_property (
            "n-updatable-packages", updates_badge, "label", SYNC_CREATE,
            (binding, from_value, ref to_value) => {
                to_value.set_string (from_value.get_uint ().to_string ());
                return true;
            }
        );

        updates_badge_revealer = new Gtk.Revealer () {
            can_target = false,
            child = updates_badge,
            halign = Gtk.Align.END,
            valign = Gtk.Align.START,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        fp_client.bind_property ("has-updatable-packages", updates_badge_revealer, "reveal-child", SYNC_CREATE);

        var updates_overlay = new Gtk.Overlay () {
            child = updates_button
        };
        updates_overlay.add_overlay (updates_badge_revealer);

        var headerbar = new Gtk.HeaderBar () {
            show_title_buttons = true
        };

        if (!Utils.is_running_in_guest_session ()) {
            headerbar.pack_end (updates_overlay);
        }
        headerbar.pack_end (search_button);

        var toolbar_view = new Adw.ToolbarView () {
            content = scrolled_window
        };
        toolbar_view.add_top_bar (headerbar);

        child = toolbar_view;
        title = _("Home");

        var local_package = App.local_package;
        if (local_package != null) {
            var banner = new Widgets.Banner.from_package (local_package);

            banner_carousel.prepend (banner);

            banner.clicked.connect (() => {
                show_package (local_package);
            });
        } else {
            appcenter_banner = new Widgets.Banner (
                _("AppCenter"),
                _("Browse and manage apps"),
                _("The open source, pay-what-you-want app store from elementary. Reviewed and curated by elementary to ensure a native, privacy-respecting, and secure experience. Browse by categories or search and discover new apps. AppCenter is also used for updating your system to the latest and greatest version for new features and fixes."),
                new AppIcon (128) { icon = new ThemedIcon ("io.elementary.appcenter") },
                "#7239b3"
            );
            banner_carousel.append (appcenter_banner);

            banner_carousel.page_changed.connect (page_changed_handler);
        }

        load_banners_and_carousels.begin ((obj, res) => {
            load_banners_and_carousels.end (res);
            banner_timeout_start ();
            banner_motion_controller.enter.connect (banner_timeout_stop);
            banner_motion_controller.leave.connect (banner_timeout_start);
        });

        category_flow.child_activated.connect ((child) => {
            var card = (CategoryCard) child;
            show_category (card.category);
        });

        recently_updated_carousel.child_activated.connect ((child) => {
            var package_row_grid = (AppCenter.Widgets.ListPackageRowGrid) child.get_child ();

            show_package (package_row_grid.package);
        });

        destroy.connect (() => {
            banner_timeout_stop ();
        });
    }

    private void page_changed_handler () {
        banner_carousel.remove (appcenter_banner);
        banner_carousel.page_changed.disconnect (page_changed_handler);
    }

    private async void load_banners_and_carousels () {
        unowned var fp_client = AppCenterCore.FlatpakBackend.get_default ();
        var packages_by_release_date = fp_client.get_featured_packages_by_release_date ();
        var packages_in_banner = new Gee.LinkedList<AppCenterCore.Package> ();

        foreach (var package in packages_by_release_date) {
            if (packages_in_banner.size >= MAX_PACKAGES_IN_BANNER) {
                break;
            }

            var installed = false;
            foreach (var origin_package in package.origin_packages) {
                try {
                    if (AppCenterCore.FlatpakBackend.get_default ().is_package_installed (origin_package)) {
                        installed = true;
                        break;
                    }
                } catch (Error e) {
                    continue;
                }
            }

            if (!installed) {
                packages_in_banner.add (package);

                var banner = new Widgets.Banner.from_package (package);
                banner.clicked.connect (() => {
                    show_package (package);
                });

                banner_carousel.append (banner);
            }
        }

        banner_carousel.scroll_to (banner_carousel.get_nth_page (1), true);

        foreach (var package in packages_by_release_date) {
            if (recently_updated_carousel.get_child_at_index (MAX_PACKAGES_IN_CAROUSEL - 1) != null) {
                break;
            }

            if (package in packages_in_banner) {
                continue;
            }

            var installed = false;
            foreach (var origin_package in package.origin_packages) {
                try {
                    if (AppCenterCore.FlatpakBackend.get_default ().is_package_installed (origin_package)) {
                        installed = true;
                        break;
                    }
                } catch (Error e) {
                    continue;
                }
            }

            if (!installed) {
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

            banner_carousel.scroll_to (banner_carousel.get_nth_page (new_index), true);

            return Source.CONTINUE;
        });
    }

    private void banner_timeout_stop () {
        if (banner_timeout_id != 0) {
            Source.remove (banner_timeout_id);
            banner_timeout_id = 0;
        }
    }

    private class CategoryCard : Gtk.FlowBoxChild {
        public AppStream.Category category { get; construct; }

        public CategoryCard (AppStream.Category category) {
            Object (category: category);
        }

        construct {
            var name_label = new Gtk.Label (category.name) {
                wrap = true,
                max_width_chars = 15
            };

            var box = new Gtk.Box (HORIZONTAL, 6) {
                halign = CENTER,
                valign = CENTER
            };

            if (category.icon != "") {
                var display_image = new Gtk.Image.from_icon_name (category.icon) {
                    halign = END,
                    valign = CENTER,
                };

                box.append (display_image);

                name_label.xalign = 0;
                name_label.halign = START;
            } else {
                name_label.justify = CENTER;
            }

            box.append (name_label);

            var expanded_grid = new Gtk.Grid () {
                hexpand = true,
                vexpand = true
            };

            var content_area = new Gtk.Grid ();
            content_area.attach (box, 0, 0);
            content_area.attach (expanded_grid, 0, 0);
            content_area.add_css_class (Granite.CssClass.CARD);
            content_area.add_css_class ("category");
            content_area.add_css_class (category.id);

            child = content_area;

            if (category.id == "accessibility") {
                name_label.label = category.name.up ();
            } else {
                name_label.label = category.name;
            }

            if (category.id == "science") {
                name_label.justify = CENTER;
            }

            AppCenterCore.FlatpakBackend.get_default ().package_list_changed.connect (() => {
                Idle.add (() => {
                    // Clear the cached categories when the AppStream pool is updated
                    if (visible) {
                        return GLib.Source.REMOVE;
                    }

                    var category_components = category.get_components ();
                    category_components.remove_range (0, category_components.length);

                    return GLib.Source.REMOVE;
                });
            });
        }
    }
}
