// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2017 elementary LLC. (https://elementary.io)
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
        private Cancellable app_download_size_cancellable;
        private Gtk.ListBox extension_box;
        private Gtk.Grid release_grid;
        private Widgets.ReleaseListBox release_list_box;
        private Gtk.Stack screenshot_stack;
        private Gtk.TextView app_description;
        private Widgets.Switcher screenshot_switcher;

        public AppInfoView (AppCenterCore.Package package) {
            Object (package: package);
        }

        construct {
            image.margin_top = 12;
            image.margin_start = 6;
            image.pixel_size = 128;

            action_button.suggested_action = true;

            var uninstall_button_context = uninstall_button.get_style_context ();
            uninstall_button_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            uninstall_button_context.add_class ("h3");

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
                app_screenshot_not_found.get_style_context ().add_class ("h2");

                screenshot_stack = new Gtk.Stack ();
                screenshot_stack.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);
                screenshot_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
                screenshot_stack.add (app_screenshot_spinner);
                screenshot_stack.add (app_screenshots);
                screenshot_stack.add (app_screenshot_not_found);
            }

            package_name = new Gtk.Label (null);
            package_name.margin_top = 12;
            package_name.xalign = 0;
            package_name.get_style_context ().add_class ("h1");
            package_name.valign = Gtk.Align.CENTER;

            app_version = new Gtk.Label (null);
            app_version.margin_top = 12;
            app_version.xalign = 0;
            app_version.hexpand = true;
            app_version.valign = Gtk.Align.CENTER;
            app_version.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            app_version.get_style_context ().add_class ("h3");

            package_author = new Gtk.Label (null);
            package_author.xalign = 0;
            package_author.valign = Gtk.Align.START;
            package_author.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            package_author.get_style_context ().add_class ("h2");

            package_summary = new Gtk.Label (package.get_summary ());
            package_summary.xalign = 0;
            package_summary.get_style_context ().add_class ("h2");
            package_summary.wrap = true;
            package_summary.wrap_mode = Pango.WrapMode.WORD_CHAR;

            app_description = new Gtk.TextView ();
            app_description.expand = true;
            app_description.editable = false;
            app_description.get_style_context ().add_class ("h3");
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

            var content_grid = new Gtk.Grid ();
            content_grid.width_request = 800;
            content_grid.halign = Gtk.Align.CENTER;
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
            whats_new_label.get_style_context ().add_class ("h2");
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
                extension_label.get_style_context ().add_class ("h2");
                extension_label.halign = Gtk.Align.START;

                content_grid.add (extension_label);
                content_grid.add (extension_box);
                load_extensions.begin ();
            }

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            header_box.get_style_context ().add_class ("banner");
            header_box.hexpand = true;

            var header_grid = new Gtk.Grid ();
            header_grid.column_spacing = 12;
            header_grid.halign = Gtk.Align.CENTER;
            header_grid.margin = 12;
            header_grid.width_request = 800;
            header_grid.attach (image, 0, 0, 1, 2);
            header_grid.attach (package_name, 1, 0, 1, 1);
            if (!package.is_os_updates) {
                header_grid.attach (package_author, 1, 1, 3, 1);
                header_grid.attach (app_version, 2, 0, 1, 1);
            } else {
                package_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                package_summary.valign = Gtk.Align.START;
                header_grid.attach (package_summary, 1, 1, 3, 1);
            }

            if (!package.is_local) {
                var download_button_grid = new Gtk.Grid ();
                download_button_grid.orientation = Gtk.Orientation.VERTICAL;
                download_button_grid.valign = Gtk.Align.END;
                download_button_grid.halign = Gtk.Align.END;
                download_button_grid.row_spacing = 3;

                app_download_size_cancellable = new Cancellable ();

                app_download_size_label = new Gtk.Label (null);
                app_download_size_label.visible = false;
                app_download_size_label.halign = Gtk.Align.END;

                download_button_grid.add (action_stack);
                download_button_grid.add (app_download_size_label);
                header_grid.attach (download_button_grid, 3, 0, 1, 1);
            }

            header_box.add (header_grid);

            var footer_grid = new Gtk.Grid ();
            footer_grid.halign = Gtk.Align.CENTER;
            footer_grid.margin = 12;
            footer_grid.width_request = 800;

            var project_license = package.component.project_license;
            if (project_license != null) {
                string license_url = "https://choosealicense.com/licenses/";
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
                var license_button = new UrlButton (_(project_license), license_url, "text-x-copying-symbolic");
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
                other_apps_header.get_style_context ().add_class ("h4");

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

            open_button.get_style_context ().add_class ("h3");

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

            reload_css ();
            set_up_package (128);
            parse_description (package.get_description ());

            if (package.is_os_updates) {
                package.notify["state"].connect (() => {
                    Idle.add (() => {
                        parse_description (package.get_description ());
                        return false;
                    });
                });
            }
        }

        protected override void update_state (bool first_update = false) {
            if (!first_update) {
                app_version.label = package.get_version ();
            }

            app_download_size_label.visible = package.state == AppCenterCore.Package.State.NOT_INSTALLED;
            app_download_size_label.label = "";
            if (package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                get_app_download_size.begin ();
            }

            update_action ();
        }

        private async void load_extensions () {
            package.component.get_addons ().@foreach ((extension) => {
                var row = new Widgets.PackageRow.list (new AppCenterCore.Package (extension), null, null, false);
                if (extension_box != null) {
                    extension_box.add (row);
                }
            });
        }

        private async void get_app_download_size () {
            if (package.state == AppCenterCore.Package.State.INSTALLED) {
                return;
            }

            var client = AppCenterCore.Client.get_default ();
            var deps = yield client.get_needed_deps_for_package (package, app_download_size_cancellable);
            string[] package_ids = {};

            foreach (var package in deps) {
                package_ids += package.package_id;
            }

            package_ids += null;
            uint64 size = 0;

            if (package_ids.length > 1) {
                var pk_client = AppCenterCore.Client.get_pk_client ();
                try {
                    var details = yield pk_client.get_details_async (package_ids, app_download_size_cancellable, (p, t) => {});
                    details.get_details_array ().foreach ((details) => {
                        size += details.size;
                    });
                } catch (Error e) {
                    warning ("Error fetching details for dependencies, download size may be inaccurate: %s", e.message);
                }
            }

            var pk_package = package.find_package ();
            if (pk_package != null) {
                size += pk_package.size;
            }

            app_download_size_label.label = GLib.format_size (size);
            app_download_size_label.visible = true;
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

        public void load_more_content () {
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

                foreach (var url in urls) {
                    load_screenshot (url);
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
        private void load_screenshot (string url) {
            var ret = GLib.DirUtils.create_with_parents (GLib.Environment.get_tmp_dir () + Path.DIR_SEPARATOR_S + ".appcenter", 0755);
            if (ret == -1) {
                critical ("Error creating the temporary folder: GFileError #%d", GLib.FileUtils.error_from_errno (GLib.errno));
            }

            string path = Path.build_path (Path.DIR_SEPARATOR_S, GLib.Environment.get_tmp_dir (), ".appcenter", "XXXXXX");
            File fileimage;
            var fd = GLib.FileUtils.mkstemp (path);
            if (fd != -1) {
                var source = File.new_for_uri (url);
                fileimage = File.new_for_path (path);
                try {
                    source.copy (fileimage, GLib.FileCopyFlags.OVERWRITE);
                } catch (Error e) {
                    debug (e.message);
                    return;
                }

                GLib.FileUtils.close (fd);
            } else {
                critical ("Error create the temporary file: GFileError #%d", GLib.FileUtils.error_from_errno (GLib.errno));
                fileimage = File.new_for_uri (url);
                if (fileimage.query_exists () == false) {
                    return;
                }
            }

            Idle.add (() => {
                try {
                    var image = new Gtk.Image ();
                    image.width_request = 800;
                    image.height_request = 500;
                    image.icon_name = "image-x-generic";
                    image.halign = Gtk.Align.CENTER;
                    image.pixbuf = new Gdk.Pixbuf.from_file_at_scale (fileimage.get_path (), 800, 600, true);
                    image.show ();

                    app_screenshots.add (image);
                } catch (Error e) {
                    critical (e.message);
                }

                return GLib.Source.REMOVE;
            });
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

        class UrlButton : Gtk.Button {
            public UrlButton (string label, string uri, string icon_name) {
                get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
                tooltip_text = uri;

                var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.SMALL_TOOLBAR);
                icon.valign = Gtk.Align.CENTER;

                var title = new Gtk.Label (label);

                var grid = new Gtk.Grid ();
                grid.column_spacing = 6;
                grid.add (icon);
                grid.add (title);

                add (grid);

                clicked.connect (() => {
                    try {
                        AppInfo.launch_default_for_uri (uri, null);
                    } catch (Error e) {
                        warning ("%s\n", e.message);
                    }
                });
            }
        }
    }
}
