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
        add (get_category (_("Accessories"), "applications-accessories", {"Utility"}, "accessories"));
        add (get_category (_("Audio"), "applications-audio-symbolic", {"Audio", "Music"}, "audio"));
        add (get_category (_("Communication"), "internet-chat", {"Chat", "InstantMessaging", "IRCClient", "VideoConference", "Email", "Telephony", "ContactManagement"}, "communication"));
        add (get_category (_("Development"), "", {"IDE", "Development", "Debugger", "WebDevelopment", "TerminalEmulator", "RevisionControl", "GUIDesigner", "Database"}, "development"));
        add (get_category (_("Education"), "", {"Education"}, "education"));
        add (get_category (_("Games"), "applications-games-symbolic", {"Game", "ActionGame", "AdventureGame", "ArcadeGame", "BlocksGame", "BoardGame", "CardGame", "KidsGame", "LogicGame", "RolePlaying", "Shooter", "Simulation", "SportsGame", "StrategyGame"}, "games"));
        add (get_category (_("Graphics"), "", {"Graphics", "Photography", "3DGraphics", "2DGraphics", "RasterGraphics", "VectorGraphics", "ImageProcessing"}, "graphics"));
        add (get_category (_("Internet"), "applications-internet", {"Network", "P2P"}, "internet"));
        add (get_category (_("Math, Science, & Engineering"), "", {"Science", "Chemistry", "Astronomy", "Electricity", "Math", "Biology", "DataVisualization", "Calculator", "ComputerScience", "Engineering", "Physics", "NumericalAnalysis", "Geology", "Geoscience", "Electronics", "ArtificialIntelligence", "Robotics"}, "science"));
        add (get_category (_("Media Production"), "applications-multimedia", {"AudioVideoEditing", "Recorder", "Midi", "Mixer", "Sequencer"}, "media-production"));
        add (get_category (_("News & Feeds"), "internet-news-reader", {"News", "Feed"}, "news"));
        add (get_category (_("Office"), "applications-office-symbolic", {"Office", "Publishing", "WordProcessor", "Presentation", "Spreadsheet"}, "office"));
        add (get_category (_("System"), "applications-system", {"System", "Monitor"}, "system"));
        add (get_category (_("To-Do & Projects"), "office-calender", {"ProjectManagement", "Calendar"}, "todo"));
        add (get_category (_("Video"), "applications-video-symbolic", {"Video", "TV", "Tuner"}, "video"));
        add (get_category (_("Writing & Language"), "preferences-desktop-locale", {"TextTools", "TextEditor", "Dictionary", "Languages", "Literature", "Translation", "OCR", "WordProcessor"}, "language"));
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
