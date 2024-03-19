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

const string BANNER_STYLE_CSS = """
    @define-color banner_bg_color %s;
    @define-color banner_fg_color %s;
""";

const string DEFAULT_BANNER_COLOR_PRIMARY = "mix(@accent_color, @bg_color, 0.8)";
const string DEFAULT_BANNER_COLOR_PRIMARY_TEXT = "mix(@accent_color, @text_color, 0.85)";
const int MILLISECONDS_BETWEEN_BANNER_ITEMS = 5000;

public class AppCenter.Widgets.Banner : Gtk.Button {
    public AppCenterCore.Package package { get; construct; }

    public Banner (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        var name_label = new Gtk.Label (package.get_name ()) {
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        name_label.add_css_class (Granite.STYLE_CLASS_H1_LABEL);

        var summary_label = new Gtk.Label (package.get_summary ()) {
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        summary_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        string description = "";
        if (package.get_description () != null) {
            // We only want the first line/paragraph
            description = package.get_description ().split ("\n")[0];
        }

        var description_label = new Gtk.Label (description) {
            ellipsize = Pango.EllipsizeMode.END,
            lines = 2,
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };

        var icon_image = new Gtk.Image.from_gicon (
            package.get_icon (128, get_scale_factor ())
        ) {
            pixel_size = 128
        };

        var package_grid = new Gtk.Grid () {
            column_spacing = 24,
            halign = Gtk.Align.CENTER,
            margin_bottom = 64,
            margin_top = 64,
            valign = Gtk.Align.CENTER
        };

        package_grid.attach (icon_image, 0, 0, 1, 3);
        package_grid.attach (name_label, 1, 0);
        package_grid.attach (summary_label, 1, 1);
        package_grid.attach (description_label, 1, 2);

        add_css_class ("banner");
        add_css_class (Granite.STYLE_CLASS_CARD);
        add_css_class (Granite.STYLE_CLASS_ROUNDED);

        hexpand = true;
        child = package_grid;

        var provider = new Gtk.CssProvider ();
        try {
            string bg_color = DEFAULT_BANNER_COLOR_PRIMARY;
            string text_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;

            if (package != null) {
                var primary_color = package.get_color_primary ();

                if (primary_color != null) {
                    var bg_rgba = Gdk.RGBA ();
                    bg_rgba.parse (primary_color);

                    bg_color = primary_color;
                    text_color = Granite.contrasting_foreground_color (bg_rgba).to_string ();
                }
            }

            var colored_css = BANNER_STYLE_CSS.printf (bg_color, text_color);
            provider.load_from_data (colored_css.data);
            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (GLib.Error e) {
            critical ("Unable to set accent color: %s", e.message);
        }
    }
}
