/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
    private const string ACTION_GROUP_PREFIX = "package";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    public AppCenterCore.Package package { get; construct; }

    private Gtk.ProgressBar progressbar;

    public ProgressButton (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        add_css_class ("progress");
        add_css_class ("text-button");

        package.change_information.bind_property ("status-description", this, "tooltip-text", SYNC_CREATE);

        var cancel_label = new Gtk.Label (_("Cancel")) {
            mnemonic_widget = this
        };

        progressbar = new Gtk.ProgressBar ();
        package.change_information.bind_property ("progress", progressbar, "fraction", SYNC_CREATE);

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (cancel_label);
        box.append (progressbar);

        child = box;
        action_name = ACTION_PREFIX + AppCenterCore.ChangeInformation.CANCEL_ACTION_NAME;
        insert_action_group (ACTION_GROUP_PREFIX, package.change_information.action_group);
    }
}
