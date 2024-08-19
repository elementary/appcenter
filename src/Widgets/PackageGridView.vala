

public class AppCenter.Widgets.PackageGridView : Gtk.Widget {
    class construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    public signal void package_activated (AppCenterCore.Package package);

    public ListModel packages { get; construct; }

    private Gtk.GridView grid_view;

    public PackageGridView (ListModel packages) {
        Object (packages: packages);
    }

    construct {
        var selection_model = new Gtk.NoSelection (packages);

        var factory = new Gtk.SignalListItemFactory ();

        factory.setup.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            item.child = new ListPackageRowGrid ();
        });

        factory.bind.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            var package = (AppCenterCore.Package) item.item;
            var grid = (ListPackageRowGrid) item.child;
            grid.bind_package (package);
        });

        grid_view = new Gtk.GridView (selection_model, factory) {
            single_click_activate = true
        };
        grid_view.remove_css_class (Granite.STYLE_CLASS_VIEW);
        grid_view.set_parent (this);

        grid_view.activate.connect ((pos) => {
            var item = (AppCenterCore.Package) packages.get_item (pos);
            package_activated (item);
        });
    }

    ~PackageGridView () {
        grid_view.unparent ();
    }
}
