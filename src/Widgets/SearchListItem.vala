/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.SearchListItem : Gtk.Grid {
    public AppCenterCore.Package package {
        set {
            app_icon.package = value;
            name_label.label = value.name;
            summary_label.label = value.get_summary ();

            if (action_stack != null) {
                remove (action_stack);
            }

            action_stack = new ActionStack (value);
            attach (action_stack, 2, 0, 1, 2);
        }
    }

    private AppCenter.ActionStack action_stack;
    private AppCenter.AppIcon app_icon;
    private Gtk.Label name_label;
    private Gtk.Label summary_label;

    class construct {
        set_css_name ("search-list-item");
    }

    construct {
        app_icon = new AppIcon (48);

        name_label = new Gtk.Label (null) {
            ellipsize = END,
            max_width_chars = 30,
            valign = END,
            xalign = 0
        };
        name_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        summary_label = new Gtk.Label (null) {
            ellipsize = END,
            hexpand = true,
            lines = 2,
            width_chars = 20,
            max_width_chars = 35,
            valign = START,
            wrap = true,
            xalign = 0
        };
        summary_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        summary_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        attach (app_icon, 0, 0, 1, 2);
        attach (name_label, 1, 0);
        attach (summary_label, 1, 1);
    }
}
