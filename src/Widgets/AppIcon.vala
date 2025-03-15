/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.AppIcon : Gtk.Box {
    public int pixel_size { get; construct; }
    public Icon gicon { get; set; }

    public AppIcon (int pixel_size) {
        Object (pixel_size: pixel_size);
    }

    construct {
        var image = new Gtk.Image () {
            pixel_size = pixel_size
        };

        append (image);

        bind_property ("gicon", image, "gicon");
    }
}
