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


namespace AppCenter {
    public static Gee.TreeSet<Widgets.CategoryItem> get_app_categories () {
        var items = new Gee.TreeSet<Widgets.CategoryItem> ();
        items.add (get_audio_category ());
        items.add (get_development_category ());
        items.add (get_accessories_category ());
        items.add (get_office_category ());
        items.add (get_system_category ());
        items.add (get_video_category ());
        items.add (get_graphics_category ());
        items.add (get_games_category ());
        items.add (get_education_category ());
        items.add (get_internet_category ());
        items.add (get_science_category ());
        items.add (get_a11y_category ());
        return items;
    }
    
    public static Widgets.CategoryItem get_audio_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Audio"));
        category.set_icon ("applications-audio-symbolic");
        category.get_included ().append ("Audio");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("audio");

        return item;
    }

    public static Widgets.CategoryItem get_development_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Development"));
        category.get_included ().append ("Development");
        category.get_included ().append ("IDE");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("development");

        return item;
    }

    public static Widgets.CategoryItem get_accessories_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Accessories"));
        category.set_icon ("applications-accessories");
        category.get_included ().append ("Utility");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("accessories");

        return item;
    }

    public static Widgets.CategoryItem get_office_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Office"));
        category.set_icon ("applications-office-symbolic");
        category.get_included ().append ("Office");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("office");

        return item;
    }

    public static Widgets.CategoryItem get_system_category () {
        var category = new AppStream.Category ();
        category.set_name (_("System"));
        category.set_icon ("applications-system");
        category.get_included ().append ("System");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("system");

        return item;
    }

    public static Widgets.CategoryItem get_video_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Video"));
        category.set_icon ("applications-video-symbolic");
        category.get_included ().append ("Video");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("video");

        return item;
    }

    public static Widgets.CategoryItem get_graphics_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Graphics"));
        category.get_included ().append ("Graphics");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("graphics");

        return item;
    }

    public static Widgets.CategoryItem get_games_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Games"));
        category.get_included ().append ("Game");
        category.set_icon ("applications-games-symbolic");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("games");

        return item;
    }

    public static Widgets.CategoryItem get_education_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Education"));
        category.get_included ().append ("Education");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("education");

        return item;
    }

    public static Widgets.CategoryItem get_internet_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Internet"));
        category.set_icon ("applications-internet");
        category.get_included ().append ("Network");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("internet");

        return item;
    }

    public static Widgets.CategoryItem get_science_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Science & Engineering"));
        category.get_included ().append ("Science");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("science");

        return item;
    }

    public static Widgets.CategoryItem get_a11y_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Universal Access"));
        category.set_icon ("applications-accessibility-symbolic");
        category.get_included ().append ("Accessibility");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("accessibility");

        return item;
    }
}
