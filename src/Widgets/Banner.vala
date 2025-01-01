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
    public Icon icon { get; construct; }
    public string brand_color { get; construct; }
    public string description { get; construct; }
    public string app_name { get; construct; }
    public string summary { get; construct; }
    public bool uses_generic_icon { get; construct set; }

    private Gtk.Spinner spinner;
    private Gtk.Image icon_image;

    public Banner (string name, string summary, string description, Icon icon, string brand_color) {
        Object (
            app_name: name,
            summary: summary,
            description: description,
            icon: icon,
            brand_color: brand_color,
            uses_generic_icon: false
        );
    }

    public Banner.from_package (AppCenterCore.Package package) {
        // Can't get widget scale factor before it's realized
        var scale_factor = 1;
        var app = ((Gtk.Application) Application.get_default ());
        if (app != null) {
            if (app.active_window != null) {
                scale_factor = app.active_window.get_scale_factor ();
            }
        }

        var pkg_icon = package.get_icon (128, scale_factor);

        Object (
            app_name: package.get_name (),
            summary: package.get_summary (),
            description: package.get_description (),
            icon: pkg_icon,
            brand_color: package.get_color_primary (),
            uses_generic_icon: package.uses_generic_icon && package.icon_available
        );
    }


    construct {
        var name_label = new Gtk.Label (app_name) {
            use_markup = true,
            xalign = 0
        };
        name_label.add_css_class ("name");

        var summary_label = new Gtk.Label (summary) {
            use_markup = true,
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
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        description_label.add_css_class ("description");

        spinner = new Gtk.Spinner () {
            margin_top = 6,
            halign = Gtk.Align.FILL,
            valign = Gtk.Align.CENTER,
            width_request = 80,
            height_request = 104,
            visible = uses_generic_icon
        };
        spinner.start ();
        spinner.add_css_class ("spinner");

        icon_image = new Gtk.Image.from_gicon (icon);
        icon_image.add_css_class ("icon_image");
        var image_overlay = new Gtk.Overlay () {
            child = icon_image,
        };
        image_overlay.add_overlay (spinner);

        var inner_box = new Gtk.Box (VERTICAL, 0) {
            valign = CENTER
        };
        inner_box.append (name_label);
        inner_box.append (summary_label);
        inner_box.append (description_label);

        var outer_box = new Gtk.Box (HORIZONTAL, 24) {
            halign = CENTER
        };
        outer_box.append (image_overlay);
        outer_box.append (inner_box);

        add_css_class ("banner");
        add_css_class (Granite.STYLE_CLASS_CARD);
        add_css_class (Granite.STYLE_CLASS_ROUNDED);

        hexpand = true;
        child = outer_box;

        var provider = new Gtk.CssProvider ();
        try {
            string bg_color = DEFAULT_BANNER_COLOR_PRIMARY;
            string text_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;

            if (brand_color != null) {
                var bg_rgba = Gdk.RGBA ();
                bg_rgba.parse (brand_color);

                bg_color = brand_color;
                text_color = Granite.contrasting_foreground_color (bg_rgba).to_string ();
            }

            var colored_css = BANNER_STYLE_CSS.printf (bg_color, text_color);
            provider.load_from_string (colored_css);
            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (GLib.Error e) {
            critical ("Unable to set accent color: %s", e.message);
        }
    }

    public void update_icon (Icon icon) {
        uses_generic_icon = false;
        spinner.visible = false;
        icon_image.clear ();
        icon_image.set_from_gicon (icon);
    }
}
