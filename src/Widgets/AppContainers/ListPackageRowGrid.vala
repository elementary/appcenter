/*
 * SPDX-FileCopyrightText: 2014-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class AppCenter.Widgets.ListPackageRowGrid : Granite.Bin {
    public AppCenterCore.Package package { get; construct; }

    public ListPackageRowGrid (AppCenterCore.Package package) {
        Object (package: package);
    }

    class construct {
        set_css_name ("package-row-grid");
    }

    construct {
        var app_icon = new AppIcon (48) {
            package = package
        };

        var action_stack = new ActionStack (package) {
            show_open = false
        };

        var package_name = new Gtk.Label (package.name) {
            ellipsize = END,
            lines = 2,
            max_width_chars = 1,
            valign = Gtk.Align.END,
            wrap = true,
            xalign = 0
        };
        package_name.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var package_summary = new Gtk.Label (package.get_summary ()) {
            ellipsize = END,
            hexpand = true,
            lines = 2,
            max_width_chars = 1,
            valign = Gtk.Align.START,
            width_chars = 20,
            wrap = true,
            xalign = 0
        };
        package_summary.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        if (package.is_local) {
            action_stack.visible = false;
        }

        var grid = new Gtk.Grid () {
            column_spacing = 12
        };
        grid.attach (app_icon, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (package_summary, 1, 1);
        grid.attach (action_stack, 2, 0, 1, 2);

        child = grid;
    }
}
