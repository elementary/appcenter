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
    Gtk.Button update_button;
    Gtk.Label package_name;
    Gtk.Label package_summary;

    public PackageRow (Package package) {
        this.package = package;
        package_name.label = package.get_name ();
        package_summary.label = package.get_summary ();
        package.component.get_icon_urls ().foreach ((k, v) => {
            var file = File.new_for_path (v);
            image.gicon = new FileIcon (file);
        });

        if (image.gicon == null) {
            try {
                image.gicon = new ThemedIcon ("application-default-icon");
            } catch (Error e) {
                critical (e.message);
            }
        }

        package.notify["installed"].connect (() => {
            changed ();
        });

        update_button.no_show_all = !package.update_available;
        update_button.visible = package.update_available;
        package.notify["update-available"].connect (() => {
            update_button.no_show_all = !package.update_available;
            update_button.visible = package.update_available;
            changed ();
        });
    }

    construct {
        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = 12;
        grid.row_spacing = 6;
        grid.column_spacing = 12;
        image = new Gtk.Image ();
        image.icon_size = Gtk.IconSize.DIALOG;
        update_button = new Gtk.Button.with_label (_("Update"));
        update_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        update_button.valign = Gtk.Align.CENTER;
        package_name = new Gtk.Label (null);
        package_name.hexpand = true;
        package_name.valign = Gtk.Align.END;
        ((Gtk.Misc) package_name).xalign = 0;
        package_summary = new Gtk.Label (null);
        package_summary.hexpand = true;
        package_summary.valign = Gtk.Align.START;
        ((Gtk.Misc) package_summary).xalign = 0;
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0, 1, 1);
        grid.attach (package_summary, 1, 1, 1, 1);
        grid.attach (update_button, 2, 0, 1, 2);
        add (grid);
    }
}
