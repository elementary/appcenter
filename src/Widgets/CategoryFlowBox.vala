// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
  * Copyright (c) 2014-2018 elementary, Inc. (https://elementary.io)
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
    construct {
        activate_on_single_click = true;
        homogeneous = true;
        margin_bottom = 12;

        var games_card = new GamesCard ();

        add (new LegacyCard (_("Accessories"), "applications-accessories", {"Utility"}, "accessories"));
        add (new LegacyCard (_("Audio"), "applications-audio-symbolic", {"Audio", "Music"}, "audio"));
        add (new LegacyCard (_("Communication"), "", {
            "Chat",
            "ContactManagement",
            "Email",
            "InstantMessaging",
            "IRCClient",
            "Telephony",
            "VideoConference"
        }, "communication"));
        add (new LegacyCard (_("Development"), "", {
            "Database",
            "Debugger",
            "Development",
            "GUIDesigner",
            "IDE",
            "RevisionControl",
            "TerminalEmulator",
            "WebDevelopment"
        }, "development"));
        add (new LegacyCard (_("Education"), "", {"Education"}, "education"));
        add (new LegacyCard (_("Finance"), "payment-card-symbolic", {
            "Economy",
            "Finance"
        }, "finance"));
        add (games_card);
        add (new LegacyCard (_("Graphics"), "", {
            "2DGraphics",
            "3DGraphics",
            "Graphics",
            "ImageProcessing",
            "Photography",
            "RasterGraphics",
            "VectorGraphics"
        }, "graphics"));
        add (new LegacyCard (_("Internet"), "applications-internet", {
            "Network",
            "P2P"
        }, "internet"));
        add (new LegacyCard (_("Math, Science, & Engineering"), "", {
            "ArtificialIntelligence",
            "Astronomy",
            "Biology",
            "Calculator",
            "Chemistry",
            "ComputerScience",
            "DataVisualization",
            "Electricity",
            "Electronics",
            "Engineering",
            "Geology",
            "Geoscience",
            "Math",
            "NumericalAnalysis",
            "Physics",
            "Robotics",
            "Science"
        }, "science"));
        add (new LegacyCard (_("Media Production"), "applications-multimedia-symbolic", {
            "AudioVideoEditing",
            "Midi",
            "Mixer",
            "Recorder",
            "Sequencer"
        }, "media-production"));
        add (new LegacyCard (_("Office"), "applications-office-symbolic", {
            "Office",
            "Presentation",
            "Publishing",
            "Spreadsheet",
            "WordProcessor"
        }, "office"));
        add (new LegacyCard (_("System"), "applications-system-symbolic", {
            "Monitor",
            "System"
        }, "system"));
        add (new LegacyCard (_("Universal Access"), "applications-accessibility-symbolic", {"Accessibility"}, "accessibility"));
        add (new LegacyCard (_("Video"), "applications-video-symbolic", {
            "Tuner",
            "TV",
            "Video"
        }, "video"));
        add (new LegacyCard (_("Writing & Language"), "preferences-desktop-locale", {
            "Dictionary",
            "Languages",
            "Literature",
            "OCR",
            "TextEditor",
            "TextTools",
            "Translation",
            "WordProcessor"
        }, "writing-language"));
        add (new LegacyCard (_("Privacy & Security"), "preferences-system-privacy", {
            "Security",
        }, "privacy-security"));

        set_sort_func ((child1, child2) => {
            var item1 = (AbstractCategoryCard) child1;
            var item2 = (AbstractCategoryCard) child2;
            if (item1 != null && item2 != null) {
                return item1.category.name.collate (item2.category.name);
            }

            return 0;
        });
    }

    public abstract class AbstractCategoryCard : Gtk.FlowBoxChild {
        public AppStream.Category category { get; protected set; }

        protected Gtk.Grid content_area;
        protected unowned Gtk.StyleContext style_context;

        protected static Gtk.CssProvider category_provider;

        static construct {
            category_provider = new Gtk.CssProvider ();
            category_provider.load_from_resource ("io/elementary/appcenter/categories.css");
        }

        construct {
            var expanded_grid = new Gtk.Grid () {
                hexpand = true,
                vexpand = true,
                margin_top = 12,
                margin_end = 12,
                margin_bottom = 12,
                margin_start = 12
            };

            content_area = new Gtk.Grid () {
                margin_top = 12,
                margin_end = 12,
                margin_bottom = 12,
                margin_start = 12
            };
            content_area.add (expanded_grid);

            style_context = content_area.get_style_context ();
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class (Granite.STYLE_CLASS_ROUNDED);
            style_context.add_class ("category");
            style_context.add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            child = content_area;
        }
    }

    private class LegacyCard : AbstractCategoryCard {
        public LegacyCard (string name, string icon, string[] groups, string style) {
            category = new AppStream.Category ();
            category.set_name (name);
            category.set_icon (icon);

            foreach (var group in groups) {
                category.add_desktop_group (group);
            }

            var display_image = new Gtk.Image ();
            display_image.icon_size = Gtk.IconSize.DIALOG;
            display_image.valign = Gtk.Align.CENTER;
            display_image.halign = Gtk.Align.END;

            var name_label = new Gtk.Label (null);
            name_label.wrap = true;
            name_label.max_width_chars = 15;
            name_label.get_style_context ().add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                margin_top = 32,
                margin_end = 16,
                margin_bottom = 32,
                margin_start = 16
            };
            box.add (display_image);
            box.add (name_label);

            content_area.attach (box, 0, 0);

            if (category.icon != "") {
                display_image.icon_name = category.icon;
                name_label.xalign = 0;
                name_label.halign = Gtk.Align.START;
            } else {
                display_image.destroy ();
                name_label.justify = Gtk.Justification.CENTER;
            }

            style_context.add_class (style);

            if (style == "accessibility") {
                name_label.label = category.name.up ();
            } else {
                name_label.label = category.name;
            }

            if (style == "science") {
                name_label.justify = Gtk.Justification.CENTER;
            }
        }
    }

    private class GamesCard : AbstractCategoryCard {
        construct {
            category = new AppStream.Category () {
                name = _("Fun & Games"),
                icon = "applications-games-symbolic"
            };
            category.add_desktop_group ("ActionGame");
            category.add_desktop_group ("AdventureGame");
            category.add_desktop_group ("Amusement");
            category.add_desktop_group ("ArcadeGame");
            category.add_desktop_group ("BlocksGame");
            category.add_desktop_group ("BoardGame");
            category.add_desktop_group ("CardGame");
            category.add_desktop_group ("Game");
            category.add_desktop_group ("KidsGame");
            category.add_desktop_group ("LogicGame");
            category.add_desktop_group ("RolePlaying");
            category.add_desktop_group ("Shooter");
            category.add_desktop_group ("Simulation");
            category.add_desktop_group ("SportsGame");
            category.add_desktop_group ("StrategyGame");

            var image = new Gtk.Image () {
                icon_name = "applications-games-symbolic",
                pixel_size = 64
            };

            unowned var image_context = image.get_style_context ();
            image_context.add_class (Granite.STYLE_CLASS_ACCENT);
            image_context.add_class ("slate");

            var fun_label = new Gtk.Label (_("Fun &")) {
                halign = Gtk.Align.START
            };

            unowned var fun_label_context = fun_label.get_style_context ();
            fun_label_context.add_class (Granite.STYLE_CLASS_ACCENT);
            fun_label_context.add_class ("pink");
            fun_label_context.add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var games_label = new Gtk.Label (_("Games"));

            unowned var games_label_context = games_label.get_style_context ();
            games_label_context.add_class (Granite.STYLE_CLASS_ACCENT);
            games_label_context.add_class ("blue");
            games_label_context.add_provider (category_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var grid = new Gtk.Grid () {
                column_spacing = 12,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            grid.attach (image, 0, 0, 1, 2);
            grid.attach (fun_label, 1, 0);
            grid.attach (games_label, 1, 1);

            content_area.attach (grid, 0, 0);

            style_context.add_class ("games");
        }
    }
}
