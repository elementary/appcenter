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

public abstract class AppCenter.AbstractView : Hdy.Deck {
    public signal void package_selected (AppCenterCore.Package package);

    protected AppCenterCore.Package? previous_package = null;

    construct {
        can_swipe_back = true;
        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        expand = true;

        notify["visible-child"].connect (() => {
            if (!transition_running) {
                update_navigation ();
                abstract_update_navigation ();
            }
        });

        notify["transition-running"].connect (() => {
            if (!transition_running) {
                update_navigation ();
                abstract_update_navigation ();
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

        app_info_view.show_other_package.connect ((_package, remember_history, transition) => {
            if (!transition) {
                transition_duration = 0;
            }

            show_package (_package, remember_history);
            if (remember_history) {
                previous_package = package;

                var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();
                main_window.set_return_name (package.get_name ());
            }
            transition_duration = 200;
        });
    }

    private void abstract_update_navigation () {
        var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();

        if (visible_child is Views.AppInfoView) {
            main_window.configure_search (false);
        }

        var previous_child = get_adjacent_child (Hdy.NavigationDirection.BACK);
        if (previous_child == null) {
            main_window.set_return_name (null);
        } else if (previous_child is Views.AppInfoView) {
            main_window.set_return_name (((Views.AppInfoView) previous_child).package.get_name ());
        } else if (previous_child is CategoryView) {
            main_window.set_return_name (((CategoryView) previous_child).category.name);
        }

        while (get_adjacent_child (Hdy.NavigationDirection.FORWARD) != null) {
            get_adjacent_child (Hdy.NavigationDirection.FORWARD).destroy ();
        }
    }

    public abstract void update_navigation ();
}
