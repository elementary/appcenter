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

using AppCenterCore;

public class AppCenter.Views.CategoryView : Gtk.Stack {
    public signal void category_entered (string category_name);
    private Gtk.Grid categories_grid;

    public CategoryView () {
        
    }

    construct {
        transition_type = Gtk.StackTransitionType.OVER_DOWN_UP;
        expand = true;
        categories_grid = new Gtk.Grid ();
        categories_grid.margin = 12;
        categories_grid.expand = true;
        categories_grid.column_spacing = 12;
        categories_grid.row_spacing = 12;
        categories_grid.column_homogeneous = true;
        categories_grid.row_homogeneous = true;
        categories_grid.halign = Gtk.Align.CENTER;
        categories_grid.valign = Gtk.Align.CENTER;

        var office_category = new Category (Pk.Group.OFFICE, _("Office"), "applications-office", _("Be productive!"));
        var office_item = new Widgets.CategoryItem (office_category);
        office_item.clicked.connect (() => show_app_list_for_category.begin (office_category));
        categories_grid.attach (office_item, 0, 0, 1, 1);

        var multimedia_category = new Category (Pk.Group.MULTIMEDIA, _("Multimedia"), "applications-multimedia", _("Listen to music"));
        var multimedia_item = new Widgets.CategoryItem (multimedia_category);
        multimedia_item.clicked.connect (() => show_app_list_for_category.begin (multimedia_category));
        categories_grid.attach (multimedia_item, 1, 0, 1, 1);

        var internet_category = new Category (Pk.Group.INTERNET, _("Internet"), "applications-internet", _("Explore the web"));
        var internet_item = new Widgets.CategoryItem (internet_category);
        internet_item.clicked.connect (() => show_app_list_for_category.begin (internet_category));
        categories_grid.attach (internet_item, 2, 0, 1, 1);

        var communication_category = new Category (Pk.Group.COMMUNICATION, _("Communication"), "applications-chat", _("Stay in touch"));
        var communication_item = new Widgets.CategoryItem (communication_category);
        communication_item.clicked.connect (() => show_app_list_for_category.begin (communication_category));
        categories_grid.attach (communication_item, 0, 1, 1, 1);

        var games_category = new Category (Pk.Group.GAMES, _("Games"), "applications-games", _("Be a hero"));
        var games_item = new Widgets.CategoryItem (games_category);
        games_item.clicked.connect (() => show_app_list_for_category.begin (games_category));
        categories_grid.attach (games_item, 1, 1, 1, 1);

        var science_category = new Category (Pk.Group.SCIENCE, _("Science"), "applications-science", _("Explore the unknown"));
        var science_item = new Widgets.CategoryItem (science_category);
        science_item.clicked.connect (() => show_app_list_for_category.begin (science_category));
        categories_grid.attach (science_item, 2, 1, 1, 1);

        var education_category = new Category (Pk.Group.EDUCATION, _("Education"), "applications-education", _("Lern something new"));
        var education_item = new Widgets.CategoryItem (education_category);
        education_item.clicked.connect (() => show_app_list_for_category.begin (education_category));
        categories_grid.attach (education_item, 0, 2, 1, 1);

        var graphics_category = new Category (Pk.Group.GRAPHICS, _("Graphics"), "applications-graphics", _("Draw something!"));
        var graphics_item = new Widgets.CategoryItem (graphics_category);
        graphics_item.clicked.connect (() => show_app_list_for_category.begin (graphics_category));
        categories_grid.attach (graphics_item, 1, 2, 1, 1);

        var font_category = new Category (Pk.Group.FONTS, _("Fonts"), "applications-fonts", _("Enhance your docs"));
        var font_item = new Widgets.CategoryItem (font_category);
        font_item.clicked.connect (() => show_app_list_for_category.begin (font_category));
        categories_grid.attach (font_item, 2, 2, 1, 1);
        add (categories_grid);
    }

    public void return_clicked () {
        set_visible_child (categories_grid);
    }

    private async void show_app_list_for_category (Category category) {
        category_entered (category.category_name);
        var child = get_child_by_name (category.category_name);
        if (child != null) {
            set_visible_child (child);
            return;
        }

        var app_list_view = new Views.AppListView ();
        app_list_view.show_all ();
        add_named (app_list_view, category.category_name);
        set_visible_child (app_list_view);

        unowned Client client = Client.get_default ();
        // Do not show dev packages.
        var dev_filter = Utils.bitfield_from_filter (Pk.Filter.NOT_DEVELOPMENT);
        // Only show the latest version.
        var new_filter = Utils.bitfield_from_filter (Pk.Filter.NEWEST);
        // Show apps with .desktop file.
        var app_filter = Utils.bitfield_from_filter (Pk.Filter.APPLICATION);
        // Only show for the current architecture.
        var arch_filter = Utils.bitfield_from_filter (Pk.Filter.ARCH);
        // Show only the main package (ex: 0ad and not 0ad-data).
        var base_filter = Utils.bitfield_from_filter (Pk.Filter.BASENAME);
        var apps = yield client.get_applications (dev_filter|new_filter|app_filter|arch_filter|base_filter, category.group, null);
        foreach (var app in apps) {
            app_list_view.add_package (app);
        }

        app_list_view.package_addition_finished ();
    }
}
