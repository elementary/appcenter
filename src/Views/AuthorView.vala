/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

private class AppCenter.AuthorView : Gtk.Box {
    public signal void show_other_package (AppCenterCore.Package package);

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
        if (package.author == null) {
            return;
        }

        var author_packages = package.author_id == null ?
            AppCenterCore.FlatpakBackend.get_default ().get_packages_by_author (package.author, AUTHOR_OTHER_APPS_MAX) :
            AppCenterCore.FlatpakBackend.get_default ().get_packages_by_author_id (package.author_id, AUTHOR_OTHER_APPS_MAX);

        if (author_packages.size <= 1) {
            return;
        }

        var header = new Granite.HeaderLabel (_("Other Apps by %s").printf (package.author_title));

        var flowbox = new Gtk.FlowBox () {
            activate_on_single_click = true,
            column_spacing = 12,
            row_spacing = 12,
            homogeneous = true
        };

        foreach (var author_package in author_packages) {
            if (author_package.component.get_id () == package.component.get_id ()) {
                continue;
            }

            var other_app = new AppCenter.Widgets.ListPackageRowGrid (author_package);
            flowbox.append (other_app);
        }

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
            var package_row_grid = (AppCenter.Widgets.ListPackageRowGrid) child.get_child ();

            show_other_package (package_row_grid.package);
        });
    }
}
