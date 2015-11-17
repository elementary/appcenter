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

public class AppCenter.Views.AppListView : Gtk.ScrolledWindow {
    public signal void show_app (AppCenterCore.Package package);

    private bool updates_on_top;
    private Gtk.ListBox list_box;
    private Gtk.Grid updated_grid;
    private Gtk.Grid updates_grid;

    public AppListView (bool updates_on_top = false) {
        this.updates_on_top = updates_on_top;
        if (updates_on_top) {
            list_box.set_header_func ((row, before) => ListBoxUpdateHeaderFunc (row, before));
        }
    }

    construct {
        hscrollbar_policy = Gtk.PolicyType.NEVER;
        var alert_view = new Granite.Widgets.AlertView (_("No Apps"), _("You haven't found any app here."), "help-info");
        list_box = new Gtk.ListBox ();
        list_box.expand = true;
        list_box.set_placeholder (alert_view);
        list_box.set_sort_func ((row1, row2) => ListBoxSortFunc (row1, row2));
        var updated_label = new Gtk.Label (_("Updated packages"));
        updated_label.margin = 6;
        updated_label.hexpand = true;
        ((Gtk.Misc) updated_label).xalign = 0;
        updated_label.get_style_context ().add_class ("h4");
        updated_grid = new Gtk.Grid ();
        updated_grid.add (updated_label);
        updated_grid.show_all ();

        var updates_label = new Gtk.Label (null);
        updates_label.get_style_context ().add_class ("h4");
        updates_label.margin = 6;
        updates_grid = new Gtk.Grid ();
        updates_grid.add (updates_label);
        updates_grid.show_all ();
        add (list_box);
    }

    public void add_package (AppCenterCore.Package package) {
        var row = new Widgets.PackageRow (package);
        row.show_all ();
        list_box.add (row);
    }

    public Gee.Collection<AppCenterCore.Package> get_packages () {
        var tree_set = new Gee.TreeSet<AppCenterCore.Package> ();
        list_box.get_children ().foreach ((child) => {
            tree_set.add (((Widgets.PackageRow) child).package);
        });

        return tree_set;
    }

    private int ListBoxSortFunc (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var package_a = ((Widgets.PackageRow) row1).package;
        var package_b = ((Widgets.PackageRow) row2).package;
        if (updates_on_top) {
            if (package_a.component.id == "xxx-os-updates") {
                return -1;
            } else if (package_b.component.id == "xxx-os-updates") {
                return 1;
            }

            if (package_a.update_available && !package_b.update_available) {
                return -1;
            } else if (!package_a.update_available && package_b.update_available) {
                return 1;
            }
        }

        return package_a.get_name ().collate (package_b.get_name ());
    }

    private void ListBoxUpdateHeaderFunc (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        if (before == null) {
            row.set_header (updates_grid);
        } else if (((Widgets.PackageRow) before).package.update_available != ((Widgets.PackageRow) row).package.update_available) {
            row.set_header (updated_grid);
        } else {
            row.set_header (null);
        }
    }
}
