// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014–2018 elementary, Inc. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

namespace AppCenter.Views {
    public class AppInfoView : AppCenter.AbstractAppContainer {
        public const int MAX_WIDTH = 800;

        public signal void show_other_package (
            AppCenterCore.Package package,
            bool remember_history = true,
            Gtk.StackTransitionType transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        );

        private static Gtk.CssProvider loading_provider;
        private static Gtk.CssProvider? previous_css_provider = null;

        GenericArray<AppStream.Screenshot> screenshots;

        private Gtk.ComboBox origin_combo;
        private Gtk.Grid release_grid;
        private Gtk.Grid screenshot_arrows;
        private Gtk.Label app_screenshot_not_found;
        private Gtk.Label package_summary;
        private Gtk.ListBox extension_box;
        private Gtk.ListStore origin_liststore;
        private Gtk.Overlay screenshot_overlay;
        private Gtk.Revealer origin_combo_revealer;
        private Hdy.Carousel app_screenshots;
        private Gtk.Stack screenshot_stack;
        private Gtk.StyleContext stack_context;
        private Gtk.TextView app_description;
        private Widgets.ReleaseListBox release_list_box;
        private Widgets.SizeLabel size_label;
        private Hdy.CarouselIndicatorDots screenshot_switcher;

        public bool to_recycle { public get; private set; default = false; }

        public AppInfoView (AppCenterCore.Package package) {
            Object (package: package);
        }

        static construct {
            loading_provider = new Gtk.CssProvider ();
            loading_provider.load_from_resource ("io/elementary/appcenter/loading.css");
        }

        construct {
            AppCenterCore.BackendAggregator.get_default ().cache_flush_needed.connect (() => {
                to_recycle = true;
            });

            inner_image.margin_top = 12;
            inner_image.pixel_size = 128;

            action_button.suggested_action = true;

            var uninstall_button_context = uninstall_button.get_style_context ();
            uninstall_button_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            var package_component = package.component;

            screenshots = package_component.get_screenshots ();

            if (screenshots.length > 0) {
                app_screenshots = new Hdy.Carousel () {
                    height_request = 500
                };

                var screenshot_previous = new ArrowButton ("go-previous-symbolic", Gtk.Align.START);
                screenshot_previous.sensitive = false;
                screenshot_previous.clicked.connect (() => {
                    GLib.List<unowned Gtk.Widget> screenshot_children = app_screenshots.get_children ();
                    var index = app_screenshots.get_position ();
                    if (index > 0) {
                        app_screenshots.scroll_to (screenshot_children.nth_data ((uint) index - 1));
                    }
                });

                var screenshot_next = new ArrowButton ("go-next-symbolic", Gtk.Align.END);
                screenshot_next.clicked.connect (() => {
                    GLib.List<unowned Gtk.Widget> screenshot_children = app_screenshots.get_children ();
                    var index = app_screenshots.get_position ();
                    if (index < screenshot_children.length () - 1) {
                        app_screenshots.scroll_to (screenshot_children.nth_data ((uint) index + 1));
                    }
                });

                app_screenshots.page_changed.connect ((index) => {
                    screenshot_previous.sensitive = screenshot_next.sensitive = true;

                    GLib.List<unowned Gtk.Widget> screenshot_children = app_screenshots.get_children ();

                    if (index == 0) {
                        screenshot_previous.sensitive = false;
                    } else if (index == screenshot_children.length () - 1) {
                        screenshot_next.sensitive = false;
                    }
                });

                var screenshot_arrow_revealer_p = new Gtk.Revealer () {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.CENTER
                };
                screenshot_arrow_revealer_p.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
                screenshot_arrow_revealer_p.add (screenshot_previous);

                var screenshot_arrow_revealer_n = new Gtk.Revealer () {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.CENTER
                };
                screenshot_arrow_revealer_n.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
                screenshot_arrow_revealer_n.add (screenshot_next);

                screenshot_overlay = new Gtk.Overlay ();
                screenshot_overlay.add (app_screenshots);
                screenshot_overlay.add_overlay (screenshot_arrow_revealer_p);
                screenshot_overlay.add_overlay (screenshot_arrow_revealer_n);

                app_screenshots.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK);
                app_screenshots.add_events (Gdk.EventMask.LEAVE_NOTIFY_MASK);
                screenshot_overlay.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK);
                screenshot_overlay.add_events (Gdk.EventMask.LEAVE_NOTIFY_MASK);

