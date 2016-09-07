// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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

//~ using AppCenterCore;
namespace AppCenter.Views {
    public class AppInfoView : AppCenter.AbstractAppContainer {
        Gtk.Image app_screenshot;
        Gtk.Stack screenshot_stack;
        Gtk.Label app_screenshot_not_found;
        Gtk.Label app_version;
        Gtk.TextView app_description;
        Gtk.ListBox extension_box;
        Gtk.Label extension_label;
        Gtk.Grid content_grid;

        construct {
            image.margin_top = 12;
            image.margin_start = 6;
            image.pixel_size = 128;

            app_screenshot = new Gtk.Image ();
            app_screenshot.width_request = 800;
            app_screenshot.height_request = 600;
            app_screenshot.icon_name = "image-x-generic";
            app_screenshot.halign = Gtk.Align.CENTER;

            var app_screenshot_spinner = new Gtk.Spinner ();
            app_screenshot_spinner.halign = Gtk.Align.CENTER;
            app_screenshot_spinner.valign = Gtk.Align.CENTER;
            app_screenshot_spinner.active = true;

            app_screenshot_not_found = new Gtk.Label (_("Screenshot Not Available"));
            app_screenshot_not_found.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);
            app_screenshot_not_found.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            app_screenshot_not_found.get_style_context ().add_class ("h2");

            screenshot_stack = new Gtk.Stack ();
            screenshot_stack.margin_bottom = 24;
            screenshot_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            screenshot_stack.add (app_screenshot_spinner);
            screenshot_stack.add (app_screenshot);
            screenshot_stack.add (app_screenshot_not_found);

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

            package_summary = new Gtk.Label (null);
            package_summary.xalign = 0;
            package_summary.valign = Gtk.Align.START;
            package_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            package_summary.get_style_context ().add_class ("h2");
            package_summary.wrap = true;
            package_summary.set_lines (3);
            package_summary.wrap_mode = Pango.WrapMode.WORD_CHAR;

            app_description = new Gtk.TextView ();
            app_description.expand = true;
            app_description.editable = false;
            app_description.get_style_context ().add_class ("h3");
            app_description.cursor_visible = false;
            app_description.pixels_below_lines = 3;
            app_description.pixels_inside_wrap = 3;
            app_description.wrap_mode = Gtk.WrapMode.WORD_CHAR;

            content_grid = new Gtk.Grid ();
            content_grid.width_request = 800;
            content_grid.halign = Gtk.Align.CENTER;
            content_grid.orientation = Gtk.Orientation.VERTICAL;
            content_grid.add (screenshot_stack);
            content_grid.add (app_description);

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled.expand = true;
            scrolled.add (content_grid);

            var header_grid = new Gtk.Grid ();
            header_grid.column_spacing = 12;
            header_grid.margin = 12;
            header_grid.attach (image, 0, 0, 1, 2);
            header_grid.attach (package_name, 1, 0, 1, 1);
            header_grid.attach (app_version, 2, 0, 1, 1);
            header_grid.attach (action_stack, 3, 0, 1, 1);
            header_grid.attach (package_summary, 1, 1, 3, 1);

            attach (header_grid, 0, 0, 1, 1);
            attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 1, 1);
            attach (scrolled, 0, 2, 1, 1);
        }

        public AppInfoView (AppCenterCore.Package package) {
            this.package = package;
            set_up_package (128);

            parse_description (package.component.get_description ());

            if (package.component.get_extensions ().length > 0) {
                extension_box = new Gtk.ListBox ();
                extension_box.selection_mode = Gtk.SelectionMode.NONE;

                extension_label = new Gtk.Label ("<b>" + _("Extensions:") + "</b>");
                extension_label.margin_top = 12;
                extension_label.use_markup = true;
                extension_label.get_style_context ().add_class ("h3");
                extension_label.halign = Gtk.Align.START;

                content_grid.add (extension_label);
                content_grid.add (extension_box);
                load_extensions.begin ();
            }

            action_button.set_suggested_action_header ();
            uninstall_button.set_destructive_action_header ();
        }

        private async void load_extensions () {
            package.component.get_extensions ().@foreach ((cid) => {
                try {
                    var extension = AppCenterCore.Client.get_default ().get_extension (cid);
                    if (extension != null) {
                        var row = new Widgets.PackageRow (new AppCenterCore.Package (extension), null, false);
                        if (extension_box != null) {
                            extension_box.add (row);
                        }
                    }
                } catch (Error e) {
                    warning ("%s\n", e.message);
                }
            });
        }

        public void load_more_content () {
            new Thread<void*> ("content-loading", () => {
                app_version.label = package.get_version ();

                string url = null;
                uint max_size = 0U;
                var screenshots = package.component.get_screenshots ();
                if (screenshots.length == 0) {
                    screenshot_stack.visible_child = app_screenshot_not_found;
                    return null;
                }

                screenshots.foreach ((screenshot) => {
                    screenshot.get_images ().foreach ((image) => {
                        if (max_size < image.get_width ()) {
                            url = image.get_url ();
                            max_size = image.get_width ();
                        }
                    });
                });

                if (url != null) {
                    set_screenshot (url);
                }

                return null;
            });
        }

        // We need to first download the screenshot locally so that it doesn't freeze the interface.
        private void set_screenshot (string url) {
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
                    // The file is likely to not being found.
                    screenshot_stack.visible_child = app_screenshot_not_found;
                    return;
                }

                GLib.FileUtils.close (fd);
            } else {
                critical ("Error create the temporary file: GFileError #%d", GLib.FileUtils.error_from_errno (GLib.errno));
                fileimage = File.new_for_uri (url);
                if (fileimage.query_exists () == false) {
                    screenshot_stack.visible_child = app_screenshot_not_found;
                    return;
                }
            }

            Idle.add (() => {
                try {
                    app_screenshot.pixbuf = new Gdk.Pixbuf.from_file_at_scale (fileimage.get_path (), 800, 600, true);
                    screenshot_stack.visible_child = app_screenshot;
                } catch (Error e) {
                    critical (e.message);
                }

                return GLib.Source.REMOVE;
            });
        }

        private void parse_description (string? description) {
            if (description != null) {
                app_description.buffer.text = AppStream.description_markup_convert_simple (description);
            }
        }
    }
}
