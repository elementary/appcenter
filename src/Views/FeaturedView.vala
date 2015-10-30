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

public class AppCenter.Views.FeaturedView : Gtk.Grid {
    public FeaturedView () {
        halign = Gtk.Align.CENTER;
        column_homogeneous = true;
        column_spacing = 6;
        row_spacing = 6;
        margin = 12;
        expand = true;
        var left_featured = get_left_placeholder ();
        var right_featured = get_right_placeholder ();
        var rated_label = new Gtk.Label (_("Best Rated"));
        rated_label.get_style_context ().add_class ("h4");
        ((Gtk.Misc) rated_label).xalign = 0;
        var latest_label = new Gtk.Label (_("Latest Apps"));
        latest_label.get_style_context ().add_class ("h4");
        ((Gtk.Misc) latest_label).xalign = 0;
        attach (left_featured, 0, 0, 1, 1);
        attach (right_featured, 1, 0, 1, 1);
        attach (rated_label, 0, 1, 1, 1);
        attach (latest_label, 1, 1, 1, 1);
    }

    private Gtk.Widget get_left_placeholder () {
        Gdk.RGBA background_color = {0, 0, 0, 1};
        background_color.parse ("#3689e6");
        Gdk.RGBA text_color = {1, 1, 1, 1};
        string title = "Apport";
        string subtitle = "Crash Reporting Tool";
        var icon = new ThemedIcon ("apport");
        var left_placeholder = new Widgets.FeaturedButton (background_color, text_color, title, subtitle, icon);
        return left_placeholder;
    }

    private Gtk.Widget get_right_placeholder () {
        Gdk.RGBA background_color = {0, 0, 0, 1};
        background_color.parse ("#999999");
        Gdk.RGBA text_color = {1, 1, 1, 1};
        string title = "Database";
        string subtitle = "It's grown up and professional";
        var icon = new ThemedIcon ("office-database");
        var left_placeholder = new Widgets.FeaturedButton (background_color, text_color, title, subtitle, icon);
        return left_placeholder;
    }
}