                screenshot_overlay.enter_notify_event.connect (() => {
                    screenshot_arrow_revealer_n.reveal_child = true;
                    screenshot_arrow_revealer_p.reveal_child = true;
                    return false;
                });

                screenshot_overlay.leave_notify_event.connect ((event) => {
                    // Prevent hiding prev/next button when they're marked as insensitive
                    if (event.mode != Gdk.CrossingMode.STATE_CHANGED) {
                        screenshot_arrow_revealer_n.reveal_child = false;
                        screenshot_arrow_revealer_p.reveal_child = false;
                    }

                    return false;
                });

                app_screenshots.enter_notify_event.connect (() => {
                    screenshot_arrow_revealer_n.reveal_child = true;
                    screenshot_arrow_revealer_p.reveal_child = true;
                    return false;
                });

                app_screenshots.leave_notify_event.connect ((event) => {
                    // Prevent hiding prev/next button when they're marked as insensitive
                    if (event.mode != Gdk.CrossingMode.STATE_CHANGED) {
                        screenshot_arrow_revealer_n.reveal_child = false;
                        screenshot_arrow_revealer_p.reveal_child = false;
                    }

                    return false;
                });

                screenshot_switcher = new Hdy.CarouselIndicatorDots () {
                    carousel = app_screenshots
                };

                var app_screenshot_spinner = new Gtk.Spinner ();
                app_screenshot_spinner.halign = Gtk.Align.CENTER;
                app_screenshot_spinner.valign = Gtk.Align.CENTER;
                app_screenshot_spinner.active = true;

                app_screenshot_not_found = new Gtk.Label (_("Screenshot Not Available"));
                app_screenshot_not_found.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                app_screenshot_not_found.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

                screenshot_stack = new Gtk.Stack ();
                screenshot_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
                screenshot_stack.add (app_screenshot_spinner);
                screenshot_stack.add (screenshot_overlay);
                screenshot_stack.add (app_screenshot_not_found);

                stack_context = screenshot_stack.get_style_context ();
                stack_context.add_class (Gtk.STYLE_CLASS_BACKGROUND);
                stack_context.add_class ("loading");
                stack_context.add_provider (loading_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }

            package_name.ellipsize = Pango.EllipsizeMode.MIDDLE;
            package_name.selectable = true;
            package_name.xalign = 0;
            package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
            package_name.valign = Gtk.Align.END;

            package_author.selectable = true;
            package_author.xalign = 0;
            package_author.valign = Gtk.Align.START;
            package_author.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            package_summary = new Gtk.Label (null);
            package_summary.label = package.get_summary ();
            package_summary.selectable = true;
            package_summary.xalign = 0;
            package_summary.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
            package_summary.wrap = true;
            package_summary.wrap_mode = Pango.WrapMode.WORD_CHAR;
            package_summary.valign = Gtk.Align.CENTER;

            app_description = new Gtk.TextView ();
            app_description.expand = true;
            app_description.editable = false;
            app_description.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
            app_description.cursor_visible = false;
            app_description.pixels_below_lines = 3;
            app_description.pixels_inside_wrap = 3;
            app_description.wrap_mode = Gtk.WrapMode.WORD_CHAR;

            var links_grid = new Gtk.Grid ();
            links_grid.column_spacing = 12;
            links_grid.halign = Gtk.Align.END;
            links_grid.hexpand = true;

            var homepage_url = package_component.get_url (AppStream.UrlKind.HOMEPAGE);
            if (homepage_url != null) {
                var website_button = new UrlButton (_("Homepage"), homepage_url, "web-browser-symbolic");
                links_grid.add (website_button);
            }

