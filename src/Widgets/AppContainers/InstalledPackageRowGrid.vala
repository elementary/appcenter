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
            action_size_group.add_widget (action_button);
            action_size_group.add_widget (cancel_button);
        }

        set_up_package ();
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

        var release_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            valign = Gtk.Align.CENTER
        };

        release_button_revealer = new Gtk.Revealer () {
            halign = Gtk.Align.END,
            hexpand = true,
            tooltip_text = _("Release notes"),
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        release_button_revealer.add (release_button);

        action_stack.hexpand = false;

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6
        };
        grid.attach (app_icon_overlay, 0, 0, 1, 2);
        grid.attach (package_name, 1, 0);
        grid.attach (app_version, 1, 1);
        grid.attach (release_button_revealer, 2, 0, 1, 2);
        grid.attach (action_stack, 3, 0, 1, 2);

        add (grid);

        release_button.clicked.connect (() => {
            var releases_dialog = new ReleaseDialog (package) {
                transient_for = (Gtk.Window) get_toplevel ()
            };
            releases_dialog.present ();
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
                    release_button_revealer.reveal_child = true;
                }
            } else {
                release_button_revealer.reveal_child = true;
            }
        }

        update_action ();
        changed ();
    }

    private class ReleaseDialog : Granite.Dialog {
        public AppCenterCore.Package package { get; construct; }

        public ReleaseDialog (AppCenterCore.Package package) {
            Object (package: package);
        }

        construct {
            title = _("What's new in %s %s").printf (package.get_name (), package.get_version ());
            modal = true;

            var releases_title = new Gtk.Label (title) {
                selectable = true,
                width_chars = 20,
                wrap = true
            };
            releases_title.get_style_context ().add_class ("primary");

            var release_description = new Gtk.Label (ReleaseRow.format_release_description (package.get_newest_release ())) {
                selectable = true,
                use_markup = true,
                wrap = true,
                xalign = 0
            };

            var releases_dialog_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_end = 12,
                margin_start = 12,
                vexpand = true
            };
            releases_dialog_box.add (releases_title);
            releases_dialog_box.add (release_description);
            releases_dialog_box.show_all ();

            get_content_area ().add (releases_dialog_box);

            add_button (_("Close"), Gtk.ResponseType.CLOSE);

            response.connect (() => {
                close ();
            });
        }
    }
}
