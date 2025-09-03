/*
 * SPDX-FileCopyrightText: 2014-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class AppCenter.Widgets.InstalledPackageRowGrid : Granite.Bin {
    public signal void changed ();

    public AppCenterCore.Package package { get; construct; }

    public bool action_sensitive {
        set {
            action_stack.action_sensitive = value;
        }
    }

    private AppStream.Release? newest = null;
    private Gtk.Label app_version;
    private Gtk.Revealer release_button_revealer;
    private ActionStack action_stack;

    public InstalledPackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? action_size_group) {
        Object (package: package);

        if (action_size_group != null) {
            action_size_group.add_widget (action_stack.action_button);
            action_size_group.add_widget (action_stack.cancel_button);
        }

        set_up_package ();
    }

    class construct {
        set_css_name ("package-row-grid");
    }

    construct {
        var app_icon = new AppIcon (48) {
            margin_end = 12,
            package = package
        };

        action_stack = new ActionStack (package) {
            hexpand = false,
            margin_start = 12,
            show_open = false,
            updates_view = true
        };

        var package_name = new Gtk.Label (package.name) {
            wrap = true,
            max_width_chars = 25,
            valign = END,
            xalign = 0
        };
        package_name.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        app_version = new Gtk.Label (null) {
            ellipsize = END,
            valign = START,
            xalign = 0
        };
        app_version.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        app_version.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var release_button = new Gtk.Button.from_icon_name ("view-reader-symbolic") {
            margin_start = 12,
            tooltip_text = _("Release notes"),
            valign = Gtk.Align.CENTER
        };

        release_button_revealer = new Gtk.Revealer () {
            child = release_button,
            halign = END,
            hexpand = true,
            transition_type = SLIDE_RIGHT
        };

        var grid = new Gtk.Grid ();
        grid.attach (app_icon, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (app_version, 1, 1);
        grid.attach (release_button_revealer, 2, 0, 1, 2);
        grid.attach (action_stack, 3, 0, 1, 2);

        child = grid;

        release_button.clicked.connect (() => {
            var releases_dialog = new ReleasesDialog (package) {
                transient_for = ((Gtk.Application) Application.get_default ()).active_window
            };
            releases_dialog.present ();
        });
    }

    private void set_up_package () {
        if (package.get_version () != null) {
            if (package.has_multiple_origins) {
                app_version.label = "%s — %s".printf (package.get_version (), package.origin_description);
            } else {
                app_version.label = package.get_version ();
            }
        }

        package.notify["state"].connect (() => {
            update_state ();
        });
        update_state (true);
    }

    private void update_state (bool first_update = false) {
        if (!first_update && package.get_version != null) {
            if (package.has_multiple_origins) {
                app_version.label = "%s - %s".printf (package.get_version (), package.origin_description);
            } else {
                app_version.label = package.get_version ();
            }
        }

        if (newest == null) {
            newest = package.get_newest_release ();
        }

        if (newest != null && newest.get_version () != null) {
            release_button_revealer.reveal_child = true;
        }

        changed ();
    }
}
