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
    .banner {
        background-color: %s;
        color: %s;
    }

    .banner.home {
        border-radius: 3px;
        box-shadow:
            0 3px 2px -1px alpha (#000, 0.15),
            0 3px 5px alpha (#000, 0.10);
    }

    .banner .button {
        background-color: @base_color;
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

        private Gtk.Box content_box;
        private Gtk.Label name_label;
        private Gtk.Label summary_label;
        private Gtk.Label description_label;
        private Gtk.Image icon;

        public AppCenterCore.Package? current_package;

        public Banner () {
            foreground_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;
            background_color = DEFAULT_BANNER_COLOR_PRIMARY;
            reload_css ();
            this.height_request = 300;

            // Default AppCenter banner
            name_label = new Gtk.Label ("Name");
            name_label.get_style_context ().add_class ("h1");
            name_label.xalign = 0;
            name_label.wrap = true;
            name_label.max_width_chars = 40;

            summary_label = new Gtk.Label ("Summary");
            summary_label.get_style_context ().add_class ("h2");
            summary_label.xalign = 0;
            summary_label.wrap = true;
            summary_label.max_width_chars = 50;

            description_label = new Gtk.Label ("Description");
            description_label.get_style_context ().add_class ("h3");
            description_label.xalign = 0;
            description_label.margin_top = 25;
            description_label.wrap = true;
            description_label.max_width_chars = 50;

            icon = new Gtk.Image ();
            icon.icon_name = "system-software-install";
            icon.pixel_size = 128;
            icon.xalign = 1;
            icon.margin_right = 24;
            content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            var vertical_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            vertical_box.pack_start (name_label, false, false, 0);
            vertical_box.pack_start (summary_label, false, false, 0);
            vertical_box.pack_start (description_label, false, false, 0);
            vertical_box.valign = Gtk.Align.CENTER;

            content_box.pack_start (icon, true, true, 0);
            content_box.pack_start (vertical_box, true, true, 0);
            content_box.expand = true;
            content_box.valign = Gtk.Align.CENTER;

            var main_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main_container.add (content_box);

            this.add (main_container);

            set_brand ();
        }

        public void set_brand () {
            name_label.label = "AppCenter";
            summary_label.label = "An open, pay-what-you-want app store";
            description_label.label = "Try first, then pay what you want. Get the apps that you need, for a price you can afford.";

            background_color = DEFAULT_BANNER_COLOR_PRIMARY;
            foreground_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;

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
