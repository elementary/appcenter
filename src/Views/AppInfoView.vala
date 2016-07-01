// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
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

using AppCenterCore;

public class AppCenter.Views.AppInfoView : Gtk.Grid {
    AppCenterCore.Package package;

    Gtk.Image app_icon;
    Gtk.Image app_screenshot;
    Gtk.Stack screenshot_stack;
    Gtk.Label app_screenshot_not_found;
    Gtk.Label app_name;
    Gtk.Label app_version;
    Gtk.Label app_summary;
    Gtk.TextView app_description;
    // The action button covers Install, Update and Open at once
    Gtk.Button action_button;
    Gtk.Button uninstall_button;
    Gtk.ProgressBar progress_bar;
    Gtk.Grid content_grid;
    Gtk.ListBox extension_box;
    Gtk.Label extension_label;
    Gtk.Button cancel_button;
    Gtk.Stack action_stack;

    public AppInfoView (AppCenterCore.Package package) {
        this.package = package;
        app_name.label = package.get_name ();
        app_summary.label = package.get_summary ();
        parse_description (package.component.get_description ());
        app_icon.gicon = package.get_icon (128);

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

        if (package.update_available) {
            action_button.label = _("Update");
        } else if (package.installed) {
            action_button.no_show_all = true;
            action_button.hide ();
        } else {
            uninstall_button.no_show_all = true;
            uninstall_button.hide ();
        }

        if (package.component.id == "xxx-os-updates") {
            uninstall_button.no_show_all = true;
            uninstall_button.hide ();
        }

        package.notify["installed"].connect (() => update_buttons ());
        package.notify["update-available"].connect (() => update_buttons ());

        package.change_information.bind_property ("can-cancel", cancel_button, "sensitive", GLib.BindingFlags.SYNC_CREATE);
        package.change_information.progress_changed.connect (() => update_progress ());
        package.change_information.status_changed.connect (() => update_status ());
        update_progress ();
        update_status ();
    }

