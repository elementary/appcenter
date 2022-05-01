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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

using AppCenterCore;

public class AppCenter.Views.SearchView : AbstractView {
    AppListView app_list_view;

    public bool viewing_package { get; private set; default = false; }
    public signal void home_return_clicked ();
    public signal void category_return_clicked (AppStream.Category category);
    private AppStream.Category? current_category;
    private string current_search_term;

    public SearchView () {

    }

    construct {
        app_list_view = new AppListView ();
        add (app_list_view);
        app_list_view.show_app.connect ((package) => {
            var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();
            /// TRANSLATORS: the name of the Search view
            main_window.set_return_name (C_("view", "Search"));
            viewing_package = true;
            show_package (package);
        });
    }

    public override void return_clicked () {
        if (viewing_package) {
            if (previous_package != null) {
                show_package (previous_package);
            } else {
                set_visible_child (app_list_view);
                viewing_package = false;

                var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();
                if (current_category != null) {
                    main_window.set_custom_header (current_category.name);
                    main_window.set_return_name (current_category.name);
                } else {
                    main_window.set_custom_header (null);
                    main_window.set_return_name (_("Home"));
                }

                main_window.configure_search (true);

            }
        } else if (current_category != null) {
            category_return_clicked (current_category);
        } else {
            home_return_clicked ();
        }
    }

    public void search (string search_term, AppStream.Category? category, bool mimetype = false) {
        current_search_term = search_term;
        current_category = category;

        app_list_view.clear ();
        app_list_view.current_search_term = current_search_term;
        unowned Client client = Client.get_default ();

        Gee.Collection<Package> found_apps;

        if (mimetype) {
            found_apps = client.search_applications_mime (current_search_term);
            app_list_view.add_packages (found_apps);
        } else {
            found_apps = client.search_applications (current_search_term, current_category);
            app_list_view.add_packages (found_apps);
        }

        var main_window = (AppCenter.MainWindow) ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();
        if (current_category != null) {
            main_window.set_custom_header (current_category.name);
            main_window.set_return_name (current_category.name);
        } else {
            main_window.set_custom_header (null);
            main_window.set_return_name (_("Home"));
        }

        main_window.configure_search (true);
    }

    public void reset () {
        set_visible_child (app_list_view);
        viewing_package = false;
        current_category = null;
    }
}
