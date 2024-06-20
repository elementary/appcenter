public class AppCenterCore.SearchManager : Object {
    private ListStore packages;

    public ListModel results { get; construct; }

    public string query { get; set; }

    public SearchManager (Package[] packages) {
        this.packages.splice (0, 0, packages);
    }

    construct {
        packages = new ListStore (typeof (Package));

        var filter_model = new Gtk.FilterListModel (packages, new Gtk.CustomFilter ((obj) => {
            return ((Package) obj).matches_search (query) > 0;
        }));

        var sort_model = new Gtk.SortListModel (filter_model, new Gtk.CustomSorter ((obj1, obj2) => {
            var package1 = (Package) obj1;
            var package2 = (Package) obj2;
            return (int) (package2.cached_search_prio - package1.cached_search_prio);
        }));

        results = sort_model;
    }

    public void search (string query) {
        this.query = query;
        packages.items_changed (0, packages.n_items, packages.n_items);
    }
}
