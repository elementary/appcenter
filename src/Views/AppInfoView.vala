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
        public signal void show_other_package (AppCenterCore.Package package);

        static Gtk.CssProvider? previous_css_provider = null;

        GenericArray<AppStream.Screenshot> screenshots;

        private Gtk.Label app_screenshot_not_found;
        private Gtk.Stack app_screenshots;
        private Gtk.Label app_version;
        private Gtk.Label app_download_size_label;
        private Gtk.ListBox extension_box;
        private Gtk.Grid release_grid;
        private Widgets.ReleaseListBox release_list_box;
        private Gtk.Stack screenshot_stack;
        private Gtk.TextView app_description;
        private Widgets.Switcher screenshot_switcher;
        private Gtk.Stack app_download_stack;

        public AppInfoView (AppCenterCore.Package package) {
            Object (package: package);
        }

        construct {
            inner_image.margin_top = 12;
            inner_image.pixel_size = 128;

            action_button.suggested_action = true;

            var uninstall_button_context = uninstall_button.get_style_context ();
            uninstall_button_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            uninstall_button_context.add_class (Granite.STYLE_CLASS_H3_LABEL);

            var package_component = package.component;

            screenshots = package_component.get_screenshots ();

            if (screenshots.length > 0) {
                app_screenshots = new Gtk.Stack ();
                app_screenshots.width_request = 800;
                app_screenshots.height_request = 500;
                app_screenshots.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
                app_screenshots.halign = Gtk.Align.CENTER;

                screenshot_switcher = new Widgets.Switcher ();
                screenshot_switcher.halign = Gtk.Align.CENTER;
                screenshot_switcher.set_stack (app_screenshots);

                var app_screenshot_spinner = new Gtk.Spinner ();
                app_screenshot_spinner.halign = Gtk.Align.CENTER;
                app_screenshot_spinner.valign = Gtk.Align.CENTER;
                app_screenshot_spinner.active = true;

                app_screenshot_not_found = new Gtk.Label (_("Screenshot Not Available"));
                app_screenshot_not_found.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                app_screenshot_not_found.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

                screenshot_stack = new Gtk.Stack ();
                screenshot_stack.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);
                screenshot_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
                screenshot_stack.add (app_screenshot_spinner);
                screenshot_stack.add (app_screenshots);
                screenshot_stack.add (app_screenshot_not_found);
            }

            package_name.selectable = true;
            package_name.xalign = 0;
            package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
            package_name.valign = Gtk.Align.END;

            app_version = new Gtk.Label (null);
            app_version.margin_top = 12;
            app_version.xalign = 0;
            app_version.hexpand = true;
            app_version.valign = Gtk.Align.CENTER;
            app_version.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            app_version.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            package_author.selectable = true;
            package_author.xalign = 0;
            package_author.valign = Gtk.Align.START;
            package_author.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            package_author.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

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

            var content_grid = new Gtk.Grid ();
            content_grid.width_request = 800;
            content_grid.halign = Gtk.Align.CENTER;
            content_grid.hexpand = true;
            content_grid.margin = 48;
            content_grid.row_spacing = 24;
            content_grid.orientation = Gtk.Orientation.VERTICAL;

            if (screenshots.length > 0) {
                content_grid.add (screenshot_stack);
                content_grid.add (screenshot_switcher);
            }

            if (!package.is_os_updates) {
                content_grid.add (package_summary);
            }

            content_grid.add (app_description);

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

            content_grid.add (release_grid);

            if (package_component.get_addons ().length > 0) {
                extension_box = new Gtk.ListBox ();
                extension_box.selection_mode = Gtk.SelectionMode.NONE;

                var extension_label = new Gtk.Label (_("Extensions:"));
                extension_label.margin_top = 12;
                extension_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
                extension_label.halign = Gtk.Align.START;

                content_grid.add (extension_label);
                content_grid.add (extension_box);
                load_extensions.begin ();
            }

            var header_grid = new Gtk.Grid ();
            header_grid.column_spacing = 12;
            header_grid.row_spacing = 6;
            header_grid.row_homogeneous = false;
            header_grid.halign = Gtk.Align.CENTER;
            header_grid.margin =  content_grid.margin / 2;
            /* Must wide enought to fit long package name and progress bar */
            header_grid.width_request = content_grid.width_request + 2 * (content_grid.margin - header_grid.margin);
            header_grid.hexpand = true;
            header_grid.attach (image, 0, 0, 1, 2);
            header_grid.attach (package_name, 1, 0);

            if (!package.is_os_updates) {
                header_grid.attach (package_author, 1, 1, 2);
                header_grid.attach (app_version, 2, 0, 1, 1);
            } else {
                package_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                header_grid.attach (package_summary, 1, 2, 2, 1);
            }

            action_stack.valign = Gtk.Align.END;
            action_stack.halign = Gtk.Align.END;
            action_stack.hexpand = true;

            /* This is required to stop any button movement when switch from button_grid to the
             * progress grid */
            progress_grid.margin_end = 6;
            progress_grid.margin_top = 12;
            button_grid.margin_top = progress_grid.margin_top;

            header_grid.attach (action_stack, 3, 0, 1, 1);

            if (!package.is_local) {
                app_download_size_label = new Gtk.Label (null);
                app_download_size_label.halign = Gtk.Align.END;
                app_download_size_label.valign = Gtk.Align.START;
                app_download_size_label.xalign = 1;
                app_download_size_label.margin_end = open_button.margin_end;
                action_button_group.add_widget (app_download_size_label);
                app_download_size_label.selectable = true;
                /* We hide the label with a stack in order to stop the size requisition changing */
                app_download_stack = new Gtk.Stack ();
                app_download_stack.margin_end = 6;
                app_download_stack.add_named (app_download_size_label, "CHILD");
                app_download_stack.add_named (new Gtk.EventBox (), "NONE");
                app_download_stack.hhomogeneous = false;
                app_download_stack.set_visible_child_name ("NONE");
                header_grid.attach (app_download_stack, 3, 1, 1, 1);
            }

            var header_box = new Gtk.Grid ();
            header_box.get_style_context ().add_class ("banner");
            header_box.hexpand = true;
            header_box.add (header_grid);

            var footer_grid = new Gtk.Grid ();
            footer_grid.halign = Gtk.Align.CENTER;
            footer_grid.margin = 12;
            footer_grid.width_request = 800;

            var project_license = package.component.project_license;
            if (project_license != null) {
                string? license_copy;
                string? license_url;
                if (project_license.has_prefix ("LicenseRef")) {
                    // i.e. `LicenseRef-proprietary=https://example.com`
                    var split_license = project_license.split_set ("=", 2);

                    var license_type = split_license[0].split_set ("-", 2)[1];
                    var pretty_license_type = license_type.substring (0, 1).up () + license_type.substring (1);

                    license_copy = _("%s License").printf (pretty_license_type);
                    license_url = split_license[1];
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
                footer_grid.add (license_button);
            }

            footer_grid.add (links_grid);

            var grid = new Gtk.Grid ();
            grid.row_spacing = 12;
            grid.attach (header_box, 0, 0, 1, 1);
            grid.attach (content_grid, 0, 1, 1, 1);
            grid.attach (footer_grid, 0, 2, 1, 1);

            if (package.author != null) {
                var other_apps_header = new Gtk.Label (_("Other Apps by %s").printf (package.author_title));
                other_apps_header.xalign = 0;
                other_apps_header.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

                var other_apps_carousel = new AppCenter.Widgets.AuthorCarousel (package);
                other_apps_carousel.package_activated.connect ((package) => show_other_package (package));

                var other_apps_grid = new Gtk.Grid ();
                other_apps_grid.halign = Gtk.Align.CENTER;
                other_apps_grid.row_spacing = 12;
                other_apps_grid.margin = 24;
                other_apps_grid.width_request = 800;
                other_apps_grid.orientation = Gtk.Orientation.VERTICAL;
                other_apps_grid.add (other_apps_header);
                other_apps_grid.add (other_apps_carousel);

                var other_apps_bar = new Gtk.Grid ();
                other_apps_bar.add (other_apps_grid);

                var other_apps_style_context = other_apps_bar.get_style_context ();
                other_apps_style_context.add_class (Gtk.STYLE_CLASS_TOOLBAR);
                other_apps_style_context.add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
                other_apps_style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);

                if (other_apps_carousel.get_children ().length () > 0) {
                    grid.attach (other_apps_bar, 0, 3, 1, 1);
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
            reload_css ();
            set_up_package (128);
            parse_description (package.get_description ());

            if (package.is_os_updates) {
                package.notify["state"].connect (() => {
                    Idle.add (() => {
                        parse_description (package.get_description());
                        return false;
                    });
                });
            }
        }

        protected override void update_state (bool first_update = false) {
            if (!first_update) {
                app_version.label = package.get_version ();
            }

            app_download_stack.set_visible_child_name (package.state == AppCenterCore.Package.State.NOT_INSTALLED ?
                                                       "CHILD" : "NONE");
            app_download_size_label.label = "";
            if (package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                get_app_download_size.begin ();
            }

            update_action ();
        }

        private async void load_extensions () {
            package.component.get_addons ().@foreach ((extension) => {
                var row = new Widgets.PackageRow.list (new AppCenterCore.Package (package.backend, extension), null, null, false);
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

            app_download_size_label.label = GLib.format_size (size);
            app_download_stack.set_visible_child_name ("CHILD");
        }

        public void reload_css () {
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

        public void load_more_content (AppCenterCore.ScreenshotCache? cache) {
            if (cache == null) {
                warning ("screenshots cannot be loaded, because the cache could not be created.\n");
                return;
            }

            new Thread<void*> ("content-loading", () => {
                app_version.label = package.get_version ();
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

                screenshots.foreach ((screenshot) => {
                    screenshot.get_images ().foreach ((image) => {
                        if (image.get_kind () == AppStream.ImageKind.SOURCE) {
                            if (screenshot.get_kind () == AppStream.ScreenshotKind.DEFAULT) {
                                urls.prepend (image.get_url ());
                            } else {
                                urls.append (image.get_url ());
                            }

                            return;
                        }
                    });
                });

                string?[] screenshot_files = new string?[urls.length ()];
                int[] results = new int[urls.length ()];
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

                cache.maintain ();

                // TODO: dynamically load screenshots as they become available.
                while (urls.length () != completed) {
                    Thread.usleep (100000);
                }

                // Load screenshots that were successfully obtained.
                for (int i = 0; i < urls.length (); i++) {
                    if (0 == results[i]) {
                        load_screenshot (screenshot_files[i]);
                    }
                }

                Idle.add (() => {
                    if (app_screenshots.get_children ().length () > 0) {
                        screenshot_stack.visible_child = app_screenshots;
                        screenshot_switcher.update_selected ();
                    } else {
                        screenshot_stack.visible_child = app_screenshot_not_found;
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
                var pixbuf = new Gdk.Pixbuf.from_file_at_scale (path, 800 * scale_factor, 600 * scale_factor, true);
                var image = new Gtk.Image ();
                image.width_request = 800;
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
                try {
                    app_description.buffer.text = AppStream.markup_convert_simple (description);
                } catch (Error e) {
                    critical (e.message);
                }
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
                                                           package.component.id.replace (".desktop", ""),
                                                           package.get_payments_key ()
                                                          );

                    stripe.download_requested.connect (() => {
                        Settings.get_default ().add_paid_app (package.component.get_id ());
                    });

                    stripe.show ();
                });

                tooltip_text = _("Fund the development of this app");

                direction = Gtk.ArrowType.UP;
                popover = selection;

                add (grid);
            }
        }
    }
}
