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

            set_categories (value.component.get_categories ());

            if (action_stack != null) {
                remove (action_stack);
            }

            action_stack = new ActionStack (value);
            attach (action_stack, 2, 0, 1, 3);
        }
    }

    private AppCenter.ActionStack action_stack;
    private Gtk.Image category_image;
    private Gtk.Image icon_image;
    private Gtk.Label category_label;
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

        category_image = new Gtk.Image ();
        category_image.add_css_class (Granite.STYLE_CLASS_ACCENT);

        category_label = new Gtk.Label (null);
        category_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        category_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var category_box = new Gtk.Box (HORIZONTAL, 0);
        category_box.add_css_class ("category");
        category_box.append (category_image);
        category_box.append (category_label);

        attach (icon_image, 0, 0, 1, 3);
        attach (name_label, 1, 0);
        attach (summary_label, 1, 1);
        attach (category_box, 1, 2);
    }

    private void set_categories (GLib.GenericArray<string> categories) {
        foreach (unowned var category in categories) {
            switch (category) {
                case "AudioVideo":
                    category_image.icon_name = "applications-multimedia-symbolic";
                    category_image.add_css_class ("orange");
                    category_label.label = _("Multimedia");
                    return;
                case "Development":
                    category_image.icon_name = "applications-development-symbolic";
                    category_image.add_css_class ("purple");
                    category_label.label = _("Development");
                    return;
                case "Engineering":
                    category_image.icon_name = "applications-engineering-symbolic";
                    category_image.add_css_class ("yellow");
                    category_label.label = _("Engineering");
                    return;
                case "Game":
                    category_image.icon_name = "applications-games-symbolic";
                    category_image.add_css_class ("mint");
                    category_label.label = _("Game");
                    return;
                case "Graphics":
                    category_image.icon_name = "applications-graphics-symbolic";
                    category_image.add_css_class ("pink");
                    category_label.label = _("Graphics");
                    return;
                case "Network":
                    category_image.icon_name = "applications-internet-symbolic";
                    category_image.add_css_class ("blue");
                    category_label.label = _("Internet");
                    return;
                case "Office":
                    category_image.icon_name = "applications-office-symbolic";
                    category_image.add_css_class ("slate");
                    category_label.label = _("Office");
                    return;
                case "Science":
                    category_image.icon_name = "applications-science-symbolic";
                    category_image.add_css_class ("green");
                    category_label.label = _("Science");
                    return;
                case "Utility":
                    category_image.icon_name = "applications-utilities-symbolic";
                    category_image.add_css_class ("red");
                    category_label.label = _("Accessories");
                    return;
            }
        }

        category_label.label = _("Other");
        category_image.add_css_class ("slate");
        category_image.icon_name = "applications-other-symbolic";
    }
}
