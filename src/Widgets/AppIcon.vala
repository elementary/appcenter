/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.AppIcon : Adw.Bin {
    public int pixel_size { get; construct; }
    public AppCenterCore.Package package { get; set; }
    public Icon badge_icon { get; set; }
    public Icon icon { get; set; }
    public Gtk.Stack icon_stack { get; set; }

    public AppIcon (int pixel_size) {
        Object (pixel_size: pixel_size);
    }

    construct {
        var image_default_icon = new Gtk.Image () {
            pixel_size = pixel_size,
            gicon = new ThemedIcon ("application-default-icon"),
        };
        image_default_icon.add_css_class ("icon-dim");

        var image = new Gtk.Image () {
            pixel_size = pixel_size
        };

        var badge_image = new Gtk.Image () {
            halign = END,
            valign = END,
            pixel_size = pixel_size / 2
        };

        icon_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        icon_stack.add_named (image_default_icon, "base-icon");
        icon_stack.add_named (image, "updated-icon");
        icon_stack.visible_child_name = package != null ? "base-icon": "updated-icon";

        var overlay = new Gtk.Overlay () {
            child = icon_stack,
            valign = START
        };
        overlay.add_overlay (badge_image);

        child = overlay;

        bind_property ("icon", image, "gicon");
        bind_property ("badge-icon", badge_image, "gicon");

        notify["package"].connect (fetch_icon);

        AppCenterCore.FlatpakBackend.get_default ().on_metadata_remote_preprocessed.connect ((remote_title) => {
            if (package != null && package.origin_description == remote_title) {
                fetch_icon ();
            }
        });
    }

    private void fetch_icon () {
        var plugin_host_package = get_plugin_host_package (package.component);
        if (plugin_host_package != null) {
            icon = plugin_host_package.get_icon (pixel_size, scale_factor);
            badge_icon = package.get_icon (pixel_size / 2, scale_factor);

            return;
        }

        icon = package.get_icon (pixel_size, scale_factor);
        icon_stack.visible_child_name = icon.to_string () == "application-default-icon" ? "base-icon" : "updated-icon";

        if (package.is_runtime_updates) {
            badge_icon = new ThemedIcon ("system-software-update");
            return;
        }

        badge_icon = null;
    }

    private AppCenterCore.Package? get_plugin_host_package (AppStream.Component component) {
        if (component.get_kind () != AppStream.ComponentKind.ADDON) {
            return null;
        }

        var extends = component.get_extends ();
        if (extends == null || extends.length < 1) {
            return null;
        }

        for (int i = 0; i < extends.length; i++) {
            var package = AppCenterCore.FlatpakBackend.get_default ().get_package_for_component_id (extends[i]);
            if (package != null) {
                return package;
            }
        }

        return null;
    }
}