            var translate_url = package_component.get_url (AppStream.UrlKind.TRANSLATE);
            if (translate_url != null) {
                var translate_button = new UrlButton (_("Suggest Translations"), translate_url, "preferences-desktop-locale-symbolic");
                links_grid.add (translate_button);
            }

            var bugtracker_url = package_component.get_url (AppStream.UrlKind.BUGTRACKER);
            if (bugtracker_url != null) {
                var bugtracker_button = new UrlButton (_("Report a Problem"), bugtracker_url, "bug-symbolic");
                links_grid.add (bugtracker_button);
            }

            var help_url = package_component.get_url (AppStream.UrlKind.HELP);
            if (help_url != null) {
                var help_button = new UrlButton (_("Help"), help_url, "dialog-question-symbolic");
                links_grid.add (help_button);
            }

#if PAYMENTS
            if (package.get_payments_key () != null) {
                var fund_button = new FundButton (package);
                links_grid.add (fund_button);
            }
#endif

            var whats_new_label = new Gtk.Label (_("What's New:"));
            whats_new_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
            whats_new_label.xalign = 0;

            release_list_box = new Widgets.ReleaseListBox (package);

            release_grid = new Gtk.Grid ();
            release_grid.row_spacing = 12;
            release_grid.attach (whats_new_label, 0, 0, 1, 1);
            release_grid.attach (release_list_box, 0, 1, 1, 1);
            release_grid.no_show_all = true;
            release_grid.hide ();

            var content_grid = new Gtk.Grid ();
            content_grid.row_spacing = 24;

            if (screenshots.length > 0) {
                content_grid.attach (screenshot_stack, 0, 0, 2);
                content_grid.attach (screenshot_switcher, 0, 1, 2);
            }

            content_grid.attach (package_summary, 0, 2, 2);
            content_grid.attach (app_description, 0, 3, 2);
            content_grid.attach (release_grid, 0, 4, 2);

