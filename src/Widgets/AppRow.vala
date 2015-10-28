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

public class AppCenter.Widgets.AppRow : Gtk.ListBoxRow {
    private Details app_infos;
    private Gtk.Image app_image;
    private Gtk.Label name_label;
    private Gtk.Label description_label;
    private Gtk.Label version_label;
    private Gtk.Button install_button;
    public AppRow (Details app_infos) {
        this.app_infos = app_infos;
        if (app_infos.loaded) {
            show_app_data ();
        } else {
            app_infos.loading_finished.connect (() => {
                show_app_data ();
            });
        }
    }

    private void show_app_data () {
        if (app_infos.display_icon != null && app_infos.display_icon != "") {
            app_image.icon_name = app_infos.display_icon;
        }

        name_label.label = app_infos.display_name;
        description_label.label = app_infos.description.split ("\n", 2)[0];
        version_label.label = app_infos.display_version;
    }

    construct {
        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.row_spacing = 6;
        app_image = new Gtk.Image.from_icon_name ("application-default-icon", Gtk.IconSize.DIALOG);
        app_image.margin = 3;
        app_image.margin_end = 0;
        name_label = new Gtk.Label (null);
        name_label.get_style_context ().add_class ("h3");
        name_label.margin_top = 3;
        ((Gtk.Misc) name_label).xalign = 0;
        description_label = new Gtk.Label (null);
        description_label.margin_bottom = 3;
        description_label.ellipsize = Pango.EllipsizeMode.END;
        description_label.single_line_mode = true;
        ((Gtk.Misc) description_label).xalign = 0;
        version_label = new Gtk.Label (null);
        version_label.hexpand = true;
        version_label.margin_top = 3;
        ((Gtk.Misc) version_label).xalign = 0;
        install_button = new Gtk.Button.from_icon_name ("browser-download-symbolic", Gtk.IconSize.BUTTON);
        install_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        grid.attach (app_image, 0, 0, 1, 2);
        grid.attach (name_label, 1, 0, 1, 1);
        grid.attach (description_label, 1, 1, 2, 1);
        grid.attach (version_label, 2, 0, 1, 1);
        grid.attach (install_button, 3, 0, 1, 2);
        add (grid);
        show_all ();
    }
}
