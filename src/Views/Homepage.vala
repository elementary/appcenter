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

    private Gtk.FlowBox category_flow;
    private Gtk.ScrolledWindow scrolled_window;

    private Adw.Carousel banner_carousel;
    private Gtk.FlowBox recently_updated_carousel;
    private Gtk.Revealer recently_updated_revealer;
    private Widgets.Banner appcenter_banner;

    private uint banner_timeout_id;

    construct {
        add_css_class (Granite.STYLE_CLASS_VIEW);
        hexpand = true;
        vexpand = true;

        var banner_motion_controller = new Gtk.EventControllerMotion ();

        banner_carousel = new Adw.Carousel () {
            allow_long_swipes = true
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
            var item1 = (AbstractCategoryCard) child1;
            var item2 = (AbstractCategoryCard) child2;
            if (item1 != null && item2 != null) {
                return item1.category.name.collate (item2.category.name);
            }

            return 0;
        });

        var games_card = new GamesCard ();

        category_flow.append (new LegacyCard (_("Accessories"), "applications-accessories", {"Utility"}, "accessories"));
        category_flow.append (new LegacyCard (_("Audio"), "appcenter-audio-symbolic", {"Audio", "Music"}, "audio"));
        category_flow.append (new LegacyCard (_("Communication"), "", {
            "Chat",
            "ContactManagement",
            "Email",
            "InstantMessaging",
            "IRCClient",
            "Telephony",
            "VideoConference"
        }, "communication"));
        category_flow.append (new LegacyCard (_("Development"), "", {
            "Database",
            "Debugger",
            "Development",
            "GUIDesigner",
            "IDE",
            "RevisionControl",
            "TerminalEmulator",
            "WebDevelopment"
        }, "development"));
        category_flow.append (new LegacyCard (_("Education"), "", {"Education"}, "education"));
        category_flow.append (new LegacyCard (_("Finance"), "appcenter-finance-symbolic", {
            "Economy",
            "Finance"
        }, "finance"));
        category_flow.append (games_card);
        category_flow.append (new LegacyCard (_("Graphics"), "", {
            "2DGraphics",
            "3DGraphics",
            "Graphics",
            "ImageProcessing",
            "Photography",
            "RasterGraphics",
            "VectorGraphics"
        }, "graphics"));
        category_flow.append (new LegacyCard (_("Internet"), "applications-internet", {
            "Network",
            "P2P"
        }, "internet"));
        category_flow.append (new LegacyCard (_("Math, Science, & Engineering"), "", {
            "ArtificialIntelligence",
            "Astronomy",
            "Biology",
            "Calculator",
            "Chemistry",
            "ComputerScience",
            "DataVisualization",
            "Electricity",
            "Electronics",
            "Engineering",
            "Geology",
            "Geoscience",
            "Math",
            "NumericalAnalysis",
            "Physics",
            "Robotics",
            "Science"
        }, "science"));
        category_flow.append (new LegacyCard (_("Media Production"), "appcenter-multimedia-symbolic", {
            "AudioVideoEditing",
            "Midi",
            "Mixer",
            "Recorder",
            "Sequencer"
        }, "media-production"));
        category_flow.append (new LegacyCard (_("Office"), "appcenter-office-symbolic", {
            "Office",
            "Presentation",
            "Publishing",
            "Spreadsheet",
            "WordProcessor"
        }, "office"));
        category_flow.append (new LegacyCard (_("System"), "applications-system-symbolic", {
            "Monitor",
            "System"
        }, "system"));
        category_flow.append (new LegacyCard (_("Universal Access"), "appcenter-accessibility-symbolic", {"Accessibility"}, "accessibility"));
        category_flow.append (new LegacyCard (_("Video"), "appcenter-video-symbolic", {
            "Tuner",
            "TV",
            "Video"
        }, "video"));
        category_flow.append (new LegacyCard (_("Writing & Language"), "preferences-desktop-locale", {
            "Dictionary",
            "Languages",
            "Literature",
            "OCR",
            "TextEditor",
            "TextTools",
            "Translation",
            "WordProcessor"
        }, "writing-language"));
        category_flow.append (new LegacyCard (_("Privacy & Security"), "preferences-system-privacy", {
            "Security",
        }, "privacy-security"));

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

        append (scrolled_window);

        var local_package = App.local_package;
        if (local_package != null) {
            var banner = new Widgets.Banner (local_package);

            banner_carousel.prepend (banner);

            banner.clicked.connect (() => {
                show_package (local_package);
            });
        } else {
#if PACKAGEKIT_BACKEND
            appcenter_banner = new Widgets.Banner (
                AppCenterCore.PackageKitBackend.get_default ().lookup_package_by_id ("appcenter")
            );
            banner_carousel.append (appcenter_banner);
#endif

            banner_carousel.page_changed.connect (page_changed_handler );
        }

        load_banners_and_carousels.begin ((obj, res) => {
            load_banners_and_carousels.end (res);
            banner_timeout_start ();
        });

        category_flow.child_activated.connect ((child) => {
            var card = (AbstractCategoryCard) child;
            show_category (card.category);
        });

        AppCenterCore.Client.get_default ().installed_apps_changed.connect (() => {
            Idle.add (() => {
                // Clear the cached categories when the AppStream pool is updated
                var child = category_flow.get_first_child ();
                while (child != null) {
                    var item = (AbstractCategoryCard) child;
                    if (item.visible) {
                        continue;
                    }
                    var category_components = item.category.get_components ();
                    category_components.remove_range (0, category_components.length);

                    child = child.get_next_sibling ();
                }

                return GLib.Source.REMOVE;
            });
        });

        banner_motion_controller.enter.connect (() => {
            banner_timeout_stop ();
        });

        banner_motion_controller.leave.connect (() => {
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

                var banner = new Widgets.Banner (package);
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
                    if (yield origin_package.backend.is_package_installed (origin_package)) {
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

        recently_updated_revealer.reveal_child = recently_updated_carousel.get_first_child != null;
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

    private abstract class AbstractCategoryCard : Gtk.FlowBoxChild {
        public AppStream.Category category { get; protected set; }

        protected Gtk.Grid content_area;

        protected static Gtk.CssProvider category_provider;

        static construct {
            category_provider = new Gtk.CssProvider ();
            category_provider.load_from_resource ("io/elementary/appcenter/categories.css");
        }

        construct {
            var expanded_grid = new Gtk.Grid () {
                hexpand = true,
                vexpand = true
            };

            content_area = new Gtk.Grid ();
            content_area.attach (expanded_grid, 0, 0);
            content_area.add_css_class (Granite.STYLE_CLASS_CARD);
            content_area.add_css_class (Granite.STYLE_CLASS_ROUNDED);
            content_area.add_css_class ("category");
            content_area.get_style_context ().add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            child = content_area;
        }
    }

    private class LegacyCard : AbstractCategoryCard {
        public LegacyCard (string name, string icon, string[] groups, string style) {
            category = new AppStream.Category ();
            category.set_name (name);
            category.set_icon (icon);

            foreach (var group in groups) {
                category.add_desktop_group (group);
            }

            var name_label = new Gtk.Label (null);
            name_label.wrap = true;
            name_label.max_width_chars = 15;
            name_label.get_style_context ().add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };

            if (category.icon != "") {
                var display_image = new Gtk.Image.from_icon_name (category.icon) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.CENTER,
                    pixel_size = 48
                };

                box.append (display_image);

                name_label.xalign = 0;
                name_label.halign = Gtk.Align.START;
            } else {
                name_label.justify = Gtk.Justification.CENTER;
            }

            box.append (name_label);

            content_area.attach (box, 0, 0);
            content_area.add_css_class (style);

            if (style == "accessibility") {
                name_label.label = category.name.up ();
            } else {
                name_label.label = category.name;
            }

            if (style == "science") {
                name_label.justify = Gtk.Justification.CENTER;
            }
        }
    }

    private class GamesCard : AbstractCategoryCard {
        construct {
            category = new AppStream.Category () {
                name = _("Fun & Games"),
                icon = "appcenter-games-symbolic"
            };
            category.add_desktop_group ("ActionGame");
            category.add_desktop_group ("AdventureGame");
            category.add_desktop_group ("Amusement");
            category.add_desktop_group ("ArcadeGame");
            category.add_desktop_group ("BlocksGame");
            category.add_desktop_group ("BoardGame");
            category.add_desktop_group ("CardGame");
            category.add_desktop_group ("Game");
            category.add_desktop_group ("KidsGame");
            category.add_desktop_group ("LogicGame");
            category.add_desktop_group ("RolePlaying");
            category.add_desktop_group ("Shooter");
            category.add_desktop_group ("Simulation");
            category.add_desktop_group ("SportsGame");
            category.add_desktop_group ("StrategyGame");

            var image = new Gtk.Image () {
                icon_name = "appcenter-games-symbolic",
                pixel_size = 64
            };
            image.add_css_class (Granite.STYLE_CLASS_ACCENT);
            image.add_css_class ("slate");

            var fun_label = new Gtk.Label (_("Fun &")) {
                halign = Gtk.Align.START
            };

            unowned var fun_label_context = fun_label.get_style_context ();
            fun_label_context.add_class (Granite.STYLE_CLASS_ACCENT);
            fun_label_context.add_class ("pink");
            fun_label_context.add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var games_label = new Gtk.Label (_("Games"));
            games_label.add_css_class (Granite.STYLE_CLASS_ACCENT);
            games_label.add_css_class ("blue");
            games_label.get_style_context ().add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var grid = new Gtk.Grid () {
                column_spacing = 12,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            grid.attach (image, 0, 0, 1, 2);
            grid.attach (fun_label, 1, 0);
            grid.attach (games_label, 1, 1);

            content_area.attach (grid, 0, 0);
            content_area.add_css_class ("games");
        }
    }
}
