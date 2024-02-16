/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
    public AppCenterCore.Package package { get; construct; }
    public double fraction { get; set; default = 0.0; }

    // 2px spacing on each side; otherwise it looks weird with button borders
    private const string CSS = """
        .progress-button {
            background-size: calc(%i%% - 4px) calc(100%% - 4px);
        }
    """;
    private static Gtk.CssProvider style_provider;

    public ProgressButton (AppCenterCore.Package package) {
        Object (package: package);
    }

    static construct {
        style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("io/elementary/appcenter/ProgressButton.css");
    }

    construct {
        add_css_class ("progress-button");
        get_style_context ().add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var provider = new Gtk.CssProvider ();

        package.change_information.progress_changed.connect (update_progress);
        package.change_information.status_changed.connect (update_progress_status);

        update_progress_status ();
        update_progress ();

        notify["fraction"].connect (() => {
            var css = CSS.printf ((int) (fraction * 100));

            try {
                provider.load_from_data (css.data);
                get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    private void update_progress () {
        Idle.add (() => {
            fraction = package.progress;
            return GLib.Source.REMOVE;
        });
    }

    private void update_progress_status () {
        Idle.add (() => {
            tooltip_text = package.get_progress_description ();
            sensitive = package.change_information.can_cancel && !package.changes_finished;
            /* Ensure progress bar shows complete to match status (lp:1606902) */
            if (package.changes_finished) {
                fraction = 1.0f;
            }

            return GLib.Source.REMOVE;
        });
    }
}
