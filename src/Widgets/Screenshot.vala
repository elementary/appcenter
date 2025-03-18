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

        bind_property ("caption", label, "label");
    }

    public void set_accent_color (string color) {
        if (providers == null) {
            providers = new Gee.HashMap<string, Gtk.CssProvider> ();
        }

        var color_class = color.replace ("#", "color-");
        add_css_class (color_class);

        if (!providers.has_key (color)) {
            var bg_rgba = Gdk.RGBA ();
            bg_rgba.parse (color);

            var text_color = Granite.contrasting_foreground_color (bg_rgba).to_string ();

            string style = @"
                screenshot.$color_class {
                    background-color: $color;
                    color: $text_color;
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
