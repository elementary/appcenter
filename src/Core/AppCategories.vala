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
                                  shade (#FFFFFF, 1),
                                  shade (#f2f2f2, 1)
                                  );
        color: #4d4d4d;
        padding: 24px;
        font-size: 32px;
        font-family: open-sans;
        font-weight: lighter;
    }
    .category.audio {
        background-image: linear-gradient(to bottom,
                                  shade (#FC8F36, 1),
                                  shade (#EF6522, 1)
                                  );
        text-shadow: 0 0 3px alpha (black, 0.8);
        icon-shadow: 0 0 3px alpha (black, 0.6);
        color: white;
    }
    .category.development {
        background-image: linear-gradient(to bottom,
                                  shade (#7D6DA5, 1),
                                  shade (#7C709C, 1)
                                  );
        font-family: lobster;
        text-shadow: 0 0 3px alpha (black, 0.8);
        color: white;
    }
    .category.accessories {
        font-size: 24px;
    }
    .category.office {
        color: #ff750c;
    }
    .category.system {
        background-image: linear-gradient(to bottom,
                                  shade (#6B7891, 1),
                                  shade (#5A697F, 1)
                                  );
        color: white;
    }
    .category.video {
        background-image: linear-gradient(to bottom,
                                  shade (#D74742, 1),
                                  shade (#9A3731, 1)
                                  );
        text-shadow: 0 0 3px alpha (black, 0.8);
        icon-shadow: 0 0 3px alpha (black, 0.6);
        color: white;
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
