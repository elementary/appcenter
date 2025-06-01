/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2024 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.BackButton : Gtk.Button {
    construct {
        var back_icon = new Gtk.Image.from_icon_name ("go-previous-symbolic");

        var label_widget = new Gtk.Label ("") {
            mnemonic_widget = this
        };

        var box = new Gtk.Box (HORIZONTAL, 0);
        box.append (back_icon);
        box.append (label_widget);

        action_name = "navigation.pop";
        child = box;
        tooltip_markup = Granite.markup_accel_tooltip ({"<alt>Left"});
        valign = CENTER;

        map.connect (() => {
            var current_page = (Adw.NavigationPage) get_ancestor (typeof (Adw.NavigationPage));
            var navigation_view = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));
            var previous_page = navigation_view.get_previous_page (current_page);
            label_widget.label = previous_page.title;
        });
    }
}
