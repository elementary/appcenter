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
    private Gtk.Label app_version;
    private Gtk.Revealer release_button_revealer;

    public InstalledPackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? action_size_group) {
        Object (package: package);

        if (action_size_group != null) {
            action_size_group.add_widget (action_stack.action_button);
            action_size_group.add_widget (action_stack.cancel_button);
        }

        set_up_package ();
    }

    construct {
        app_icon_overlay.margin_end = 12;

        action_stack.updates_view = true;
        action_stack.margin_start = 12;

        var package_name = new Gtk.Label (package.get_name ()) {
            wrap = true,
            max_width_chars = 25,
            valign = END,
            xalign = 0
        };
        package_name.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        app_version = new Gtk.Label (null) {
            ellipsize = END,
            valign = START,
            xalign = 0
        };
        app_version.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        app_version.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var release_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic") {
            margin_start = 12,
            tooltip_text = _("Release notes"),
            valign = Gtk.Align.CENTER
        };

        release_button_revealer = new Gtk.Revealer () {
            child = release_button,
            halign = END,
            hexpand = true,
            transition_type = SLIDE_RIGHT
        };

        action_stack.hexpand = false;

        var grid = new Gtk.Grid () {
            row_spacing = 3
        };
        grid.attach (app_icon_overlay, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (app_version, 1, 1);
        grid.attach (release_button_revealer, 2, 0, 1, 2);
        grid.attach (action_stack, 3, 0, 1, 2);

        append (grid);

        release_button.clicked.connect (() => {
            var releases_dialog = new ReleaseDialog (package) {
                transient_for = ((Gtk.Application) Application.get_default ()).active_window
            };
            releases_dialog.present ();
        });
    }

    private void set_up_package () {
        if (package.get_version () != null) {
            if (package.has_multiple_origins) {
                app_version.label = "%s — %s".printf (package.get_version (), package.origin_description);
            } else {
                app_version.label = package.get_version ();
            }
        }

        package.notify["state"].connect (() => {
            update_state ();
        });
        update_state (true);
    }

    private void update_state (bool first_update = false) {
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
                if (newest != null && newest.get_description () != null) {
                    release_button_revealer.reveal_child = true;
                }
            } else {
                release_button_revealer.reveal_child = true;
            }
        }

        changed ();
    }

    private class ReleaseDialog : Granite.Dialog {
        public AppCenterCore.Package package { get; construct; }

        public ReleaseDialog (AppCenterCore.Package package) {
            Object (package: package);
        }

        construct {
            title = _("What's new in %s").printf (package.get_name ());
            modal = true;

            var releases_title = new Gtk.Label (title) {
                selectable = true,
                width_chars = 20,
                wrap = true
            };
            releases_title.add_css_class ("primary");

            var release_row = new AppCenter.Widgets.ReleaseRow (package.get_newest_release ());

            var releases_dialog_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_end = 12,
                margin_start = 12,
                vexpand = true
            };
            releases_dialog_box.append (releases_title);
            releases_dialog_box.append (release_row);

            get_content_area ().append (releases_dialog_box);

            add_button (_("Close"), Gtk.ResponseType.CLOSE);

            response.connect (() => {
                close ();
            });
        }
    }
}
