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
        default_height = 500;
        default_width = 400;
        deletable = true;
        modal = true;
        title = _("What's new in %s").printf (package.name);

        var releases_title = new Gtk.Label (title) {
            width_chars = 20,
            wrap = true
        };
        releases_title.add_css_class ("primary");

        var headerbar = new Gtk.HeaderBar () {
            title_widget = releases_title
        };

        var releases_list = new Gtk.ListBox () {
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        releases_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);
        releases_list.add_css_class (Granite.STYLE_CLASS_BACKGROUND);

        var release_scrolled_window = new Gtk.ScrolledWindow () {
            child = releases_list,
            propagate_natural_height = true,
            propagate_natural_width = true,
        };

        var toolbarview = new Adw.ToolbarView () {
            content = release_scrolled_window
        };
        toolbarview.add_top_bar (headerbar);

        child = toolbarview;

        var releases = package.component.get_releases_plain ().get_entries ();

        foreach (unowned var release in releases) {
            if (release.get_version () == null) {
                releases.remove (release);
            }
        }

        if (releases.length > 0) {
            releases.sort_with_data ((a, b) => {
                return b.vercmp (a);
            });

            foreach (unowned var release in releases) {
                var release_row = new Widgets.ReleaseRow (release) {

                };
                release_row.add_css_class (Granite.STYLE_CLASS_CARD);

                releases_list.append (release_row);

                if (package.installed && AppStream.vercmp_simple (release.get_version (), package.get_version ()) <= 0) {
                    break;
                }
            }
        }
    }
}