            if (package_component.get_addons ().length > 0) {
                extension_box = new Gtk.ListBox ();
                extension_box.selection_mode = Gtk.SelectionMode.SINGLE;
                extension_box.row_activated.connect ((row) => {
                    var extension_row = row as Widgets.PackageRow;
                    if (extension_row != null) {
                        show_other_package (extension_row.get_package (), true, Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
                    }
                });

                var extension_label = new Gtk.Label (_("Extensions:"));
                extension_label.margin_top = 12;
                extension_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
                extension_label.halign = Gtk.Align.START;

                content_grid.attach (extension_label, 0, 5, 2);
                content_grid.attach (extension_box, 0, 6, 2);
                load_extensions.begin ();
            }

            origin_liststore = new Gtk.ListStore (2, typeof (AppCenterCore.Package), typeof (string));
            origin_combo = new Gtk.ComboBox.with_model (origin_liststore);
            origin_combo.halign = Gtk.Align.START;
            origin_combo.valign = Gtk.Align.START;
            origin_combo.changed.connect (() => {
                Gtk.TreeIter iter;
                AppCenterCore.Package selected_origin_package;
                origin_combo.get_active_iter (out iter);
                origin_liststore.@get (iter, 0, out selected_origin_package);
                if (selected_origin_package != null && selected_origin_package != package) {
                    show_other_package (selected_origin_package, false, Gtk.StackTransitionType.CROSSFADE);
                }
            });

            origin_combo_revealer = new Gtk.Revealer ();
            origin_combo_revealer.add (origin_combo);

            var renderer = new Gtk.CellRendererText ();
            origin_combo.pack_start (renderer, true);
            origin_combo.add_attribute (renderer, "text", 1);

            action_stack.valign = Gtk.Align.END;
            action_stack.halign = Gtk.Align.END;
            action_stack.hexpand = true;

            /* This is required to stop any button movement when switch from button_grid to the
             * progress grid */
            progress_grid.margin_end = 6;
            progress_grid.margin_top = 12;
            button_grid.margin_top = progress_grid.margin_top;

            var header_grid = new Gtk.Grid ();
            header_grid.column_spacing = 12;
            header_grid.row_spacing = 6;
            header_grid.hexpand = true;
            header_grid.attach (image, 0, 0, 1, 3);
            header_grid.attach (package_name, 1, 0);
            header_grid.attach (package_author, 1, 1);
            header_grid.attach (origin_combo_revealer, 1, 2);
            header_grid.attach (action_stack, 3, 0);

            if (!package.is_local) {
                size_label = new Widgets.SizeLabel ();
                size_label.halign = Gtk.Align.END;
                size_label.valign = Gtk.Align.START;
                size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

                action_button_group.add_widget (size_label);

                header_grid.attach (size_label, 3, 1);
            }

            var header_clamp = new Hdy.Clamp () {
                margin = 24,
                maximum_size = MAX_WIDTH
            };
            header_clamp.add (header_grid);

            var header_box = new Gtk.Grid ();
            header_box.get_style_context ().add_class ("banner");
            header_box.hexpand = true;
            header_box.add (header_clamp);

            var project_license = package.component.project_license;
            if (project_license != null) {
                string? license_copy = null;
                string? license_url = null;

                // NOTE: Ideally this would be handled in AppStream: https://github.com/ximion/appstream/issues/107
                if (project_license.has_prefix ("LicenseRef")) {
                    // i.e. `LicenseRef-proprietary=https://example.com`
                    string[] split_license = project_license.split_set ("=", 2);
                    if (split_license[1] != null) {
                        license_url = split_license[1];
                    }

                    string license_type = split_license[0].split_set ("-", 2)[1].down ();
                    switch (license_type) {
                        case "public-domain":
                            // TRANSLATORS: See the Wikipedia page
                            license_copy = _("Public Domain");
                            if (license_url == null) {
                                // TRANSLATORS: Replace the link with the version for your language
                                license_url = _("https://en.wikipedia.org/wiki/Public_domain");
                            }
                            break;
                        case "free":
                            // TRANSLATORS: Freedom, not price. See the GNU page.
                            license_copy = _("Free Software");
                            if (license_url == null) {
                                // TRANSLATORS: Replace the link with the version for your language
                                license_url = _("https://www.gnu.org/philosophy/free-sw");
                            }
                            break;
                        case "proprietary":
                            license_copy = _("Proprietary");
                            break;
                        default:
                            license_copy = _("Unknown License");
                    }
                } else {
                    license_copy = project_license;
                    license_url = "https://choosealicense.com/licenses/";

                    switch (project_license) {
                        case "Apache-2.0":
                            license_url = license_url + "apache-2.0";
                            break;
                        case "GPL-2":
                        case "GPL-2.0":
                        case "GPL-2.0+":
                            license_url = license_url + "gpl-2.0";
                            break;
                        case "GPL-3":
                        case "GPL-3.0":
                        case "GPL-3.0+":
                            license_url = license_url + "gpl-3.0";
                            break;
                        case "LGPL-2.1":
                        case "LGPL-2.1+":
                            license_url = license_url + "lgpl-2.1";
                            break;
                        case "MIT":
                            license_url = license_url + "mit";
                            break;
                    }
                }

                var license_button = new UrlButton (_(license_copy), license_url, "text-x-copying-symbolic");
                license_button.hexpand = true;

                content_grid.attach (license_button, 0, 7);
            }

            content_grid.attach (links_grid, 1, 7);

            var body_clamp = new Hdy.Clamp () {
                margin = 24,
                maximum_size = MAX_WIDTH
            };
            body_clamp.add (content_grid);

            var grid = new Gtk.Grid ();
            grid.row_spacing = 12;
            grid.attach (header_box, 0, 0, 1, 1);
            grid.attach (body_clamp, 0, 1);

            if (package.author != null) {
                var other_apps_header = new Gtk.Label (_("Other Apps by %s").printf (package.author_title));
                other_apps_header.xalign = 0;
                other_apps_header.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

                var other_apps_carousel = new AppCenter.Widgets.AuthorCarousel (package);
                other_apps_carousel.package_activated.connect ((package) => show_other_package (package));

                var other_apps_grid = new Gtk.Grid ();
                other_apps_grid.orientation = Gtk.Orientation.VERTICAL;
                other_apps_grid.row_spacing = 12;
                other_apps_grid.width_request = MAX_WIDTH;
                other_apps_grid.add (other_apps_header);
                other_apps_grid.add (other_apps_carousel);

                var other_apps_clamp = new Hdy.Clamp () {
                    margin = 24,
                    maximum_size = MAX_WIDTH
                };
                other_apps_clamp.add (other_apps_grid);

                var other_apps_bar = new Gtk.Grid ();
                other_apps_bar.add (other_apps_clamp);

                unowned Gtk.StyleContext other_apps_style_context = other_apps_bar.get_style_context ();
                other_apps_style_context.add_class (Gtk.STYLE_CLASS_TOOLBAR);
                other_apps_style_context.add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
                other_apps_style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);

                if (other_apps_carousel.get_children ().length () > 0) {
                    grid.attach (other_apps_bar, 0, 3);
                }
            }

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled.expand = true;
            scrolled.add (grid);

