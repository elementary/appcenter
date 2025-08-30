/*
 * SPDX-FileCopyrightText: 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class AppCenter.ReleasesDialog : Granite.Dialog {
    public AppCenterCore.Package package { get; construct; }

    public ReleasesDialog (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        title = _("What's new in %s").printf (package.name);
        modal = true;

        var releases_title = new Gtk.Label (title) {
            margin_end = 12,
            margin_start = 12,
            selectable = true,
            width_chars = 20,
            wrap = true
        };
        releases_title.add_css_class ("primary");

        var release_row = new AppCenter.Widgets.ReleaseRow (package.get_newest_release ()) {
            vexpand = true
        };

        var release_scrolled_window = new Gtk.ScrolledWindow () {
            child = release_row,
            propagate_natural_height = true,
            propagate_natural_width = true,
            max_content_width = 400,
            max_content_height = 500,
        };
        release_scrolled_window.add_css_class (Granite.STYLE_CLASS_FRAME);
        release_scrolled_window.add_css_class (Granite.STYLE_CLASS_VIEW);

        var releases_dialog_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            vexpand = true
        };
        releases_dialog_box.append (releases_title);
        releases_dialog_box.append (release_scrolled_window);

        get_content_area ().append (releases_dialog_box);

        add_button (_("Close"), Gtk.ResponseType.CLOSE);

        response.connect (() => {
            close ();
        });
    }
}
