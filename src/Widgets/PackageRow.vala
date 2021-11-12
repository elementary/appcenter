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
    public class PackageRow : Gtk.ListBoxRow {
        AbstractPackageRowGrid grid;

        public PackageRow.installed (AppCenterCore.Package package, Gtk.SizeGroup? action_size_group) {
            grid = new InstalledPackageRowGrid (package, action_size_group);
            add (grid);
            ((InstalledPackageRowGrid) grid).changed.connect (() => {
                changed ();
            });
        }

        public PackageRow.list (AppCenterCore.Package package) {
            grid = new ListPackageRowGrid (package);
            add (grid);
        }

        public AppCenterCore.Package? get_package () {
            return grid.package;
        }

        public void set_action_sensitive (bool is_sensitive) {
            grid.action_sensitive = is_sensitive;
        }
    }
}
