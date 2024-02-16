/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
    public double fraction { get; set; }

    // 2px spacing on each side; otherwise it looks weird with button borders
    private const string CSS = """
        .progress-button {
            background-size: calc(%i%% - 4px) calc(100%% - 4px);
        }
    """;
    private static Gtk.CssProvider style_provider;

    public ProgressButton (double fraction = 0.0) {
        Object (
            fraction: fraction
        );
    }

    static construct {
        style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("io/elementary/appcenter/ProgressButton.css");
    }

    construct {
        add_css_class ("progress-button");
        get_style_context ().add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var provider = new Gtk.CssProvider ();

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
}
