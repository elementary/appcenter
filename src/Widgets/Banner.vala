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

    .banner {
        transition: all %ums ease-in-out;
    }
""";

const string DEFAULT_BANNER_COLOR_PRIMARY = "mix(@accent_color, @bg_color, 0.8)";
const string DEFAULT_BANNER_COLOR_PRIMARY_TEXT = "mix(@accent_color, @text_color, 0.85)";
const int MILLISECONDS_BETWEEN_BANNER_ITEMS = 5000;

namespace AppCenter.Widgets {
    public class Banner : Gtk.Button {
        public const int TRANSITION_DURATION_MILLISECONDS = 500;

        private string _background_color = "#667885";
        public string background_color {
            get {
                return _background_color;
            } set {
                _background_color = value;
                reload_css ();
            }
        }
        private string _foreground_color = "white";
        public string foreground_color {
            get {
                return _foreground_color;
            } set {
                _foreground_color = value;
                reload_css ();
            }
        }

        private BannerWidget? brand_widget;
        private Gtk.Stack stack;
        private int current_package_index;
        private int next_free_package_index = 1;
        private uint timer_id;

        private static Gtk.CssProvider style_provider;
        private unowned Gtk.StyleContext style_context;

        // public Banner (Switcher switcher) {
        //     Object (switcher: switcher);
        // }

        static construct {
            style_provider = new Gtk.CssProvider ();
            style_provider.load_from_resource ("io/elementary/appcenter/banner.css");
        }

        construct {
            height_request = 300;

            style_context = get_style_context ();
            style_context.add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            style_context.add_class ("banner");
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class (Granite.STYLE_CLASS_ROUNDED);
            style_context.remove_class (Gtk.STYLE_CLASS_BUTTON);

            stack = new Gtk.Stack ();
            stack.valign = Gtk.Align.CENTER;
            stack.transition_duration = TRANSITION_DURATION_MILLISECONDS;
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            add (stack);

            background_color = "#7E45BE";
            foreground_color = "white";

            brand_widget = new BannerWidget (null);
            stack.add_named (brand_widget, "brand");

            destroy.connect (() => {
               if (timer_id > 0) {
                   Source.remove (timer_id);
                   timer_id = 0;
               }
            });
        }

        public AppCenterCore.Package? get_package () {
            var current = stack.visible_child as BannerWidget;
            if (current != null) {
                return current.package;
            }

            return null;
        }

        public void add_package (AppCenterCore.Package? package) {
            if (package.is_explicit) {
                debug ("%s is explicit, not adding to banner", package.component.id);
                return;
            }

            var widget = new BannerWidget (package);
            stack.add_named (widget, next_free_package_index.to_string ());
            next_free_package_index++;
            stack.set_visible_child (widget);
            // switcher.update_selected ();
            set_background (package);

            if (brand_widget != null) {
                brand_widget.destroy ();
                brand_widget = null;
            }
        }

        private void next_package () {
            if (next_free_package_index <= 1) {
                return;
            }

            if (++current_package_index >= next_free_package_index) {
                current_package_index = 1;
            }

            stack.set_visible_child_name (current_package_index.to_string ());
            set_background (((BannerWidget) stack.visible_child).package);
        }

        public void go_to_first () {
            if (next_free_package_index <= 1) {
                return;
            }

            current_package_index = 1;
            stack.set_visible_child_name (current_package_index.to_string ());
            set_background (((BannerWidget) stack.visible_child).package);

            if (timer_id > 0) {
                Source.remove (timer_id);
                timer_id = 0;
            }
            timer_id = Timeout.add (MILLISECONDS_BETWEEN_BANNER_ITEMS, () => {
                next_package ();
                return true;
            });
        }

        private void set_background (AppCenterCore.Package? package) {
            if (package == null) {
                background_color = DEFAULT_BANNER_COLOR_PRIMARY;
                foreground_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;
                return;
            }

            var color_primary = package.get_color_primary ();
            if (color_primary != null) {
                background_color = color_primary;
            } else {
                background_color = DEFAULT_BANNER_COLOR_PRIMARY;
            }

            var color_primary_text = package.get_color_primary_text ();
            if (color_primary_text != null) {
                foreground_color = color_primary_text;
            } else {
                foreground_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;
            }
        }

        private void reload_css () {
            var provider = new Gtk.CssProvider ();
            try {
                var colored_css = BANNER_STYLE_CSS.printf (background_color, foreground_color, stack.transition_duration);
                provider.load_from_data (colored_css, colored_css.length);

                style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (GLib.Error e) {
                critical (e.message);
            }
        }

        private class BannerWidget : Gtk.Grid {
            public AppCenterCore.Package? package { get; construct; }

            public BannerWidget (AppCenterCore.Package? package) {
                Object (package: package);
            }

            construct {
                var icon = new Gtk.Image () {
                    gicon = new ThemedIcon (Build.PROJECT_NAME),
                    pixel_size = 128
                };

                var name_label = new Gtk.Label (_(Build.APP_NAME)) {
                    max_width_chars = 50,
                    use_markup = true,
                    wrap = true,
                    xalign = 0
                };
                name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

                var summary_label = new Gtk.Label (_("The open source, pay-what-you-can app store")) {
                    max_width_chars = 50,
                    use_markup = true,
                    wrap = true,
                    xalign = 0
                };
                summary_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

                var description_label = new Gtk.Label (_("Reviewed and curated for a native, privacy-respecting, and secure experience.")) {
                    ellipsize = Pango.EllipsizeMode.END,
                    lines = 2,
                    margin_top = 12,
                    max_width_chars = 50,
                    use_markup = true,
                    wrap = true,
                    xalign = 0
                };

                if (package != null) {
                    name_label.label = package.get_name ();

                    summary_label.label = package.get_summary ();

                    string[] lines = package.get_description ().split ("\n");
                    var description = lines[0].strip ();

                    for (int i = 1; i < lines.length; i++) {
                        description += " " + lines[i].strip ();
                    }

                    int close_paragraph_index = description.index_of ("</p>", 0);
                    description_label.label = description.slice (3, close_paragraph_index);

                    icon.gicon = package.get_icon (128, icon.get_scale_factor ());
                }

                column_spacing = 24;
                halign = Gtk.Align.CENTER;
                valign = Gtk.Align.CENTER;

                attach (icon, 0, 0, 1, 3);
                attach (name_label, 1, 0);
                attach (summary_label, 1, 1);
                attach (description_label, 1, 2);

                show_all ();
            }
        }
    }
}
