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

        var author_packages = AppCenterCore.FlatpakBackend.get_default ().get_packages_by_author (package.author, AUTHOR_OTHER_APPS_MAX);
        if (author_packages.size <= 1) {
            return;
        }

        var header = new Granite.HeaderLabel (_("Other Apps by %s").printf (package.author_title));

        var packages = new ListStore (typeof (AppCenterCore.Package));

        var package_grid_view = new Widgets.PackageGridView (packages);

        foreach (var author_package in author_packages) {
            if (author_package.component.get_id () == package.component.get_id ()) {
                continue;
            }

            packages.append (author_package);
        }

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        box.append (header);
        box.append (package_grid_view);

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

        package_grid_view.package_activated.connect ((pkg) => show_other_package (pkg));
    }
}
