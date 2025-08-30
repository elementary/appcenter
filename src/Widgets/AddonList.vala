/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.AddonList : Granite.Bin {
    public signal void show_addon (AppCenterCore.Package package);

    public AppCenterCore.Package package { get; construct; }

    public AddonList (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        var header_label = new Granite.HeaderLabel (_("Add-Ons")) {
            margin_start = 12
        };
        var addon_list = AppCenterCore.FlatpakBackend.get_default ().get_addons (package);

        var selection_model = new Gtk.NoSelection (addon_list);

        var factory = new Gtk.SignalListItemFactory ();
        factory.bind.connect (on_bind);

        var list_view = new Gtk.GridView (selection_model, factory) {
            single_click_activate = true,
            vexpand = true
        };
        list_view.activate.connect (on_activate);

        var scrolled = new Gtk.ScrolledWindow () {
            child = list_view,
            hscrollbar_policy = NEVER,
            propagate_natural_height = true,
            has_frame = true,
            min_content_height = 64,
            max_content_height = 500
        };

        var content_box = new Gtk.Box (VERTICAL, 6);
        content_box.append (header_label);
        content_box.append (scrolled);

        child = content_box;

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

    private void on_activate (Gtk.GridView view, uint pos) {
        var addon = (AppCenterCore.Package) view.model.get_item (pos);
        show_addon (addon);
    }
}
