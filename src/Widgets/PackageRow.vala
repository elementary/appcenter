// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

using AppCenterCore;

public class AppCenter.Widgets.PackageRow : Gtk.ListBoxRow {
    public Package package;

    Gtk.Image image;
    Gtk.Label package_name;
    Gtk.Label package_summary;

    // The action button covers Install and Update
    public Gtk.Button action_button;
    Gtk.ProgressBar progress_bar;
    public Gtk.Button cancel_button;
    Gtk.Stack action_stack;

    public PackageRow (Package package) {
        this.package = package;
        package_name.label = package.get_name ();
        package_summary.label = package.get_summary ();
        package_summary.ellipsize = Pango.EllipsizeMode.END;
        image.gicon = package.get_icon ();

        if (package.update_available) {
            action_button.label = _("Update");
        } else if (package.installed) {
            action_stack.no_show_all = true;
            action_stack.hide ();
        }

        package.notify["installed"].connect (() => update_buttons ());
        package.notify["update-available"].connect (() => update_buttons ());

        package.change_information.bind_property ("can-cancel", cancel_button, "sensitive", GLib.BindingFlags.SYNC_CREATE);
        package.change_information.progress_changed.connect (() => update_progress ());
        package.change_information.status_changed.connect (() => update_status ());
        update_progress ();
        update_status ();
    }

    construct {
        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = 12;
        grid.row_spacing = 6;
        grid.column_spacing = 12;

        image = new Gtk.Image ();
        image.icon_size = Gtk.IconSize.DIALOG;
        /* Needed to enforce size on icons from Filesystem/Remote */
        image.pixel_size = 48;

        package_name = new Gtk.Label (null);
        package_name.get_style_context ().add_class ("h3");
        package_name.hexpand = true;
        package_name.valign = Gtk.Align.END;
        ((Gtk.Misc) package_name).xalign = 0;

        package_summary = new Gtk.Label (null);
        package_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        package_summary.hexpand = true;
        package_summary.valign = Gtk.Align.START;
        ((Gtk.Misc) package_summary).xalign = 0;

        action_stack = new Gtk.Stack ();
        action_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        action_stack.hhomogeneous = false;

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.show_text = true;
        progress_bar.valign = Gtk.Align.CENTER;

        cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.margin_end = 6;
        cancel_button.valign = Gtk.Align.CENTER;
        cancel_button.clicked.connect (() => action_cancelled ());

        action_button = new Gtk.Button.with_label (_("Install"));
        action_button.margin_end = 6;
        action_button.valign = Gtk.Align.CENTER;
        action_button.clicked.connect (() => action_clicked.begin ());

        var progress_grid = new Gtk.Grid ();
        progress_grid.valign = Gtk.Align.CENTER;
        progress_grid.column_spacing = 12;
        progress_grid.attach (progress_bar, 0, 0, 1, 1);
        progress_grid.attach (cancel_button, 1, 0, 1, 1);

        action_stack.add_named (action_button, "buttons");
        action_stack.add_named (progress_grid, "progress");

        grid.attach (image, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0, 1, 1);
        grid.attach (package_summary, 1, 1, 1, 1);
        grid.attach (action_stack, 2, 0, 1, 2);
        add (grid);
    }

    private void update_status () {
        progress_bar.text = package.change_information.get_status ();
        if (package.change_information.status == Pk.Status.FINISHED) {
            action_stack.set_visible_child_name ("buttons");
        } else {
            action_stack.set_visible_child_name ("progress");   
            action_stack.no_show_all = false;
            action_stack.show_all ();   
        }        
    }

    private void update_progress () {
        var progress = package.change_information.get_progress ();
        if (progress < 1.0f) {
            action_stack.set_visible_child_name ("progress");
            progress_bar.fraction = progress;
            action_stack.no_show_all = false;
            action_stack.show_all ();               
        } else {
            action_stack.set_visible_child_name ("buttons");
        }
    }

    private void update_buttons () {
        if (package.installed) {
            if (package.update_available) {
                action_button.label = _("Update");
                action_button.no_show_all = false;
                action_button.show_all ();    

                action_stack.no_show_all = false;
                action_stack.show_all ();
            } else {
                action_stack.no_show_all = true;
                action_stack.hide ();
            }
        } else {
            action_button.label = _("Install");
            action_button.no_show_all = false;
            action_button.show_all ();

            action_stack.no_show_all = false;
            action_stack.show_all ();                
        }

        changed ();        
    }

    private void action_cancelled () {
        package.action_cancellable.cancel ();
    }

    private async void action_clicked () {
        try {
            if (package.update_available) {
                yield package.update ();
            } else {
                yield package.install ();
            }
            action_stack.no_show_all = true;
            action_stack.hide ();
        } catch (Error e) {
            critical (e.message);
            action_stack.set_visible_child_name ("buttons");
        }
    }
}
