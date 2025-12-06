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

        package.change_information.progress_changed.connect (update_progress);
        package.change_information.status_changed.connect (update_progress_status);

        update_progress_status ();
        update_progress ();

        var cancel_label = new Gtk.Label (_("Cancel")) {
            mnemonic_widget = this
        };

        progressbar = new Gtk.ProgressBar ();

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (cancel_label);
        box.append (progressbar);

        child = box;
        action_name = ACTION_PREFIX + AppCenterCore.ChangeInformation.CANCEL_ACTION_NAME;
        insert_action_group (ACTION_GROUP_PREFIX, package.change_information.action_group);
    }

    private void update_progress () {
        Idle.add (() => {
            progressbar.fraction = package.progress;
            return GLib.Source.REMOVE;
        });
    }

    private void update_progress_status () {
        Idle.add (() => {
            tooltip_text = package.get_progress_description ();
            /* Ensure progress bar shows complete to match status (lp:1606902) */
            if (package.changes_finished) {
                progressbar.fraction = 1.0f;
            }

            return GLib.Source.REMOVE;
        });
    }
}
