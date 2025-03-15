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

public abstract class AppCenter.Widgets.AbstractPackageRowGrid : Gtk.Box {
    public AppCenterCore.Package package { get; construct set; }

    public bool action_sensitive {
        set {
            action_stack.action_sensitive = value;
        }
    }

    protected ActionStack action_stack;
    protected Gtk.Label package_name;
    protected AppIcon app_icon;

    protected AbstractPackageRowGrid (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        app_icon = new AppIcon (48) {
            package = package
        };

        action_stack = new ActionStack (package) {
            show_open = false
        };

        margin_top = 6;
        margin_start = 12;
        margin_bottom = 6;
        margin_end = 12;
    }
}
