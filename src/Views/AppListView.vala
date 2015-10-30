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

public class AppCenter.Views.AppListView : Gtk.Stack {
    public signal void show_app (AppCenterCore.Package package);

    Gtk.TreeView tree_view;
    Gtk.ListStore list_store;
    Gtk.ScrolledWindow scrolled;
    Gtk.Grid waiting_view;
    Granite.Widgets.AlertView alert_view;
    public AppListView () {
        
    }

    construct {
        waiting_view = new Gtk.Grid ();
        waiting_view.halign = Gtk.Align.CENTER;
        waiting_view.valign = Gtk.Align.CENTER;
        waiting_view.expand = true;
        var spinner = new Gtk.Spinner ();
        waiting_view.add (spinner);
        alert_view = new Granite.Widgets.AlertView (_("No Apps"), _("You haven't found any app here."), "help-info");
        list_store = new Gtk.ListStore (2, typeof (AppCenterCore.Package), typeof (Gdk.Pixbuf));
        tree_view = new Gtk.TreeView.with_model (list_store);
        tree_view.insert_column_with_data_func (0, null, new Widgets.AppCellRenderer (), TreeCellDataFunc);
        tree_view.headers_visible = false;
        tree_view.activate_on_single_click = true;
        tree_view.rules_hint = true;
        list_store.set_sort_func (0, TreeIterCompareFunc);
        list_store.set_sort_column_id (0, Gtk.SortType.ASCENDING);
        scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.add (tree_view);
        add (scrolled);
        add (waiting_view);
        add (alert_view);
        set_visible_child (waiting_view);
        spinner.start ();
        
        tree_view.row_activated.connect ((path, column) => {
            Gtk.TreeIter iter;
            if (list_store.get_iter (out iter, path)) {
                Value val;
                list_store.get_value (iter, 0, out val);
                var package = (AppCenterCore.Package) val.get_object ();

                show_app (package);
            }
        });

        Client.get_default ().updates_available.connect (() => {
            list_store.set_sort_func (0, TreeIterCompareFunc);
        });
    }

    /*
     * Shows the no_app view if there are no apps.
     */
    public void package_addition_finished () {
        if (list_store.iter_n_children (null) <= 0) {
            set_visible_child (alert_view);
        }
    }

    public void add_package (AppCenterCore.Package package) {
        Gtk.TreeIter iter;
        list_store.append (out iter);
        list_store.set (iter, 0, package);
        if (list_store.iter_n_children (null) == 1) {
            set_visible_child (scrolled);
        }
    }

    /*
     * As clearing is the beggining of an action (refill),
     * the user should call package_addition_finished once finished.
     */
    public void clear () {
        set_visible_child (waiting_view);
        list_store.clear ();
    }

    private static void TreeCellDataFunc (Gtk.TreeViewColumn tree_column, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        Value val;
        tree_model.get_value (iter, 0, out val);
        var package = (AppCenterCore.Package) val.get_object ();
        ((Widgets.AppCellRenderer) cell).package = package;
        tree_model.get_value (iter, 1, out val);
        var icon = (Gdk.Pixbuf) val.get_object ();
        if (icon == null) {
            package.find_components ();
            foreach (var component in package.components) {
                component.get_icon_urls ().foreach ((k, v) => {
                    icon = new Gdk.Pixbuf.from_file_at_scale (v, 48, 48, true);
                });
            }

            if (icon == null) {
                try {
                    icon = Gtk.IconTheme.get_default ().load_icon ("application-default-icon", 48, Gtk.IconLookupFlags.GENERIC_FALLBACK);
                } catch (Error e) {
                    critical (e.message);
                }
            }

            ((Gtk.ListStore) tree_model).set (iter, 1, icon);
        }

        ((Widgets.AppCellRenderer) cell).icon = icon;
    }

    private static int TreeIterCompareFunc (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b) {
        Value val_a;
        Value val_b;
        model.get_value (a, 0, out val_a);
        model.get_value (b, 0, out val_b);
        var package_a = (Package) val_a.get_object ();
        var package_b = (Package) val_b.get_object ();
        if (package_a.update_available && !package_b.update_available) {
            return -1;
        } else if (!package_a.update_available && package_b.update_available) {
            return 1;
        }

        return package_a.pk_package.get_name ().collate (package_b.pk_package.get_name ());
    }
}
