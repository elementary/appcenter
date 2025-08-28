/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.AddonList : Granite.Bin {
    public signal void show_addon (AppCenterCore.Package package);

    public AppCenterCore.Package package { get; construct; }
    public int max_width { get; construct; }

    public AddonList (AppCenterCore.Package package, int max_width) {
        Object (package: package, max_width: max_width);
    }

    construct {
        var header_label = new Granite.HeaderLabel (_("Add-Ons")) {
            margin_start = 12
        };
        var addon_list = AppCenterCore.FlatpakBackend.get_default ().get_addons (package);

        var selection_model = new Gtk.NoSelection (addon_list);

        var factory = new Gtk.SignalListItemFactory ();
        factory.bind.connect (on_bind);

        var list_view = new Gtk.ListView (selection_model, factory) {
            single_click_activate = true,
        };
        list_view.activate.connect (on_activate);

        var scrolled = new Gtk.ScrolledWindow () {
            child = list_view,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            propagate_natural_height = true,
            has_frame = true,
            min_content_height = 300,
        };

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        content_box.append (header_label);
        content_box.append (scrolled);

        var vertical_clamp = new Adw.Clamp () {
            child = content_box,
            maximum_size = 500,
            orientation = Gtk.Orientation.VERTICAL,
        };

        var horizontal_clamp = new Adw.Clamp () {
            child = vertical_clamp,
            maximum_size = max_width,
            orientation = Gtk.Orientation.HORIZONTAL,
        };

        child = horizontal_clamp;

        addon_list.bind_property ("n-items", this, "visible", SYNC_CREATE,
            (binding, from_value, ref to_value) => {
                var items = from_value.get_uint ();
                to_value.set_boolean (items > 0);
                return true;
            }
        );
    }

    private void on_bind (Object obj) {
        var list_item = (Gtk.ListItem) obj;
        var addon = (AppCenterCore.Package) list_item.item;
        list_item.child = new AppCenter.Widgets.ListPackageRowGrid (addon);
    }

    private void on_activate (Gtk.ListView view, uint pos) {
        var addon = (AppCenterCore.Package) view.model.get_item (pos);
        show_addon (addon);
    }
}
