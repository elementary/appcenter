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
* Authored by: Corentin Noël <corentin@elementaryos.org>
*/

public class AppCenter.Widgets.CategoryFlowBox : Gtk.FlowBox {
    public CategoryFlowBox () {
        Object (activate_on_single_click: true,
                homogeneous: true,
                min_children_per_line: 2);
    }

    construct {
        add (get_audio_category ());
        add (get_development_category ());
        add (get_accessories_category ());
        add (get_office_category ());
        add (get_system_category ());
        add (get_video_category ());
        add (get_graphics_category ());
        add (get_games_category ());
        add (get_education_category ());
        add (get_internet_category ());
        add (get_science_category ());
        add (get_a11y_category ());
    }

    private Widgets.CategoryItem get_audio_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Audio"));
        category.set_icon ("applications-audio-symbolic");
        category.add_desktop_group ("Audio");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("audio");

        return item;
    }

    private Widgets.CategoryItem get_development_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Development"));
        category.add_desktop_group ("Development");
        category.add_desktop_group ("IDE");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("development");

        return item;
    }

    private Widgets.CategoryItem get_accessories_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Accessories"));
        category.set_icon ("applications-accessories");
        category.add_desktop_group ("Utility");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("accessories");

        return item;
    }

    private Widgets.CategoryItem get_office_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Office"));
        category.set_icon ("applications-office-symbolic");
        category.add_desktop_group ("Office");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("office");

        return item;
    }

    private Widgets.CategoryItem get_system_category () {
        var category = new AppStream.Category ();
        category.set_name (_("System"));
        category.set_icon ("applications-system");
        category.add_desktop_group ("System");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("system");

        return item;
    }

    private Widgets.CategoryItem get_video_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Video"));
        category.set_icon ("applications-video-symbolic");
        category.add_desktop_group ("Video");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("video");

        return item;
    }

    private Widgets.CategoryItem get_graphics_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Graphics"));
        category.add_desktop_group ("Graphics");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("graphics");

        return item;
    }

    private Widgets.CategoryItem get_games_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Games"));
        category.add_desktop_group ("Game");
        category.set_icon ("applications-games-symbolic");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("games");

        return item;
    }

    private Widgets.CategoryItem get_education_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Education"));
        category.add_desktop_group ("Education");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("education");

        return item;
    }

    private Widgets.CategoryItem get_internet_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Internet"));
        category.set_icon ("applications-internet");
        category.add_desktop_group ("Network");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("internet");

        return item;
    }

    private Widgets.CategoryItem get_science_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Science & Engineering"));
        category.add_desktop_group ("Science");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("science");

        return item;
    }

    private Widgets.CategoryItem get_a11y_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Universal Access"));
        category.set_icon ("applications-accessibility-symbolic");
        category.add_desktop_group ("Accessibility");
        var item = new Widgets.CategoryItem (category);
        item.add_category_class ("accessibility");

        return item;
    }
}
