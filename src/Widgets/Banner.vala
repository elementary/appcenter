// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016–2018 elementary, Inc. (https://elementary.io)
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

#if POP_OS
const string DEFAULT_BANNER_COLOR_PRIMARY = "#454241";
#else
const string DEFAULT_BANNER_COLOR_PRIMARY = "#68758e";
#endif
const string DEFAULT_BANNER_COLOR_PRIMARY_TEXT = "white";
const int MILLISECONDS_BETWEEN_BANNER_ITEMS = 5000;

namespace AppCenter.Widgets {
    public class Banner : Gtk.Button {
        public const int TRANSITION_DURATION_MILLISECONDS = 500;

        private class BannerWidget : Gtk.Grid {
            public AppCenterCore.Package? package { get; construct; }

            construct {
                column_spacing = 24;
                halign = Gtk.Align.CENTER;
                valign = Gtk.Align.CENTER;

                bool has_package = package != null;

                var name_label = new Gtk.Label (has_package ? package.get_name () : _(Build.APP_NAME));
                name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
                name_label.xalign = 0;
                name_label.use_markup = true;
                name_label.wrap = true;
                name_label.max_width_chars = 50;

                var summary_label = new Gtk.Label (has_package ? package.get_summary () : _("An open, pay-what-you-want app store"));
                summary_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
                summary_label.xalign = 0;
                summary_label.use_markup = true;
                summary_label.wrap = true;
                summary_label.max_width_chars = 50;

                string description;
                if (has_package) {
                    description = package.get_description ();
                    int close_paragraph_index = description.index_of ("</p>", 0);
                    description = description.slice (3, close_paragraph_index);
                } else {
                    description = _("Get the apps that you need at a price you can afford.");
                }

                var description_label = new Gtk.Label (description);
                description_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
                description_label.ellipsize = Pango.EllipsizeMode.END;
                description_label.lines = 2;
                description_label.margin_top = 12;
                description_label.max_width_chars = 50;
                description_label.use_markup = true;
                description_label.wrap = true;
                description_label.xalign = 0;

                var icon = new Gtk.Image ();
                icon.pixel_size = 128;
                if (has_package) {
                    icon.gicon = package.get_icon (128, icon.get_scale_factor ());
                } else {
                    icon.icon_name = "system-software-install";
                }

                attach (icon, 0, 0, 1, 3);
                attach (name_label, 1, 0, 1, 1);
                attach (summary_label, 1, 1, 1, 1);
                attach (description_label, 1, 2, 1, 1);
                show_all ();
            }

            public BannerWidget (AppCenterCore.Package? package) {
                Object (package: package);
            }
        }

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

        private BannerWidget? brand_widget;
        private Gtk.Stack stack;
        private Switcher switcher;
        private int current_package_index;
        private int next_free_package_index = 1;
        private uint timer_id;

        construct {
            height_request = 300;

            stack = new Gtk.Stack ();
            stack.valign = Gtk.Align.CENTER;
            stack.transition_duration = TRANSITION_DURATION_MILLISECONDS;
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            add (stack);

            set_default_brand ();
            destroy.connect (() => {
               if (timer_id > 0) {
                   Source.remove (timer_id);
                   timer_id = 0;
               }
            });
        }

        public Banner (Switcher switcher) {
            this.switcher = switcher;
            this.switcher.set_stack (stack);
            this.switcher.on_stack_changed.connect (() => {
                set_background ((stack.visible_child as BannerWidget).package);
                if (timer_id > 0) {
                    Source.remove (timer_id);
                    timer_id = 0;
                }
            });
        }

        public void set_default_brand () {
#if POP_OS
            background_color = "#665888";
#else
            background_color = "#7E45BE";
#endif
            foreground_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;

            brand_widget = new BannerWidget (null);
            stack.add_named (brand_widget, "brand");
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
            switcher.update_selected ();
            set_background (package);

            if (brand_widget != null) {
                brand_widget.destroy ();
                brand_widget = null;
            }
        }

        public void next_package () {
            if (next_free_package_index <= 1) {
                return;
            }

            if (++current_package_index >= next_free_package_index) {
                current_package_index = 1;
            }

            stack.set_visible_child_name (current_package_index.to_string ());
            set_background ((stack.visible_child as BannerWidget).package);
            switcher.update_selected ();
        }

        public void go_to_first () {
            if (next_free_package_index <= 1) {
                return;
            }

            current_package_index = 1;
            stack.set_visible_child_name (current_package_index.to_string ());
            set_background ((stack.visible_child as BannerWidget).package);
            switcher.update_selected ();

            if (timer_id > 0) {
                Source.remove (timer_id);
                timer_id = 0;
            }
            timer_id = Timeout.add (MILLISECONDS_BETWEEN_BANNER_ITEMS, () => {
                next_package ();
                return true;
            });
        }

        public void set_background (AppCenterCore.Package? package) {
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

        private void on_any_color_change () {
            reload_css ();
        }

        private void reload_css () {
            var provider = new Gtk.CssProvider ();
            try {
                var colored_css = BANNER_STYLE_CSS.printf (background_color, foreground_color, stack.transition_duration);
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
