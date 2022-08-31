/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
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

public abstract class AppCenter.AbstractAppList : Gtk.Box {
    public signal void show_app (AppCenterCore.Package package);

    protected Gtk.ScrolledWindow scrolled;
    protected Gtk.ListBox list_box;
    protected uint packages_changing = 0;

    construct {
        orientation = Gtk.Orientation.VERTICAL;

        list_box = new Gtk.ListBox () {
            activate_on_single_click = true,
            hexpand = true,
            vexpand = true
        };
        list_box.set_sort_func ((Gtk.ListBoxSortFunc) package_row_compare);

        scrolled = new Gtk.ScrolledWindow () {
            child = list_box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        list_box.row_activated.connect ((r) => {
            var row = (Widgets.PackageRow)r;
            show_app (row.get_package ());
        });

        // list_box.add.connect ((row) => {
        //     ((Widgets.PackageRow) row).get_package ().changing.connect (on_package_changing);
        // });
    }

    public abstract void add_packages (Gee.Collection<AppCenterCore.Package> packages);
    public abstract void add_package (AppCenterCore.Package package);

    public void remove_package (AppCenterCore.Package package) {
        package.changing.disconnect (on_package_changing);

        unowned var row = list_box.get_first_child ();
        while (row != null) {
            if (row is Widgets.PackageRow && ((Widgets.PackageRow) row).get_package () == package) {
                row.destroy ();
                break;
            }

            row = row.get_next_sibling ();
        }

        list_box.invalidate_sort ();
    }

    public virtual void clear () {
        unowned var row = list_box.get_first_child ();
        while (row != null) {
            if (row is Widgets.PackageRow) {
                var package = ((Widgets.PackageRow) row).get_package ();
                package.changing.disconnect (on_package_changing);
                row.destroy ();
            }

            row = row.get_next_sibling ();
        }

        list_box.invalidate_sort ();
    }

    protected virtual Gee.Collection<AppCenterCore.Package> get_packages () {
        var tree_set = new Gee.TreeSet<AppCenterCore.Package> ();

        unowned var row = list_box.get_first_child ();
        while (row != null) {
            if (row is Widgets.PackageRow) {
                tree_set.add (((Widgets.PackageRow) row).get_package ());
            }

            row = row.get_next_sibling ();
        }

        return tree_set;
    }

    [CCode (instance_pos = -1)]
    protected virtual int package_row_compare (Widgets.PackageRow row1, Widgets.PackageRow row2) {
        return row1.get_package ().get_name ().collate (row2.get_package ().get_name ());
    }

    protected virtual void on_package_changing (AppCenterCore.Package package, bool is_changing) {
        if (is_changing) {
            packages_changing++;
        } else {
            packages_changing--;
        }

        assert (packages_changing >= 0);
        if (packages_changing == 0) {
            list_box.invalidate_sort ();
        }
    }
}