            var toast = new Granite.Widgets.Toast (_("Link copied to clipboard"));

            var overlay = new Gtk.Overlay ();
            overlay.add (scrolled);
            overlay.add_overlay (toast);

            add (overlay);

            open_button.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
#if SHARING
            if (package.is_shareable) {
                var body = _("Check out %s on AppCenter:").printf (package.get_name ());
                var uri = "https://appcenter.elementary.io/%s".printf (package.component.get_id ());
                var share_popover = new SharePopover (body, uri);

                var share_icon = new Gtk.Image.from_icon_name ("send-to-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                share_icon.valign = Gtk.Align.CENTER;

                var share_label = new Gtk.Label (_("Share"));

                var share_grid = new Gtk.Grid ();
                share_grid.column_spacing = 6;
                share_grid.add (share_icon);
                share_grid.add (share_label);

                var share_button = new Gtk.MenuButton ();
                share_button.direction = Gtk.ArrowType.UP;
                share_button.popover = share_popover;
                share_button.add (share_grid);

                var share_button_context = share_button.get_style_context ();
                share_button_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                share_button_context.add_class (Gtk.STYLE_CLASS_FLAT);

                share_popover.link_copied.connect (() => {
                    toast.send_notification ();
                });

                links_grid.add (share_button);
            }
#endif
            view_entered ();
            set_up_package (128);

            if (package.is_os_updates) {
                package.notify["state"].connect (() => {
                    Idle.add (() => {
                        // For the OS updates component, this is the "x components with updates" text
                        package_author.label = package.get_version ();

                        parse_description (package.get_description ());
                        return false;
                    });
                });
            }
        }

        protected override void update_state (bool first_update = false) {
            size_label.update ();
            if (package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                get_app_download_size.begin ();
            }

            update_action ();
        }

        private async void load_extensions () {
            package.component.get_addons ().@foreach ((extension) => {
                var extension_package = package.backend.get_package_for_component_id (extension.id);
                if (extension_package == null) {
                    return;
                }

                var row = new Widgets.PackageRow.list (extension_package);
                if (extension_box != null) {
                    extension_box.add (row);
                }
            });
        }

        private async void get_app_download_size () {
            if (package.state == AppCenterCore.Package.State.INSTALLED) {
                return;
            }

            var size = yield package.get_download_size_including_deps ();
            size_label.update (size, package.is_flatpak);
        }

