/*
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.SearchEngine : Object {
    public ListModel results { get; private set; }

    private ListStore packages;
    private AppStream.Pool pool;

    private string[] query;
    private AppStream.Category? category;

    public SearchEngine (Package[] packages, AppStream.Pool pool) {
        var unique_packages = new Gee.HashMap<string, Package> ();
        foreach (var package in packages) {
            var package_component_id = package.normalized_component_id;
            if (unique_packages.has_key (package_component_id)) {
                if (package.origin_score > unique_packages[package_component_id].origin_score) {
                    unique_packages[package_component_id] = package;
                }
            } else {
                unique_packages[package_component_id] = package;
            }
        }

        this.packages.splice (0, 0, unique_packages.values.to_array ());
        this.pool = pool;
    }

    construct {
        packages = new ListStore (typeof (Package));

        var filter_model = new Gtk.FilterListModel (packages, new Gtk.CustomFilter ((obj) => {
            var package = (Package) obj;

            if (category != null && !package.component.is_member_of_category (category)) {
                return false;
            }

            return ((Package) obj).matches_search (query) > 0;
        })) {
            incremental = true
        };

        var sort_model = new Gtk.SortListModel (filter_model, new Gtk.CustomSorter ((obj1, obj2) => {
            var package1 = (Package) obj1;
            var package2 = (Package) obj2;
            return (int) (package2.cached_search_score - package1.cached_search_score);
        }));

        results = sort_model;
    }

    public void search (string query, AppStream.Category? category) {
        this.query = pool.build_search_tokens (query);
        /*
        * If there are multiple tokens, add an additional joined query token.
        * This is done because users tend to search queries for apps that have
        * one name as separate with spaces. An example would be "LibreOffice",
        * usually being searched as "Libre Office". Searching this shows the app
        * as the 17th result instead of the first without a joined query. With 
        * the joined query (e.g. the search being "Libre Office LibreOffice") it
        * will show up as the first search result.
        */
        if (this.query.length > 1) {
            var joined_query = query.replace (" ", "");
            this.query += joined_query;
        }
        this.category = category;
        packages.items_changed (0, packages.n_items, packages.n_items);
    }

    /**
     * This should be called if the engine is no longer needed.
     * We need this because thanks to how vala sets delegates we get a reference cycle,
     * where the filter and sorter keep a reference on us and we on them.
     * Setting results to null will free them and they will in turn free us.
     * https://gitlab.gnome.org/GNOME/vala/-/issues/957
     */
    public void cleanup () {
        results = null;
    }
}
