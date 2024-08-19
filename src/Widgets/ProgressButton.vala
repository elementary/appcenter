/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
    public AppCenterCore.Package? package { get; private set; }

    private Gtk.ProgressBar progressbar;

    construct {
        add_css_class ("progress");
        add_css_class ("text-button");

        var cancel_label = new Gtk.Label (_("Cancel")) {
            mnemonic_widget = this
        };

        progressbar = new Gtk.ProgressBar ();

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (cancel_label);
        box.append (progressbar);

        child = box;
    }

    public void bind_package (AppCenterCore.Package package) {
        if (this.package != null) {
            this.package.change_information.progress_changed.disconnect (update_progress);
            this.package.change_information.status_changed.disconnect (update_progress_status);
        }

        this.package = package;

        package.change_information.progress_changed.connect (update_progress);
        package.change_information.status_changed.connect (update_progress_status);

        update_progress_status ();
        update_progress ();
    }

    private void update_progress () requires (package != null) {
        Idle.add (() => {
            progressbar.fraction = package.progress;
            return GLib.Source.REMOVE;
        });
    }

    private void update_progress_status () requires (package != null) {
        Idle.add (() => {
            tooltip_text = package.get_progress_description ();
            sensitive = package.change_information.can_cancel && !package.changes_finished;
            /* Ensure progress bar shows complete to match status (lp:1606902) */
            if (package.changes_finished) {
                progressbar.fraction = 1.0f;
            }

            return GLib.Source.REMOVE;
        });
    }
}
