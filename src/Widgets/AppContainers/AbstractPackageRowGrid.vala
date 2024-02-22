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

    protected AbstractPackageRowGrid (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        var app_icon = new Gtk.Image () {
            pixel_size = 48
        };

        var badge_image = new Gtk.Image () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END,
            pixel_size = 24
        };

        app_icon_overlay = new Gtk.Overlay () {
            child = app_icon
        };

        action_stack = new ActionStack (package) {
            show_open = false
        };

        var scale_factor = get_scale_factor ();

        var plugin_host_package = package.get_plugin_host_package ();
        if (package.kind == AppStream.ComponentKind.ADDON && plugin_host_package != null) {
            app_icon.gicon = plugin_host_package.get_icon (app_icon.pixel_size, scale_factor);
            badge_image.gicon = package.get_icon (badge_image.pixel_size / 2, scale_factor);

            app_icon_overlay.add_overlay (badge_image);
        } else {
            app_icon.gicon = package.get_icon (app_icon.pixel_size, scale_factor);

            if (package.is_runtime_updates) {
                badge_image.icon_name = "system-software-update";
                app_icon_overlay.add_overlay (badge_image);
            }
        }

        margin_top = 6;
        margin_start = 12;
        margin_bottom = 6;
        margin_end = 12;
    }

    protected virtual void set_up_package () {
        package.notify["state"].connect (on_package_state_changed);
        update_state (true);
    }

    protected virtual void update_state (bool first_update = false) {
        action_stack.update_action ();
    }

    private void on_package_state_changed () {
        if (action_stack.state_source > 0) {
            return;
        }

        action_stack.state_source = Idle.add (() => {
            update_state ();
            action_stack.state_source = 0U;
            return GLib.Source.REMOVE;
        });
    }
}
