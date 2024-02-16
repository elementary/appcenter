/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2021 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ProgressButton : Gtk.Button {
    public AppCenterCore.Package package { get; construct; }

    private static Gtk.CssProvider style_provider;

    private Gtk.ProgressBar progressbar;

    public ProgressButton (AppCenterCore.Package package) {
        Object (package: package);
    }

    static construct {
        style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("io/elementary/appcenter/ProgressButton.css");

        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    construct {
        add_css_class ("progress");

        var provider = new Gtk.CssProvider ();

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
            sensitive = package.change_information.can_cancel && !package.changes_finished;
            /* Ensure progress bar shows complete to match status (lp:1606902) */
            if (package.changes_finished) {
                progressbar.fraction = 1.0f;
            }

            return GLib.Source.REMOVE;
        });
    }
}
