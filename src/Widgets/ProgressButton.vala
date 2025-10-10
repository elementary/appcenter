/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
    public AppCenterCore.Package package { get; construct; }

    public ProgressButton (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        add_css_class ("progress");
        add_css_class ("text-button");

        var cancel_label = new Gtk.Label (_("Cancel")) {
            mnemonic_widget = this
        };

        var progressbar = new Gtk.ProgressBar ();
        package.change_information.bind_property ("progress", progressbar, "fraction", SYNC_CREATE);

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (cancel_label);
        box.append (progressbar);

        child = box;

        package.change_information.bind_property ("can-cancel", this, "sensitive", SYNC_CREATE);
        package.change_information.bind_property ("status-description", this, "tooltip-text", SYNC_CREATE);
    }
}