    construct {
        column_spacing = 12;

        app_icon = new Gtk.Image ();
        app_icon.margin_top = 12;
        app_icon.margin_start = 6;
        app_icon.pixel_size = 128;

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

        app_name = new Gtk.Label (null);
        app_name.margin_top = 12;
        app_name.xalign = 0;
        app_name.get_style_context ().add_class ("h1");
        app_name.valign = Gtk.Align.CENTER;

        app_version = new Gtk.Label (null);
        app_version.margin_top = 12;
        app_version.xalign = 0;
        app_version.hexpand = true;
        app_version.valign = Gtk.Align.CENTER;
        app_version.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        app_version.get_style_context ().add_class ("h3");

        app_summary = new Gtk.Label (null);
        app_summary.xalign = 0;
        app_summary.valign = Gtk.Align.START;
        app_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        app_summary.get_style_context ().add_class ("h2");
        app_summary.wrap = true;
        app_summary.wrap_mode = Pango.WrapMode.WORD_CHAR;

        app_description = new Gtk.TextView ();
        app_description.expand = true;
        app_description.editable = false;
        app_description.get_style_context ().add_class ("h3");
        app_description.cursor_visible = false;
        app_description.pixels_below_lines = 3;
        app_description.pixels_inside_wrap = 3;
        app_description.wrap_mode = Gtk.WrapMode.WORD_CHAR;

        action_stack = new Gtk.Stack ();
        action_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        action_stack.margin_end = 6;

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.show_text = true;
        progress_bar.valign = Gtk.Align.CENTER;

        cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.get_style_context ().add_class ("h3");
        cancel_button.valign = Gtk.Align.CENTER;
        cancel_button.clicked.connect (() => action_cancelled ());

        action_button = new Gtk.Button.with_label (_("Install"));
        action_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        action_button.get_style_context ().add_class ("h3");
        action_button.clicked.connect (() => action_clicked.begin ());

        uninstall_button = new Gtk.Button.with_label (_("Uninstall"));
        uninstall_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        uninstall_button.get_style_context ().add_class ("h3");
        uninstall_button.clicked.connect (() => uninstall_clicked.begin ());

        var button_grid = new Gtk.Grid ();
        button_grid.halign = Gtk.Align.END;
        button_grid.valign = Gtk.Align.CENTER;
        button_grid.column_spacing = 12;
        button_grid.orientation = Gtk.Orientation.HORIZONTAL;
        button_grid.add (uninstall_button);
        button_grid.add (action_button);

        var progress_grid = new Gtk.Grid ();
        progress_grid.valign = Gtk.Align.CENTER;
        progress_grid.column_spacing = 12;
        progress_grid.attach (progress_bar, 0, 0, 1, 1);
        progress_grid.attach (cancel_button, 1, 0, 1, 1);

        content_grid = new Gtk.Grid ();
        content_grid.width_request = 800;
        content_grid.halign = Gtk.Align.CENTER;
        content_grid.margin = 24;
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (screenshot_stack);
        content_grid.add (app_description);

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled.expand = true;
        scrolled.add (content_grid);

        action_stack.add_named (button_grid, "buttons");
        action_stack.add_named (progress_grid, "progress");

        var header_grid = new Gtk.Grid ();
        header_grid.column_spacing = 12;
        header_grid.margin = 12;
        header_grid.attach (app_icon, 0, 0, 1, 2);
        header_grid.attach (app_name, 1, 0, 1, 1);
        header_grid.attach (app_version, 2, 0, 1, 1);
        header_grid.attach (action_stack, 3, 0, 1, 1);
        header_grid.attach (app_summary, 1, 1, 3, 1);

        attach (header_grid, 0, 0, 1, 1);
        attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 1, 1);
        attach (scrolled, 0, 2, 1, 1);
    }

    private async void load_extensions () {
        package.component.get_extensions ().@foreach ((cid) => {
            try {
                var extension = Client.get_default ().get_extension (cid);
                if (extension != null) {
                    var row = new Widgets.PackageRow (new Package (extension));
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
        new Thread<void*> ("content loading", () => {
            string url = null;
            uint max_size = 0U;
            package.component.get_screenshots ().foreach ((screenshot) => {
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

            app_version.label = package.get_version ();

            return null;
        });
    }

    private void update_status () {
        progress_bar.text = package.change_information.get_status ();
        if (package.change_information.status == Pk.Status.FINISHED) {
            action_stack.set_visible_child_name ("buttons");
        } else {
            action_stack.set_visible_child_name ("progress");
        }         
    }

    private void update_progress () {
        var progress = package.change_information.get_progress ();
        if (progress < 1.0f) {
            action_stack.set_visible_child_name ("progress");
            progress_bar.fraction = progress;
        } else {
            action_stack.set_visible_child_name ("buttons");
        }
    }

    private void update_buttons () {
        if (package.installed) {
            if (package.update_available) {
                action_button.label = _("Update");
                action_button.no_show_all = false;
                action_button.show_all ();                
            } else {
                action_button.no_show_all = true;
                action_button.hide ();                   
                uninstall_button.no_show_all = false;
                uninstall_button.show_all ();                
            }
        } else {
            action_button.label = _("Install");
            action_button.no_show_all = false;
            action_button.show_all ();
        }
    }

    private void action_cancelled () {
        package.action_cancellable.cancel ();
    }

    private async void action_clicked () {
        try {
            if (package.update_available) {
                yield package.update ();
                action_button.no_show_all = true;
                action_button.hide ();
            } else {
                yield package.install ();
                action_button.no_show_all = true;
                action_button.hide ();
                if (package.component.id != "xxx-os-updates") {
                    uninstall_button.no_show_all = false;
                    uninstall_button.show_all ();
                }
                
                // Add this app to the Installed Apps View
                MainWindow.installed_view.add_app.begin (package);
            }
        } catch (Error e) {
            critical (e.message);
            action_stack.set_visible_child_name ("buttons");
        }
    }

    private async void uninstall_clicked () {
        try {
            yield package.uninstall ();
            action_button.label = _("Install");
            uninstall_button.no_show_all = true;
            uninstall_button.hide ();

            // Remove this app from the Installed Apps View
            MainWindow.installed_view.remove_app.begin (package);
        } catch (Error e) {
            critical (e.message);
            action_stack.set_visible_child_name ("buttons");
        }
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
                critical (e.message);
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
        if (description != null)
            app_description.buffer.text = AppStream.description_markup_convert_simple (description);
    }
}
