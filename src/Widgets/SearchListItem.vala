/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.SearchListItem : Granite.ListItem {
    public AppCenterCore.Package package {
        set {
            app_icon.package = value;
            label.label = value.name;
            label.secondary_text = value.get_summary ();

            if (action_stack != null) {
                box.remove (action_stack);
            }

            action_stack = new ActionStack (value);
            box.append (action_stack);
        }
    }

    private AppCenter.ActionStack action_stack;
    private AppCenter.AppIcon app_icon;
    private Granite.Box box;
    private Granite.HeaderLabel label;

    class construct {
        set_css_name ("search-list-item");
    }

    construct {
        app_icon = new AppIcon (48);

        label = new Granite.HeaderLabel ("") {
            ellipsize = END,
            size = H3,
            valign = CENTER
        };

        box = new Granite.Box (HORIZONTAL);
        box.append (app_icon);
        box.append (label);

        child = box;
    }
}
