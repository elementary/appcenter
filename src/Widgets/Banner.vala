/*
 * Copyright 2016–2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Nathan Dyer <mail@nathandyer.me>
 */

const int MILLISECONDS_BETWEEN_BANNER_ITEMS = 5000;

public class AppCenter.Widgets.Banner : Gtk.Button {
    public Icon icon { get; construct; }
    public string brand_color { get; construct; }
    public string description { get; construct; }
    public string app_name { get; construct; }
    public string summary { get; construct; }

    public Banner (string name, string summary, string description, Icon icon, string brand_color) {
        Object (
            brand_color: brand_color,
            description: description,
            icon: icon,
            app_name: name,
            summary: summary
        );
    }

    public Banner.from_package (AppCenterCore.Package package) {
        // Can't get widget scale factor before it's realized
        var scale_factor = ((Gtk.Application) Application.get_default ()).active_window.get_scale_factor ();

        Object (
            app_name: package.get_name (),
            summary: package.get_summary (),
            description: package.get_description (),
            icon: package.get_icon (128, scale_factor),
            brand_color: package.get_color_primary ()
        );
    }

    construct {
        var name_label = new Gtk.Label (app_name) {
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        name_label.add_css_class ("name");

        var summary_label = new Gtk.Label (summary) {
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        summary_label.add_css_class ("summary");

        if (description != null && description != "") {
            // We only want the first line/paragraph
            description = description.split ("\n")[0];
        }

        var description_label = new Gtk.Label (description) {
            ellipsize = Pango.EllipsizeMode.END,
            lines = 2,
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        description_label.add_css_class ("description");

        var app_icon = new AppIcon (128) {
            icon = icon
        };

        var inner_box = new Gtk.Box (VERTICAL, 0) {
            valign = CENTER
        };
        inner_box.append (name_label);
        inner_box.append (summary_label);
        inner_box.append (description_label);

        var outer_box = new Gtk.Box (HORIZONTAL, 0) {
            halign = CENTER
        };
        outer_box.append (app_icon);
        outer_box.append (inner_box);

        add_css_class ("banner");
        add_css_class (Granite.STYLE_CLASS_CARD);
        add_css_class (Granite.STYLE_CLASS_ROUNDED);

        hexpand = true;
        child = outer_box;

        if (brand_color != null) {
            set_accent_color (brand_color, this);
        }
    }

    private static Gee.HashMap<string, Gtk.CssProvider>? providers;
    public static void set_accent_color (string color, Gtk.Widget widget) {
        if (providers == null) {
            providers = new Gee.HashMap<string, Gtk.CssProvider> ();
        }

        var color_class = color.replace ("#", "color-");
        widget.add_css_class (color_class);

        if (!providers.has_key (color)) {
            var bg_rgba = Gdk.RGBA ();
            bg_rgba.parse (color);

            var text_color = Granite.contrasting_foreground_color (bg_rgba).to_string ();

            string style = @"
                .banner.$color_class {
                    background-color: $color;
                    background-image:
                        linear-gradient(
                            to bottom right,
                            shade($color, 1.05),
                            shade($color, 0.95)
                        );
                    color: $text_color;

                    border: 1px solid shade($color, 0.8);
                    box-shadow:
                        inset 0 0 0 1px alpha(shade($color, 1.7), 0.05),
                        inset 0 1px 0 0 alpha(shade($color, 1.7), 0.45),
                        inset 0 -1px 0 0 alpha(shade($color, 1.7), 0.15),
                        0 3px 2px -1px alpha(shade($color, 0.5), 0.2),
                        0 3px 5px alpha(shade($color, 0.5), 0.15);
                }

                .banner.$color_class:hover {
                    box-shadow:
                        inset 0 0 0 1px alpha(shade($color, 1.7), 0.05),
                        inset 0 1px 0 0 alpha(shade($color, 1.7), 0.45),
                        inset 0 -1px 0 0 alpha(shade($color, 1.7), 0.15),
                        0 10px 8px -11px alpha(shade($color, 0.6), 0.8),
                        0 8px 12px alpha(shade($color, 0.8), 0.6);
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
