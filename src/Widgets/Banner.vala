// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC. (https://elementary.io)
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

    .banner {
        background-color: @banner_bg_color;
        background-image: linear-gradient(to bottom right,
                                  shade (@banner_bg_color, 1.05),
                                  shade (@banner_bg_color, 0.95)
                                  );
        color: @banner_fg_color;
    }

    .banner.home {
        border: 1px solid shade (@banner_bg_color, 0.8);
        border-radius: 3px;
        box-shadow:
            inset 0 0 0 1px alpha (shade (@banner_bg_color, 1.7), 0.05),
            inset 0 1px 0 0 alpha (shade (@banner_bg_color, 1.7), 0.45),
            inset 0 -1px 0 0 alpha (shade (@banner_bg_color, 1.7), 0.15),
            0 3px 2px -1px alpha (shade (@banner_bg_color, 0.5), 0.2),
            0 3px 5px alpha (shade (@banner_bg_color, 0.5), 0.15);
    }

    .banner .button {
        background-color: alpha (@banner_fg_color, 0.6);
        background-image: none;
        border-color: alpha (@banner_fg_color, 0.7);
        box-shadow: none;
        font-weight: 600;
    }

    .banner .button.destructive-action,
    .banner .button.suggested-action {
        background-color: alpha (@banner_fg_color, 0.8);
        border-color: alpha (@banner_fg_color, 0.9);
    }

    .banner .button:focus {
        background-color: alpha (@banner_fg_color, 0.9);
        border-color: @banner_fg_color;
    }

    .banner .button:active,
    .banner .button:checked {
        background-color: alpha (@banner_fg_color, 0.5);
        border-color: alpha (@banner_fg_color, 0.6);
    }

    .banner .button GtkImage {
        color: @banner_bg_color;
        icon-shadow: 0 1px 1px alpha (@banner_fg_color, 0.1);
    }

    .banner .button .label {
        color: @banner_bg_color;
        text-shadow: 0 1px 1px alpha (@banner_fg_color, 0.1);
    }
""";

const string DEFAULT_BANNER_COLOR_PRIMARY = "#68758e";
const string DEFAULT_BANNER_COLOR_PRIMARY_TEXT = "white";

namespace AppCenter.Widgets {
    public class Banner : Gtk.Button {

        private string _background_color = "#68758e";
        public string background_color {
            get {
                return _background_color;
            } set {
                _background_color = value;
                on_any_color_change ();
            }
        }
        private string _foreground_color = "white";
        public string foreground_color {
            get {
                return _foreground_color;
            } set {
                _foreground_color = value;
                on_any_color_change ();
            }
        }

        private Gtk.Label name_label;
        private Gtk.Label summary_label;
        private Gtk.Label description_label;
        private Gtk.Image icon;

        public AppCenterCore.Package? current_package;

        public Banner () {
            Object (background_color: DEFAULT_BANNER_COLOR_PRIMARY,
                    foreground_color: DEFAULT_BANNER_COLOR_PRIMARY_TEXT);
        }

        construct {
            reload_css ();
            height_request = 300;

            name_label = new Gtk.Label ("");
            name_label.get_style_context ().add_class ("h1");
            name_label.xalign = 0;
            name_label.use_markup = true;
            name_label.wrap = true;
            name_label.max_width_chars = 50;

            summary_label = new Gtk.Label ("");
            summary_label.get_style_context ().add_class ("h2");
            summary_label.xalign = 0;
            summary_label.use_markup = true;
            summary_label.wrap = true;
            summary_label.max_width_chars = 50;

            description_label = new Gtk.Label ("");
            description_label.get_style_context ().add_class ("h3");
            description_label.ellipsize = Pango.EllipsizeMode.END;
            description_label.lines = 2;
            description_label.margin_top = 12;
            description_label.max_width_chars = 50;
            description_label.use_markup = true;
            description_label.wrap = true;
            description_label.xalign = 0;

            icon = new Gtk.Image ();
            icon.pixel_size = 128;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 24;
            grid.halign = Gtk.Align.CENTER;
            grid.valign = Gtk.Align.CENTER;
            grid.attach (icon, 0, 0, 1, 3);
            grid.attach (name_label, 1, 0, 1, 1);
            grid.attach (summary_label, 1, 1, 1, 1);
            grid.attach (description_label, 1, 2, 1, 1);

            add (grid);
        }

        public void set_brand () {
            name_label.label = _("AppCenter");
            summary_label.label = _("An open, pay-what-you-want app store");
            description_label.label = _("Get the apps that you need at a price you can afford.");

            background_color = "#665888";
            foreground_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;
            icon.icon_name = "system-software-install";

            current_package = null;
        }

        public void set_package (AppCenterCore.Package package) {
            name_label.label = package.get_name ();
            summary_label.label = package.get_summary ();

            string description = package.get_description ();
            int close_paragraph_index = description.index_of ("</p>", 0);
            string opening_paragraph = description.slice(3, close_paragraph_index);
            description_label.label = opening_paragraph;

            icon.gicon = package.get_icon (128);

            var color_primary = package.get_color_primary ();
            if (color_primary != null) {
                background_color = color_primary;
            }

            var color_primary_text = package.get_color_primary_text ();
            if (color_primary_text != null) {
                foreground_color = color_primary_text;
            }

            current_package = package;
        }

        private void on_any_color_change () {
            reload_css ();
        }

        private void reload_css () {
            var provider = new Gtk.CssProvider ();
            try {
                var colored_css = BANNER_STYLE_CSS.printf (background_color, foreground_color);
                provider.load_from_data (colored_css, colored_css.length);
                var context = get_style_context ();
                context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                context.add_class ("banner");
                context.remove_class ("button");
            } catch (GLib.Error e) {
                critical (e.message);
            }
        }
    }
}
