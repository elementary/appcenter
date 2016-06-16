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

public class AppCenter.Views.CategoryView : View {
    private Gtk.FlowBox category_flow;
    private Gtk.ScrolledWindow category_scrolled;
    private string current_category;

    public CategoryView () {
        
    }

    construct {
        category_flow = new Gtk.FlowBox ();
        category_flow.margin = 12;
        category_flow.homogeneous = true;
        category_flow.halign = Gtk.Align.CENTER;
        category_flow.valign = Gtk.Align.CENTER;
        category_flow.min_children_per_line = 2;
        category_flow.activate_on_single_click = true;
        get_app_categories ();

        category_flow.child_activated.connect ((child) => {
            var item = child as Widgets.CategoryItem;
            if (item != null) {
                show_app_list_for_category (item.app_category);
            }
        });

        category_flow.set_sort_func ((child1, child2) => {
            var item1 = child1 as Widgets.CategoryItem;
            var item2 = child2 as Widgets.CategoryItem;
            if (item1 != null && item2 != null) {
                return item1.app_category.name.collate (item2.app_category.name);
            }

            return 0;
        });

        category_scrolled = new Gtk.ScrolledWindow (null, null);
        category_scrolled.add (category_flow);
        add (category_scrolled);
    }

    public override void return_clicked () {
        if (current_category == null) {
            set_visible_child (category_scrolled);
        } else {
            subview_entered (_("Categories"));
            set_visible_child_name (current_category);
            current_category = null;
        }
    }

    private void show_app_list_for_category (AppStream.Category category) {
        subview_entered (_("Categories"));
        var child = get_child_by_name (category.name);
        if (child != null) {
            set_visible_child (child);
            return;
        }

        var app_list_view = new Views.AppListView ();
        app_list_view.show_all ();
        add_named (app_list_view, category.name);
        set_visible_child (app_list_view);

        app_list_view.show_app.connect ((package) => {
            subview_entered (category.name);
            current_category = category.name;
            show_package (package);
        });

        unowned Client client = Client.get_default ();
        var apps = client.get_applications_for_category (category);
        foreach (var app in apps) {
            app_list_view.add_package (app);
        }

    }

    private void get_app_categories () {
        category_flow.add (get_audio_category ());
        category_flow.add (get_development_category ());
        category_flow.add (get_accessories_category ());
        category_flow.add (get_office_category ());
        category_flow.add (get_system_category ());
        category_flow.add (get_video_category ());
        category_flow.add (get_graphics_category ());
        category_flow.add (get_games_category ());
        category_flow.add (get_education_category ());
        category_flow.add (get_internet_category ());
        category_flow.add (get_science_category ());
        category_flow.add (get_a11y_category ());
    }

    private Widgets.CategoryItem get_audio_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Audio"));
        category.set_icon ("applications-audio-symbolic");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Audio");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("audio");

        return item;
    }

    private Widgets.CategoryItem get_development_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Development"));
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Development");
        categories.add ("IDE");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("development");

        return item;
    }

    private Widgets.CategoryItem get_accessories_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Accessories"));
        category.set_icon ("applications-accessories");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Utility");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("accessories");

        return item;
    }

    private Widgets.CategoryItem get_office_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Office"));
        category.set_icon ("applications-office-symbolic");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Office");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("office");

        return item;
    }

    private Widgets.CategoryItem get_system_category () {
        var category = new AppStream.Category ();
        category.set_name (_("System"));
        category.set_icon ("applications-system");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("System");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("system");

        return item;
    }

    private Widgets.CategoryItem get_video_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Video"));
        category.set_icon ("applications-video-symbolic");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Video");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("video");

        return item;
    }

    private Widgets.CategoryItem get_graphics_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Graphics"));
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Graphics");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("graphics");

        return item;
    }

    private Widgets.CategoryItem get_games_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Games"));
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Game");
        category.set_data<Gee.LinkedList> ("categories", categories);
        category.set_icon ("applications-games-symbolic");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("games");

        return item;
    }

    private Widgets.CategoryItem get_education_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Education"));
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Education");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("education");

        return item;
    }

    private Widgets.CategoryItem get_internet_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Internet"));
        category.set_icon ("applications-internet");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Network");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("internet");

        return item;
    }

    private Widgets.CategoryItem get_science_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Science & Engineering"));
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Science");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("science");

        return item;
    }

    private Widgets.CategoryItem get_a11y_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Universal Access"));
        category.set_icon ("applications-accessibility-symbolic");
        var categories = new Gee.LinkedList<string> ();
        categories.add ("Accessibility");
        category.set_data<Gee.LinkedList> ("categories", categories);
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("accessibility");

        return item;
    }
}
