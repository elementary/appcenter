/*
 * Copyright 2014-2020 elementary, Inc. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

public abstract class AppCenter.AbstractView : Gtk.Stack {
    public signal void subview_entered (string? return_name, bool allow_search, string? custom_header = null, string? custom_search_placeholder = null);
    public signal void package_selected (AppCenterCore.Package package);

    protected AppCenterCore.Package? previous_package = null;

    construct {
        transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        expand = true;

        notify["transition-running"].connect (() => {
            // Transition finished
            if (!transition_running) {
                foreach (weak Gtk.Widget child in get_children ()) {
                    if (child is Views.AppInfoView && ((Views.AppInfoView) child).to_recycle) {
                        child.destroy ();
                    }
                }
            }
        });
    }

    public virtual void show_package (AppCenterCore.Package package, bool remember_history = true) {
        previous_package = null;

        package_selected (package);

        var package_hash = package.hash;

        var pk_child = get_child_by_name (package_hash) as Views.AppInfoView;
        if (pk_child != null && pk_child.to_recycle) {
            // Don't switch to a view that needs recycling
            pk_child.destroy ();
            pk_child = null;
        }

        if (pk_child != null) {
            pk_child.view_entered ();
            set_visible_child (pk_child);
            return;
        }

        var app_info_view = new Views.AppInfoView (package);
        app_info_view.show_all ();

        add (app_info_view);
        set_visible_child (app_info_view);

        app_info_view.show_other_package.connect ((_package, remember_history, _transition_type) => {
            transition_type = _transition_type;
            show_package (_package, remember_history);
            if (remember_history) {
                previous_package = package;
                subview_entered (package.get_name (), false, "", null);
            }
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        });
    }

    public abstract void return_clicked ();
}
