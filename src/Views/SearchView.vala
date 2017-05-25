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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

using AppCenterCore;

public class AppCenter.Views.SearchView : View {
    AppListView app_list_view;

    public bool viewing_package { get; private set; default = false; }

    public SearchView () {
        
    }

    construct {
        app_list_view = new AppListView ();
        add (app_list_view);
        app_list_view.show_app.connect ((package) => {
            /// TRANSLATORS: the name of the Search view
            subview_entered (C_("view", "Search"), false);
            viewing_package = true;
            show_package (package);
        });
    }

    public override void return_clicked () {
        viewing_package = false;
        set_visible_child (app_list_view);
    }
    
    public void search (string search_term, AppStream.Category? category) {
        app_list_view.clear ();
        unowned Client client = Client.get_default ();
        var found_apps = client.search_applications (search_term, category);
        app_list_view.add_packages (found_apps);
    }
}
