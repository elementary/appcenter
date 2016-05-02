// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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
        background-image: url("resource:///org/pantheon/appcenter/backgrounds/audio.svg"),
                          linear-gradient(to bottom,
                                  #FC8F36,
                                  #EF6522
                                  );
        background-position: center center;
        background-repeat: no-repeat;
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
    .category.graphics {
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.10),
                    inset 0 1px 0 0 alpha (#fff, 0.90),
                    inset 0 -1px 0 0 alpha (#fff, 0.30),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        color: #fe5498;
    }
    .category.games {
        background-image: linear-gradient(to bottom,
                                  #374044,
                                  #374044
                                  );
        border-color: alpha (#1B2022, 0.8);
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.25),
                    inset 0 -1px 0 0 alpha (#fff, 0.10),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        text-shadow: 0 1px 2px alpha (#000, 0.3);
        icon-shadow: 0 1px 2px alpha (#000, 0.3);
        color: #fff;
    }
    .category.education {
        background-image: linear-gradient(to bottom,
                                  #2F674D,
                                  #305A46
                                  );
        border-color: alpha (#213D30, 0.8);
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.25),
                    inset 0 -1px 0 0 alpha (#fff, 0.10),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        text-shadow: 0 1px 2px alpha (#000, 0.3);
        icon-shadow: 0 1px 2px alpha (#000, 0.3);
        font-family: Operating Instructions;
        font-size: 40px;
        color: #fff;
    }
    .category.internet {
        background-image: linear-gradient(to bottom,
                                  #48BCEA,
                                  #3DA4E8
                                  );
        border-color: alpha (#2980D1, 0.8);
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.25),
                    inset 0 -1px 0 0 alpha (#fff, 0.10),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        text-shadow: 0 1px 2px alpha (#000, 0.3);
        icon-shadow: 0 1px 2px alpha (#000, 0.3);
        color: #fff;
    }
    .category.science {
        background-image: url("resource:///org/pantheon/appcenter/backgrounds/science.svg"),
                          linear-gradient(to bottom,
                                  #374044,
                                  #374044
                                  );
        background-position: center center;
        background-repeat: no-repeat;
        border-color: alpha (#1B2022, 0.8);
        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.25),
                    inset 0 -1px 0 0 alpha (#fff, 0.10),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        text-shadow: 0 1px 2px alpha (#000, 0.3);
        icon-shadow: 0 1px 2px alpha (#000, 0.3);
        font-family: Limelight;
        color: #fff;
    }
    .category.accessibility {
        background-image: linear-gradient(to bottom,
                                  #3CA3E8,
                                  #368AE6
                                  );
        border-color: alpha (#2980D1, 0.8);
        color: #fff8ef;
        icon-shadow: 0 1px 1px alpha (#6c1900, 0.5),
                     0 2px 3px alpha (#6c1900, 0.5);
        text-shadow: 0 1px 1px alpha (#6c1900, 0.5),
                     0 2px 3px alpha (#6c1900, 0.5);
    }
""";

public class AppCenter.Widgets.CategoryItem : Gtk.FlowBoxChild {
    public AppStream.Category app_category;
    private Gtk.Grid grid;
    private Gtk.Image display_image;
    private Gtk.Label name_label;

    public CategoryItem (AppStream.Category app_category) {
        this.app_category = app_category;
        name_label.label = app_category.name;
        tooltip_text = app_category.summary ?? "";
        if (app_category.icon != null) {
            display_image.icon_name = app_category.icon;
            ((Gtk.Misc) name_label).xalign = 0;
            name_label.halign = Gtk.Align.START;
        } else {
            display_image.destroy ();
            name_label.justify = Gtk.Justification.CENTER;
        }

        show_all ();
    }

    static construct {
        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CATEGORIES_STYLE_CSS, CATEGORIES_STYLE_CSS.length);
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }
    }

    construct {
        grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.HORIZONTAL;
        grid.column_spacing = 6;
        grid.halign = Gtk.Align.CENTER;
        grid.valign = Gtk.Align.CENTER;

        display_image = new Gtk.Image ();
        display_image.icon_size = Gtk.IconSize.DIALOG;
        display_image.valign = Gtk.Align.CENTER;
        display_image.halign = Gtk.Align.END;
        grid.add (display_image);

        name_label = new Gtk.Label (null);
        name_label.wrap = true;
        grid.add (name_label);

        child = grid;
        get_style_context ().add_class ("category");
    }

    public override bool draw (Cairo.Context cr) {
        base.draw (cr);
        
        return false;
    }
}
