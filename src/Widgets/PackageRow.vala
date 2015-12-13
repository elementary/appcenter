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

public class AppCenter.Widgets.PackageRow : Gtk.ListBoxRow {
    public Package package;

    Gtk.Image image;
    Gtk.Label package_name;
    Gtk.Label package_summary;

    Gtk.Stack action_stack;
    Gtk.Button update_button;
    Gtk.Grid update_grid;
    Gtk.ProgressBar update_progressbar;
    Gtk.Label update_label;
    Gtk.Button cancel_button;

    public PackageRow (Package package) {
        this.package = package;
        package_name.label = package.get_name ();
        package_summary.label = package.get_summary ();
        package_summary.ellipsize = Pango.EllipsizeMode.END;
        package.component.get_icon_urls ().foreach ((k, v) => {
            var file = File.new_for_path (v);
            image.gicon = new FileIcon (file);
        });

        if (image.gicon == null) {
            var icon_name = package.component.get_icon (AppStream.IconKind.STOCK, -1, -1);
            if (icon_name != null) {
                image.gicon = new ThemedIcon (icon_name);
            }
        }

        if (image.gicon == null) {
            image.gicon = new ThemedIcon ("application-default-icon");
        }

        package.notify["installed"].connect (() => {
            changed ();
        });

        action_stack.no_show_all = !package.update_available;
        action_stack.show_all ();
        package.notify["update-available"].connect (() => {
            action_stack.no_show_all = !package.update_available;
            action_stack.show_all ();
            changed ();
        });

        package.notify["progress"].connect (() => update_progress ());
        package.notify["status"].connect (() => update_status ());
        update_progress ();
        update_status ();
    }

    construct {
        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = 12;
        grid.row_spacing = 6;
        grid.column_spacing = 12;

        image = new Gtk.Image ();
        image.icon_size = Gtk.IconSize.DIALOG;

        package_name = new Gtk.Label (null);
        package_name.hexpand = true;
        package_name.valign = Gtk.Align.END;
        ((Gtk.Misc) package_name).xalign = 0;

        package_summary = new Gtk.Label (null);
        package_summary.hexpand = true;
        package_summary.valign = Gtk.Align.START;
        ((Gtk.Misc) package_summary).xalign = 0;

        action_stack = new Gtk.Stack ();

        update_button = new Gtk.Button.with_label (_("Update"));
        update_button.valign = Gtk.Align.CENTER;
        update_button.margin_end = 6;
        update_button.clicked.connect (() => update_package.begin ());

        update_label = new Gtk.Label (null);
        update_progressbar = new Gtk.ProgressBar ();
        cancel_button = new Gtk.Button.from_icon_name ("process-stop-symbolic", Gtk.IconSize.MENU);
        cancel_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        cancel_button.valign = Gtk.Align.CENTER;

        update_grid = new Gtk.Grid ();
        update_grid.attach (update_label, 0, 0, 1, 1);
        update_grid.attach (update_progressbar, 0, 1, 1, 1);
        update_grid.attach (cancel_button, 1, 0, 1, 2);

        action_stack.add (update_button);
        action_stack.add (update_grid);

        grid.attach (image, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0, 1, 1);
        grid.attach (package_summary, 1, 1, 1, 1);
        grid.attach (action_stack, 2, 0, 1, 2);
        add (grid);
    }

    private async void update_package () {
        try {
            yield package.update ();
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void update_status () {
        update_label.label = package.change_information.get_status ();
    }

    private void update_progress () {
        var progress = package.change_information.get_progress ();
        if (progress < 1.0f) {
            action_stack.set_visible_child (update_grid);
            update_progressbar.fraction = progress;
        } else {
            action_stack.set_visible_child (update_button);
            update_button.hide ();
        }
    }
}
