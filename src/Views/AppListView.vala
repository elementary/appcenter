/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

using AppCenterCore;

public class AppCenter.Views.AppListView : Gtk.Stack {
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
        var spinner = new Gtk.Spinner ();
        spinner.start ();
        waiting_view.add (spinner);
        alert_view = new Granite.Widgets.AlertView (_("No Apps"), _("You haven't found any app here."), "help-info");
        list_store = new Gtk.ListStore (1, typeof (Pk.Package));
        tree_view = new Gtk.TreeView.with_model (list_store);
        tree_view.insert_column_with_attributes (0, null, new Widgets.AppCellRenderer (), "package", 0);
        tree_view.headers_visible = false;
        list_store.set_sort_func (0, TreeIterCompareFunc);
        list_store.set_sort_column_id (0, Gtk.SortType.ASCENDING);
        scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.add (tree_view);
        add (scrolled);
        add (waiting_view);
        add (alert_view);
        set_visible_child (waiting_view);
    }

    /*
     * Shows the no_app view if there are no apps.
     */
    public void package_addition_finished () {
        if (list_store.iter_n_children (null) <= 0) {
            set_visible_child (alert_view);
        }
    }

    public void add_package (Pk.Package package) {
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

    private static int TreeIterCompareFunc (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b) {
        Value val_a;
        Value val_b;
        model.get_value (a, 0, out val_a);
        model.get_value (b, 0, out val_b);
        return ((Pk.Package)val_a.get_object ()).get_name ().collate (((Pk.Package)val_b.get_object ()).get_name ());
    }
}
