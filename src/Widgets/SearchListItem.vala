/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.SearchListItem : Gtk.Grid {
    public AppCenterCore.Package package {
        set {
            icon_image.gicon = value.get_icon (icon_image.pixel_size, scale_factor);
            name_label.label = value.get_name ();
            summary_label.label = value.get_summary ();

            remove (action_stack);
            action_stack = new ActionStack (value);
            attach (action_stack, 2, 0, 1, 2);
        }
    }

    private AppCenter.ActionStack action_stack;
    private Gtk.Image icon_image;
    private Gtk.Label name_label;
    private Gtk.Label summary_label;

    class construct {
        set_css_name ("search-list-item");
    }

    construct {
        icon_image = new Gtk.Image () {
            pixel_size = 48
        };

        name_label = new Gtk.Label (null) {
            valign = END,
            wrap = true,
            xalign = 0
        };
        name_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        summary_label = new Gtk.Label (null) {
            valign = START,
            wrap = true,
            xalign = 0
        };
        summary_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        summary_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        attach (icon_image, 0, 0, 1, 2);
        attach (name_label, 1, 0);
        attach (summary_label, 1, 1);
    }
}
