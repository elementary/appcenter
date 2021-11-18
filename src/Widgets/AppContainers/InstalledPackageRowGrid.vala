/*-
 * Copyright 2014-2021 elementary, Inc. (https://elementary.io)
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
    public signal void changed ();

    private AppStream.Release? newest = null;
    private Gtk.Expander release_expander;
    private Gtk.Label app_version;
    private Gtk.Label release_description;
    private Gtk.Label release_expander_label;
    private Gtk.Label release_single_label;
    private Gtk.Revealer release_stack_revealer;
    private Gtk.Stack release_stack;

    private static Gtk.SizeGroup info_size_group;

    public InstalledPackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? action_size_group) {
        Object (package: package);

        if (action_size_group != null) {
            action_size_group.add_widget (action_button);
            action_size_group.add_widget (cancel_button);
        }

        set_up_package ();
    }

    static construct {
        info_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
    }

    construct {
        updates_view = true;

        var package_name = new Gtk.Label (package.get_name ()) {
            valign = Gtk.Align.END,
            xalign = 0
        };
        package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        app_version = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            valign = Gtk.Align.START,
            xalign = 0
        };
        app_version.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        release_description = new Gtk.Label (null) {
            margin_start = 12,
            selectable = true,
            use_markup = true,
            wrap = true,
            xalign = 0
        };

        release_expander_label = new Gtk.Label ("") {
            wrap = true,
            use_markup = true
        };

        release_expander = new Gtk.Expander ("") {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START,
            label_widget = release_expander_label,
            visible = true
        };
        release_expander.add (release_description);
        release_expander.show_all ();

        release_single_label = new Gtk.Label (null) {
            halign = Gtk.Align.START,
            selectable = true,
            use_markup = true,
            valign = Gtk.Align.START,
            visible = true,
            wrap = true,
            xalign = 0
        };
        release_single_label.show_all ();

        release_stack = new Gtk.Stack ();
        release_stack.add (release_expander);
        release_stack.add (release_single_label);

        release_stack_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        release_stack_revealer.add (release_stack);

        var info_grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6,
            valign = Gtk.Align.START
        };
        info_grid.attach (app_icon_overlay, 0, 0, 1, 2);
        info_grid.attach (package_name, 1, 0);
        info_grid.attach (app_version, 1, 1);

        action_stack.homogeneous = false;
        action_stack.margin_top = 10;
        action_stack.valign = Gtk.Align.START;
        action_stack.hexpand = true;

        var grid = new Gtk.Grid () {
            column_spacing = 24
        };
        grid.attach (info_grid, 0, 0);
        grid.attach (release_stack_revealer, 2, 0, 1, 2);
        grid.attach (action_stack, 3, 0);

        add (grid);

        info_size_group.add_widget (info_grid);

        release_expander.button_press_event.connect (() => {
            release_expander.expanded = !release_expander.expanded;
            return true;
        });
    }

    protected override void set_up_package () {
        if (package.get_version () != null) {
            if (package.has_multiple_origins) {
                app_version.label = "%s - %s".printf (package.get_version (), package.origin_description);
            } else {
                app_version.label = package.get_version ();
            }
        }

        base.set_up_package ();
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
}