        public void view_entered () {
            Gtk.TreeIter iter;
            AppCenterCore.Package origin_package;
            if (origin_liststore.get_iter_first (out iter)) {
                do {
                    origin_liststore.@get (iter, 0, out origin_package);
                    if (origin_package == package) {
                        origin_combo.set_active_iter (iter);
                    }
                } while (origin_liststore.iter_next (ref iter));
            }

            var provider = new Gtk.CssProvider ();
            try {
                string color_primary;
                string color_primary_text;
                if (package != null) {
                    color_primary = package.get_color_primary ();
                    color_primary_text = package.get_color_primary_text ();
                } else {
                    color_primary = null;
                    color_primary_text = null;
                }

                if (color_primary == null) {
                    color_primary = DEFAULT_BANNER_COLOR_PRIMARY;
                }

                if (color_primary_text == null) {
                    color_primary_text = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;
                }
                var colored_css = BANNER_STYLE_CSS.printf (color_primary, color_primary_text);
                provider.load_from_data (colored_css, colored_css.length);

                if (previous_css_provider != null) {
                    Gtk.StyleContext.remove_provider_for_screen (Gdk.Screen.get_default (), previous_css_provider);
                }

                previous_css_provider = provider;
                Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (GLib.Error e) {
                critical (e.message);
            }
        }

        public void load_more_content (AppCenterCore.ScreenshotCache cache) {
            Gtk.TreeIter iter;
            uint count = 0;
            foreach (var origin_package in package.origin_packages) {
                origin_liststore.append (out iter);
                origin_liststore.set (iter, 0, origin_package, 1, origin_package.origin_description);
                if (origin_package == package) {
                    origin_combo.set_active_iter (iter);
                }

                count++;
                if (count > 1) {
                    origin_combo_revealer.reveal_child = true;
                }
            }

            new Thread<void*> ("content-loading", () => {
                if (package.is_os_updates) {
                    package_author.label = package.get_version ();
                }

                parse_description (package.get_description ());

                get_app_download_size.begin ();

                Idle.add (() => {
                    if (release_list_box.populate ()) {
                        release_grid.no_show_all = false;
                        release_grid.show_all ();
                    }

                    return false;
                });

                if (screenshots.length == 0) {
                    return null;
                }

                List<string> urls = new List<string> ();

                var scale = get_scale_factor ();
                var min_screenshot_width = MAX_WIDTH * scale;

                screenshots.foreach ((screenshot) => {
                    AppStream.Image? best_image = null;
                    screenshot.get_images ().foreach ((image) => {
                        // Image is better than no image
                        if (best_image == null) {
                            best_image = image;
                        }

                        // If our current best is less than the minimum and we have a bigger image, choose that instead
                        if (best_image.get_width () < min_screenshot_width && image.get_width () >= best_image.get_width ()) {
                            best_image = image;
                        }

                        // If our new image is smaller than the current best, but still bigger than the minimum, pick that
                        if (image.get_width () < best_image.get_width () && image.get_width () >= min_screenshot_width) {
                            best_image = image;
                        }
                    });

                    if (screenshot.get_kind () == AppStream.ScreenshotKind.DEFAULT && best_image != null) {
                        urls.prepend (best_image.get_url ());
                    } else if (best_image != null) {
                        urls.append (best_image.get_url ());
                    }
                });

                string?[] screenshot_files = new string?[urls.length ()];
                bool[] results = new bool[urls.length ()];
                int completed = 0;

                // Fetch each screenshot in parallel.
                for (int i = 0; i < urls.length (); i++) {
                    string url = urls.nth_data (i);
                    string? file = null;
                    int index = i;

                    cache.fetch.begin (url, (obj, res) => {
                        results[index] = cache.fetch.end (res, out file);
                        screenshot_files[index] = file;
                        completed++;
                    });
                }

                // TODO: dynamically load screenshots as they become available.
                while (urls.length () != completed) {
                    Thread.usleep (100000);
                }

                // Load screenshots that were successfully obtained.
                for (int i = 0; i < urls.length (); i++) {
                    if (results[i] == true) {
                        load_screenshot (screenshot_files[i]);
                    }
                }

                Idle.add (() => {
                    var number_of_screenshots = app_screenshots.get_children ().length ();

                    if (number_of_screenshots > 0) {
                        screenshot_stack.visible_child = screenshot_overlay;
                        stack_context.remove_class ("loading");

                        if (number_of_screenshots > 1) {
                            screenshot_arrows.no_show_all = false;
                            screenshot_arrows.show_all ();
                        }
                    } else {
                        screenshot_stack.visible_child = app_screenshot_not_found;
                        stack_context.remove_class ("loading");
                    }

                    return GLib.Source.REMOVE;
                });

                return null;
            });
        }

        // We need to first download the screenshot locally so that it doesn't freeze the interface.
        private void load_screenshot (string path) {
            var scale_factor = get_scale_factor ();
            try {
                var pixbuf = new Gdk.Pixbuf.from_file_at_scale (path, MAX_WIDTH * scale_factor, 600 * scale_factor, true);
                var image = new Gtk.Image ();
                image.width_request = MAX_WIDTH;
                image.height_request = 500;
                image.icon_name = "image-x-generic";
                image.halign = Gtk.Align.CENTER;
                image.gicon = pixbuf;

                Idle.add (() => {
                    image.show ();
                    app_screenshots.add (image);
                    return GLib.Source.REMOVE;
                });
            } catch (Error e) {
                critical (e.message);
            }
        }

        private void parse_description (string? description) {
            if (description != null) {
                string[] lines = description.split ("\n");
                string stripped_description = lines[0].strip ();
                for (int i = 1; i < lines.length; i++) {
                    stripped_description += " " + lines[i].strip ();
                }

                // This method may be called in a thread, pass back to GTK thread
                Idle.add (() => {
                    try {
                        app_description.buffer.text = AppStream.markup_convert_simple (stripped_description);
                    } catch (Error e) {
                        warning ("Failed to parse appstream description: %s", e.message);
                    }

                    return false;
                });
            }
        }

        class UrlButton : Gtk.Grid {
            public UrlButton (string label, string? uri, string icon_name) {
                get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                tooltip_text = uri;

                var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.SMALL_TOOLBAR);
                icon.valign = Gtk.Align.CENTER;

                var title = new Gtk.Label (label);
                title.ellipsize = Pango.EllipsizeMode.END;

                var grid = new Gtk.Grid ();
                grid.column_spacing = 6;
                grid.add (icon);
                grid.add (title);

                if (uri != null) {
                    var button = new Gtk.Button ();
                    button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

                    button.add (grid);
                    add (button);

                    button.clicked.connect (() => {
                        try {
                            AppInfo.launch_default_for_uri (uri, null);
                        } catch (Error e) {
                            warning ("%s\n", e.message);
                        }
                    });
                } else {
                    add (grid);
                }
            }
        }

