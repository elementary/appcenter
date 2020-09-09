// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2017 elementary LLC. (https://elementary.io)
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

public class AppCenter.Widgets.InstalledPackageRowGrid : AbstractPackageRowGrid {
    Gtk.Label app_version;
    Gtk.Stack release_stack;
    Gtk.Expander release_expander;
    Gtk.Label release_expander_label;
    Gtk.Label release_description;
    Gtk.Label release_single_label;
    private Gtk.Revealer release_stack_revealer;
    AppStream.Release? newest = null;

    private Gtk.Grid info_grid;

    public InstalledPackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? info_size_group, Gtk.SizeGroup? action_size_group) {
        base (package);

        if (action_size_group != null) {
            action_size_group.add_widget (action_button);
            action_size_group.add_widget (cancel_button);
        }

        if (info_size_group != null) {
            info_size_group.add_widget (info_grid);
        }

        set_up_package ();
    }

    construct {
        margin_bottom = 12;
        updates_view = true;
        app_version = new Gtk.Label (null);
        app_version.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        ((Gtk.Misc) app_version).xalign = 0;

        progress_bar.width_request = 100;

        release_description = new Gtk.Label (null);
        release_description.margin_top = 6;
        release_description.selectable = true;
        release_description.use_markup = true;
        release_description.wrap = true;
        release_description.margin_start = 12;
        release_description.xalign = 0;

        release_expander = new Gtk.Expander ("");
        release_expander.margin_top = 12;
        release_expander.add (release_description);
        release_expander.visible = true;
        release_expander.show_all ();
        release_expander.button_press_event.connect (() => {
            release_expander.expanded = !release_expander.expanded;
            return true;
        });

        release_expander_label = new Gtk.Label ("");
        release_expander_label.wrap = true;
        release_expander_label.xalign = 0;
        release_expander_label.use_markup = true;
        release_expander.set_label_widget (release_expander_label);

        release_single_label = new Gtk.Label (null);
        release_single_label.selectable = true;
        release_single_label.use_markup = true;
        release_single_label.wrap = true;
        release_single_label.xalign = 0;
        release_single_label.visible = true;
        release_single_label.show_all ();

        release_stack = new Gtk.Stack ();
        release_stack.add (release_expander);
        release_stack.add (release_single_label);

        release_stack_revealer = new Gtk.Revealer ();
        release_stack_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        release_stack_revealer.add (release_stack);

        info_grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6,
            valign = Gtk.Align.START
        };
        info_grid.attach (image, 0, 0, 1, 2);
        info_grid.attach (package_name, 1, 0);
        info_grid.attach (app_version, 1, 1);

        action_stack.homogeneous = false;
        action_stack.margin_top = 10;
        action_stack.valign = Gtk.Align.START;

        var grid = new Gtk.Grid () {
            column_spacing = 24
        };
        grid.attach (info_grid, 0, 0);
        grid.attach (release_stack_revealer, 2, 0, 1, 2);
        grid.attach (action_stack, 3, 0);

        add (grid);
    }

    protected override void set_up_package (uint icon_size = 48) {
        if (package.get_version () != null) {
            if (package.has_multiple_origins) {
                app_version.label = "%s - %s".printf (package.get_version (), package.origin_description);
            } else {
                app_version.label = package.get_version ();
            }
        }

        app_version.ellipsize = Pango.EllipsizeMode.END;

        base.set_up_package (icon_size);
    }

    protected override void update_state (bool first_update = false) {
        if (!first_update && package.get_version != null) {
            if (package.has_multiple_origins) {
                app_version.label = "%s - %s".printf (package.get_version (), package.origin_description);
            } else {
                app_version.label = package.get_version ();
            }
        }

        if (package.state == AppCenterCore.Package.State.UPDATE_AVAILABLE) {
            if (newest == null) {
                newest = package.get_newest_release ();
                if (newest != null) {
                    string description = ReleaseRow.format_release_description (newest);
                    string[] lines = description.split ("\n", 2);
                    if (lines.length > 1) {
                        release_expander_label.label = lines[0];
                        release_description.set_text (lines[1]);
                        release_stack.visible_child = release_expander;
                    } else if (lines.length > 0) {
                        release_single_label.label = lines[0];
                        release_single_label.wrap = true;
                        release_stack.visible_child = release_single_label;
                    }

                    release_stack_revealer.reveal_child = true;
                }
            } else {
                release_stack_revealer.reveal_child = true;
            }
        }

        update_action ();
        changed ();
    }

    protected override void update_progress_status () {
        if (package.change_information.status == AppCenterCore.ChangeInformation.Status.WAITING ||
            package.change_information.status == AppCenterCore.ChangeInformation.Status.FINISHED) {
            progress_bar.no_show_all = true;
            progress_bar.hide ();
        } else {
            progress_bar.no_show_all = false;
            progress_bar.show_all ();
        }

        base.update_progress_status ();
    }
}
