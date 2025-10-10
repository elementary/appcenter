/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
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
            sensitive = package.change_information.can_cancel;
            return GLib.Source.REMOVE;
        });
    }
}