        class FundButton : Gtk.MenuButton {
            private Widgets.HumblePopover selection;

            public FundButton (AppCenterCore.Package package) {
                get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

                var icon = new Gtk.Image.from_icon_name ("credit-card-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                icon.valign = Gtk.Align.CENTER;

                var title = new Gtk.Label (_("Fund"));

                var grid = new Gtk.Grid ();
                grid.column_spacing = 6;
                grid.add (icon);
                grid.add (title);

                selection = new Widgets.HumblePopover (this, true);
                selection.payment_requested.connect ((amount) => {
                    var stripe = new Widgets.StripeDialog (amount,
                                                           package.get_name (),
                                                           package.normalized_component_id,
                                                           package.get_payments_key ()
                                                          );

                    stripe.download_requested.connect (() => {
                        App.add_paid_app (package.component.get_id ());
                    });

                    stripe.show ();
                });

                tooltip_text = _("Fund the development of this app");

                direction = Gtk.ArrowType.UP;
                popover = selection;

                add (grid);
            }
        }

        private class ArrowButton : Gtk.Button {
            private static Gtk.CssProvider arrow_provider;

            public ArrowButton (string icon_name, Gtk.Align halign) {
                Object (
                    halign: halign,
                    image: new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR)
                );
            }

            static construct {
                arrow_provider = new Gtk.CssProvider ();
                arrow_provider.load_from_resource ("io/elementary/appcenter/arrow.css");
            }

            construct {
                expand = true;
                valign = Gtk.Align.CENTER;

                unowned Gtk.StyleContext context = get_style_context ();
                context.add_class (Gtk.STYLE_CLASS_FLAT);
                context.add_class ("circular");
                context.add_class ("arrow");
                context.add_provider (arrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }
        }
    }
}
