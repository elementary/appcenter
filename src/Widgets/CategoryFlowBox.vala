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
        min_children_per_line = 1;

        add (get_category (_("Accessories"), "applications-accessories", {"Utility"}, "accessories"));
        add (get_category (_("Audio"), "applications-audio-symbolic", {"Audio", "Music"}, "audio"));
        add (get_category (_("Communication"), "", {
            "Chat",
            "ContactManagement",
            "Email",
            "InstantMessaging",
            "IRCClient",
            "Telephony",
            "VideoConference"
        }, "communication"));
        add (get_category (_("Development"), "", {
            "Database",
            "Debugger",
            "Development",
            "GUIDesigner",
            "IDE",
            "RevisionControl",
            "TerminalEmulator",
            "WebDevelopment"
        }, "development"));
        add (get_category (_("Education"), "", {"Education"}, "education"));
        add (get_category (_("Finance"), "payment-card-symbolic", {
            "Economy",
            "Finance"
        }, "finance"));
        add (get_category (_("Games"), "applications-games-symbolic", {
            "ActionGame",
            "AdventureGame",
            "ArcadeGame",
            "BlocksGame",
            "BoardGame",
            "CardGame",
            "Game",
            "KidsGame",
            "LogicGame",
            "RolePlaying",
            "Shooter",
            "Simulation",
            "SportsGame",
            "StrategyGame"
        }, "games"));
        add (get_category (_("Graphics"), "", {
            "2DGraphics",
            "3DGraphics",
            "Graphics",
            "ImageProcessing",
            "Photography",
            "RasterGraphics",
            "VectorGraphics"
        }, "graphics"));
        add (get_category (_("Internet"), "applications-internet", {
            "Network",
            "P2P"
        }, "internet"));
        add (get_category (_("Math, Science, & Engineering"), "", {
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
        add (get_category (_("Media Production"), "applications-multimedia-symbolic", {
            "AudioVideoEditing",
            "Midi",
            "Mixer",
            "Recorder",
            "Sequencer"
        }, "media-production"));
        add (get_category (_("Office"), "applications-office-symbolic", {
            "Office",
            "Presentation",
            "Publishing",
            "Spreadsheet",
            "WordProcessor"
        }, "office"));
        add (get_category (_("System"), "applications-system-symbolic", {
            "Monitor",
            "System"
        }, "system"));
        add (get_category (_("Universal Access"), "applications-accessibility-symbolic", {"Accessibility"}, "accessibility"));
        add (get_category (_("Video"), "applications-video-symbolic", {
            "Tuner",
            "TV",
            "Video"
        }, "video"));
        add (get_category (_("Writing & Language"), "preferences-desktop-locale", {
            "Dictionary",
            "Languages",
            "Literature",
            "OCR",
            "TextEditor",
            "TextTools",
            "Translation",
            "WordProcessor"
        }, "writing-language"));

        set_sort_func ((child1, child2) => {
            var item1 = child1 as Widgets.CategoryItem;
            var item2 = child2 as Widgets.CategoryItem;
            if (item1 != null && item2 != null) {
                return item1.app_category.name.collate (item2.app_category.name);
            }

            return 0;
        });
    }

    private Widgets.CategoryItem get_category (string name, string icon, string[] groups, string style) {
        var category = new AppStream.Category ();
        category.set_name (name);
        category.set_icon (icon);

        foreach (var group in groups) {
            category.add_desktop_group (group);
        }

        var item = new Widgets.CategoryItem (category);
        item.add_category_class (style);

        return item;
    }
}
