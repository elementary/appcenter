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
        AbstractPackageRowGrid grid;

        public PackageRow.installed (AppCenterCore.Package package, Gtk.SizeGroup? info_size_group, Gtk.SizeGroup? action_size_group, bool show_uninstall = true) {
#if POP_OS
            selectable = false;
#endif
            grid = new InstalledPackageRowGrid (package, info_size_group, action_size_group, show_uninstall);
            add (grid);
            grid.changed.connect (() => {
                changed ();
            });
        }

        public PackageRow.list (AppCenterCore.Package package, Gtk.SizeGroup? info_size_group, Gtk.SizeGroup? action_size_group, bool show_uninstall = true) {
#if POP_OS
            selectable = false;
#endif
            grid = new ListPackageRowGrid (package, info_size_group, action_size_group, show_uninstall);
            add (grid);
            grid.changed.connect (() => {
                changed ();
            });
        }

        public bool get_update_available () {
            return grid.update_available;
        }

        public bool get_is_driver () {
            return grid.is_driver;
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

        public bool has_package () {
            return true;
        }
    }
}
