public class AppCenterCore.SearchManager : Object {
    private ListStore packages;

    public ListModel results { get; construct; }

    public string query { get; private set; }
    public AppStream.Category? category { get; private set; }

    public SearchManager (Package[] packages) {
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
            return (int) (package2.cached_search_prio - package1.cached_search_prio);
        }));

        results = sort_model;
    }

    public void search (string query, AppStream.Category? category) {
        this.query = query;
        this.category = category; // TODO
        packages.items_changed (0, packages.n_items, packages.n_items);
    }
}
