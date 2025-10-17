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

    private Gtk.Label package_name;
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

        package_name = new Gtk.Label (package.name) {
            hexpand = true,
            wrap = true,
            max_width_chars = 25,
            use_markup = true,
            valign = END,
            xalign = 0
        };
        package_name.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var release_button = new Gtk.Button.from_icon_name ("view-reader-symbolic") {
            margin_start = 12,
            tooltip_text = _("Release notes"),
            halign = END,
            valign = CENTER
        };

        release_button_revealer = new Gtk.Revealer () {
            child = release_button,
            transition_type = SLIDE_RIGHT
        };

        var grid = new Gtk.Grid ();
        grid.attach (app_icon, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (release_button_revealer, 2, 0, 1, 2);
        grid.attach (action_stack, 3, 0, 1, 2);

        if (package.has_multiple_origins) {
            var origin_label = new Gtk.Label (package.origin_description) {
                valign = START,
                xalign = 0
            };
            origin_label.add_css_class (Granite.CssClass.DIM);
            origin_label.add_css_class (Granite.CssClass.SMALL);

            grid.attach (origin_label, 1, 1);
        }

        child = grid;

        release_button.clicked.connect (() => {
            var releases_dialog = new ReleasesDialog (package) {
                transient_for = ((Gtk.Application) Application.get_default ()).active_window
            };
            releases_dialog.present ();
        });

        var gesture_controller = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY
        };
        gesture_controller.released.connect (on_clicked);
        add_controller (gesture_controller);
    }

    private void on_clicked () {
        activate_action_variant (MainWindow.ACTION_PREFIX + MainWindow.ACTION_SHOW_PACKAGE, package.uid);
    }

    private void set_up_package () {
        package.notify["state"].connect (() => {
            update_state ();
        });
        update_state ();
    }

    private void update_state () {
        var newest = package.get_newest_release ();
        if (newest != null && newest.get_version () != null) {
            release_button_revealer.reveal_child = true;
            package_name.label = "%s <span alpha=\"70%\" size=\"small\">%s</span>".printf (package.name, package.get_version ());
        }

        changed ();
    }
}
