/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.Screenshot : Granite.Bin {
    public string caption { get; set; }

    public string path {
        set {
            picture.file = File.new_for_path (value);
        }
    }

    private static Gee.HashMap<string, Gtk.CssProvider>? providers;
    private Gtk.Picture picture;

    class construct {
        set_css_name ("screenshot");
    }

    construct {
        picture = new Gtk.Picture () {
            content_fit = SCALE_DOWN,
            vexpand = true
        };

        var label = new Gtk.Label ("") {
            max_width_chars = 50,
            wrap = true
        };

        var box = new Gtk.Box (VERTICAL, 0) {
            halign = CENTER
        };
        box.append (label);
        box.append (picture);

        child = box;
        add_css_class (Granite.CssClass.CARD);

        bind_property ("caption", label, "label");
    }

    public void set_branding (AppCenterCore.Package package) {
        set_accent_color (package.get_color_primary ());

        Granite.Settings.get_default ().notify["prefers-color-scheme"].connect (() => {
            set_accent_color (package.get_color_primary ());
        });
    }

    private void set_accent_color (string color) {
        if (providers == null) {
            providers = new Gee.HashMap<string, Gtk.CssProvider> ();
        }

        var color_class = color.replace ("#", "color-");
        css_classes = {Granite.CssClass.CARD, color_class};

        if (!providers.has_key (color)) {
            var bg_rgba = Gdk.RGBA ();
            bg_rgba.parse (color);

            var text_color = Granite.contrasting_foreground_color (bg_rgba).to_string ();

            string style = @"
                screenshot.$color_class {
                    background-color: $color;
                    color: mix($color, $text_color, 0.9);
                }
            ";

            var style_provider = new Gtk.CssProvider ();
            style_provider.load_from_string (style);

            providers[color] = style_provider;
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                providers[color],
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }
    }
}
