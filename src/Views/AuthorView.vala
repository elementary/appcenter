/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

private class AppCenter.AuthorView : Gtk.Box {
    public AppCenterCore.Package package { get; construct; }
    public int max_width { get; construct; }

    private const int AUTHOR_OTHER_APPS_MAX = 10;

    public AuthorView (AppCenterCore.Package package, int max_width) {
        Object (
            package: package,
            max_width: max_width
        );
    }

    construct {
        var header = new Granite.HeaderLabel (_("Other Apps by %s").printf (package.author_title));

        var packages = AppCenterCore.ComponentStore.get_default ().get_components_for_same_author (package);
        packages.bind_property ("n-items", this, "visible", SYNC_CREATE);

        var flowbox = new Gtk.FlowBox () {
            activate_on_single_click = true,
            column_spacing = 12,
            row_spacing = 12,
            homogeneous = true
        };
        flowbox.bind_model (packages, create_widget_func);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        box.append (header);
        box.append (flowbox);

        var clamp = new Adw.Clamp () {
            child = box,
            margin_top = 24,
            margin_end = 24,
            margin_bottom = 24,
            margin_start = 24,
            maximum_size = max_width
        };

        append (clamp);
        add_css_class ("bottom-toolbar");
        add_css_class (Granite.STYLE_CLASS_FLAT);

        flowbox.child_activated.connect ((child) => {
            var package = ((AppCenter.Widgets.ListPackageRowGrid) child.get_child ()).package;
            activate_action_variant (MainWindow.ACTION_PREFIX + MainWindow.ACTION_SHOW_PACKAGE, package.uid);
        });
    }

    private static Gtk.Widget create_widget_func (GLib.Object item) {
        return new AppCenter.Widgets.ListPackageRowGrid ((AppCenterCore.Package) item);
    }
}
