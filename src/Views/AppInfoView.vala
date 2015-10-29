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

public class AppCenter.Views.AppInfoView : Gtk.Grid {
    Pk.Package package;
    Gee.Collection<AppStream.Component> components;

    Gtk.Image app_icon;
    Gtk.Image app_screenshot;
    Gtk.Label app_name;
    Gtk.Label app_version;
    Gtk.Label app_summary;
    Gtk.Label app_description;

    public AppInfoView (Pk.Package package, Gee.Collection<AppStream.Component> components) {
        app_name.label = package.get_name ();
        app_version.label = package.get_version ();
        app_summary.label = package.get_summary ();
        foreach (var component in components) {
            component.get_icon_urls ().foreach ((k, v) => {
                app_icon.gicon = new FileIcon (File.new_for_path (v));
            });
        }
    }
    
    construct {
        app_icon = new Gtk.Image ();
        app_icon.icon_size = Gtk.IconSize.DIALOG;
        app_screenshot = new Gtk.Image ();
        app_screenshot.pixel_size = 200;
        app_screenshot.icon_name = "image-x-generic";
        app_name = new Gtk.Label (null);
        ((Gtk.Misc) app_name).xalign = 0;
        app_version = new Gtk.Label (null);
        ((Gtk.Misc) app_version).xalign = 0;
        app_version.hexpand = true;
        app_summary = new Gtk.Label (null);
        ((Gtk.Misc) app_summary).xalign = 0;
        app_description = new Gtk.Label (null);
        ((Gtk.Misc) app_description).xalign = 0;
        var content_grid = new Gtk.Grid ();
        content_grid.orientation = Gtk.Orientation.HORIZONTAL;
        content_grid.halign = Gtk.Align.CENTER;
        content_grid.valign = Gtk.Align.CENTER;
        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.expand = true;
        scrolled.add (app_description);
        content_grid.add (scrolled);
        content_grid.add (app_screenshot);
        attach (app_icon, 0, 0, 1, 2);
        attach (app_name, 1, 0, 1, 1);
        attach (app_version, 2, 0, 1, 1);
        attach (app_summary, 1, 1, 2, 1);
        attach (content_grid, 0, 2, 3, 1);
    }
}
