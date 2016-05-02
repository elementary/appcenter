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


const string CATEGORIES_STYLE_CSS = """
    .category {
        background-image: linear-gradient(to bottom,
                                  #fafafa,
                                  #f2f2f2
                                  );
        border: 1px solid alpha (#000, 0.15);
        border-radius: 3px;

        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.45),
                    inset 0 -1px 0 0 alpha (#fff, 0.15),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        color: #4d4d4d;
        font-size: 32px;
        font-weight: 300;
        padding: 42px 16px;
    }
    .category.audio {
        background-image: linear-gradient(to bottom,
                                  #FC8F36,
                                  #EF6522
                                  );
        border-color: alpha (#a25812, 0.8);
        color: #fff8ef;
        icon-shadow: 0 1px 1px alpha (#6c1900, 0.5),
                     0 2px 3px alpha (#6c1900, 0.5);
        text-shadow: 0 1px 1px alpha (#6c1900, 0.5),
                     0 2px 3px alpha (#6c1900, 0.5);
    }
    .category.development {
        background-image: linear-gradient(to bottom,
                                  #816fa9,
                                  #6a5c8e
                                  );
        border-color: alpha (#352d48, 0.8);
        font-family: lobster;
        text-shadow: 0 2px 0 alpha (#000, 0.3);
        color: #fff;
    }
    .category.accessories {
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.10),
                    inset 0 1px 0 0 alpha (#fff, 0.90),
                    inset 0 -1px 0 0 alpha (#fff, 0.30),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        font-size: 24px;
    }
    .category.office {
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.10),
                    inset 0 1px 0 0 alpha (#fff, 0.90),
                    inset 0 -1px 0 0 alpha (#fff, 0.30),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        color: #ff750c;
    }
    .category.system {
        background-image: linear-gradient(to bottom,
                                  #69768f,
                                  #59687e
                                  );
        border-color: alpha (#454951, 0.8);
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.25),
                    inset 0 -1px 0 0 alpha (#fff, 0.10),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        color: white;
        text-shadow: 0 1px 1px alpha (#000, 0.3),
                     0 2px 3px alpha (#000, 0.3);
    }
    .category.video {
        background-image: linear-gradient(to bottom,
                                  #dd5248,
                                  #c92b31
                                  );
        border-color: alpha (#8c201d, 0.8);
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.25),
                    inset 0 -1px 0 0 alpha (#fff, 0.10),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        text-shadow: 0 1px 2px alpha (#000, 0.3);
        icon-shadow: 0 1px 2px alpha (#000, 0.3);
        color: #fff;
    }
""";

namespace AppCenter {
    public static Gee.TreeSet<Widgets.CategoryItem> get_app_categories () {
        var items = new Gee.TreeSet<Widgets.CategoryItem> ();
        items.add (get_audio_category ());
        items.add (get_development_category ());
        items.add (get_accessories_category ());
        items.add (get_office_category ());
        items.add (get_system_category ());
        items.add (get_video_category ());
        return items;
    }
    
    public static Widgets.CategoryItem get_audio_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Audio"));
        category.set_icon ("applications-audio-symbolic");
        category.get_included ().append ("Audio");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("category");
        item.get_style_context ().add_class ("audio");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            var context = item.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        return item;
    }

    public static Widgets.CategoryItem get_development_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Development"));
        category.get_included ().append ("Development");
        category.get_included ().append ("IDE");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("category");
        item.get_style_context ().add_class ("development");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            var context = item.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        return item;
    }

    public static Widgets.CategoryItem get_accessories_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Accessories"));
        category.set_icon ("applications-accessories");
        category.get_included ().append ("Utility");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("category");
        item.get_style_context ().add_class ("accessories");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            var context = item.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        return item;
    }

    public static Widgets.CategoryItem get_office_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Office"));
        category.set_icon ("applications-office-symbolic");
        category.get_included ().append ("Office");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("category");
        item.get_style_context ().add_class ("office");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            var context = item.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        return item;
    }

    public static Widgets.CategoryItem get_system_category () {
        var category = new AppStream.Category ();
        category.set_name (_("System"));
        category.set_icon ("applications-system");
        category.get_included ().append ("System");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("category");
        item.get_style_context ().add_class ("system");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            var context = item.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        return item;
    }

    public static Widgets.CategoryItem get_video_category () {
        var category = new AppStream.Category ();
        category.set_name (_("Video"));
        category.set_icon ("applications-video-symbolic");
        category.get_included ().append ("Video");
        var item = new Widgets.CategoryItem (category);
        item.get_style_context ().add_class ("category");
        item.get_style_context ().add_class ("video");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            var context = item.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }

        return item;
    }
}
