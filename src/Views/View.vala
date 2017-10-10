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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

public abstract class AppCenter.View : Gtk.Stack {
    public signal void subview_entered (string? return_name, bool allow_search, string? custom_header = null, string? custom_search_placeholder = null);

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        expand = true;
    }

    public virtual void show_package (AppCenterCore.Package package) {
        var pk_child = get_child_by_name (package.component.id) as Views.AppInfoView;
        if (pk_child != null) {
            pk_child.reload_css ();
            set_visible_child (pk_child);
            return;
        }

        var app_info_view = new Views.AppInfoView (package);
        app_info_view.show_all ();
        add_named (app_info_view, package.component.id);
        set_visible_child (app_info_view);
    }

    public abstract void return_clicked ();
}
