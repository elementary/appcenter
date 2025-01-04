// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public abstract class AppCenter.Widgets.AbstractPackageRowGrid : Gtk.Box {
    public AppCenterCore.Package package { get; construct set; }

    public bool action_sensitive {
        set {
            action_stack.action_sensitive = value;
        }
    }

    protected ActionStack action_stack;
    protected Gtk.Label package_name;
    protected Gtk.Overlay app_icon_overlay;
    protected Gtk.Stack image_stack;
    protected Gtk.Image updated_icon_image;

    protected AbstractPackageRowGrid (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        var icon_image = new Gtk.Image () {
            pixel_size = 48
        };

        updated_icon_image = new Gtk.Image () {
            pixel_size = 48
        };

        image_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        image_stack.add_child (icon_image);
        image_stack.add_child (updated_icon_image);

        var badge_image = new Gtk.Image () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END,
            pixel_size = 24
        };

        app_icon_overlay = new Gtk.Overlay () {
            child = image_stack
        };

        action_stack = new ActionStack (package) {
            show_open = false
        };

        var scale_factor = get_scale_factor ();

        var plugin_host_package = package.get_plugin_host_package ();
        if (package.kind == AppStream.ComponentKind.ADDON && plugin_host_package != null) {
            icon_image.gicon = plugin_host_package.get_icon (icon_image.pixel_size, scale_factor);
            updated_icon_image.gicon = plugin_host_package.get_icon (updated_icon_image.pixel_size, scale_factor);
            badge_image.gicon = package.get_icon (badge_image.pixel_size / 2, scale_factor);

            app_icon_overlay.add_overlay (badge_image);
        } else {
            icon_image.gicon = package.get_icon (icon_image.pixel_size, scale_factor);
            updated_icon_image.gicon = package.get_icon (updated_icon_image.pixel_size, scale_factor);

            if (package.is_runtime_updates) {
                badge_image.icon_name = "system-software-update";
                app_icon_overlay.add_overlay (badge_image);
            }
        }

        if (package.uses_generic_icon && package.icon_available) {
            icon_image.add_css_class ("icon-dim");
        }

        margin_top = 6;
        margin_start = 12;
        margin_bottom = 6;
        margin_end = 12;
    }

    public void update_icon (Icon icon) {
        updated_icon_image.clear ();
        updated_icon_image.set_from_gicon (icon);
        image_stack.visible_child = updated_icon_image;
    }
}
