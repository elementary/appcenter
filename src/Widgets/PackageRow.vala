// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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

namespace AppCenter.Widgets {
    public class PackageRow : Gtk.ListBoxRow, AppListRow {
        PackageRowGrid grid;

        public PackageRow (AppCenterCore.Package package, Gtk.SizeGroup? size_group, bool show_uninstall = true) {
            grid = new PackageRowGrid (package, size_group, show_uninstall);
            add (grid);
            grid.changed.connect (() => {
                changed ();
            });
        }

        public bool get_update_available () {
            return grid.update_available;
        }

        public bool get_is_updating () {
            return grid.is_updating;
        }

        public bool get_is_os_updates () {
            return grid.is_os_updates;
        }

        public string get_name_label () {
            return grid.name_label;
        }

        public AppCenterCore.Package? get_package () {
            return grid.package;
        }

        public void set_action_sensitive (bool is_sensitive) {
            grid.action_sensitive = is_sensitive;
        }

        private class PackageRowGrid : AbstractAppContainer {
            public signal void changed ();

            public PackageRowGrid (AppCenterCore.Package package, Gtk.SizeGroup? size_group, bool show_uninstall = true) {
                this.package = package;
                this.show_uninstall = show_uninstall;
                set_up_package ();

                if (size_group != null) {
                    size_group.add_widget (action_button);
                    size_group.add_widget (cancel_button);
                    size_group.add_widget (uninstall_button);
                }
            }

            construct {
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


                attach (image, 0, 0, 1, 2);
                attach (package_name, 1, 0, 1, 1);
                attach (package_summary, 1, 1, 1, 1);
                attach (action_stack, 2, 0, 1, 2);
            }

            protected override void update_state () {
                update_action (show_uninstall);
                changed ();
            }
        }
    }
}
