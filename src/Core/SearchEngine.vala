/*
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.SearchEngine : Object {
    public ListModel packages { get; construct; }
    public AppStream.Pool pool { get; construct; }

    public ListModel results { get; private set; }

    private string[] query;
    private AppStream.Category? category;

    public SearchEngine (ListModel unique_packages, AppStream.Pool pool) {
        Object (packages: unique_packages, pool: pool);
    }

    construct {
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
        this.category = category;
        packages.items_changed (0, packages.get_n_items (), packages.get_n_items ());
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
