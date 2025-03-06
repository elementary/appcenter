/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 */

public class AppCenter.CategoryManager : Object {
    public GenericArray<AppStream.Category> categories { get; private set; }

    private static GLib.Once<CategoryManager> instance;
    public static unowned CategoryManager get_default () {
        return instance.once (() => { return new CategoryManager (); });
    }

    private CategoryManager () {}

    construct {
        categories = new GenericArray<AppStream.Category> ();

        append ("accessories", _("Accessories"), "applications-accessories", {"Utility"});
        append ("audio", _("Audio"), "appcenter-audio", {"Audio", "Music"});

        // FIXME: This is an app icon, not a category icon
        append ("communication", _("Communication"), "internet-chat", {
            "Chat",
            "ContactManagement",
            "Email",
            "InstantMessaging",
            "IRCClient",
            "Telephony",
            "VideoConference"
        });

        append ("development", _("Development"), "applications-development", {
            "Database",
            "Debugger",
            "Development",
            "GUIDesigner",
            "IDE",
            "RevisionControl",
            "TerminalEmulator",
            "WebDevelopment"
        });

        // FIXME: Icon missing
        append ("education", _("Education"), "", {"Education"});

        append ("finance", _("Finance"), "appcenter-finance", {
            "Economy",
            "Finance"
        });

        append ("games", _("Fun & Games"), "applications-games", {
            "ActionGame",
            "AdventureGame",
            "Amusement",
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
        });

        append ("graphics", _("Graphics"), "applications-graphics", {
            "2DGraphics",
            "3DGraphics",
            "Graphics",
            "ImageProcessing",
            "Photography",
            "RasterGraphics",
            "VectorGraphics"
        });

        append ("internet", _("Internet"), "applications-internet", {
            "Network",
            "P2P"
        });

        append ("science", _("Math, Science, & Engineering"), "applications-science", {
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
        });

        append ("media-production", _("Media Production"), "applications-multimedia", {
            "AudioVideoEditing",
            "Midi",
            "Mixer",
            "Recorder",
            "Sequencer"
        });

        append ("office", _("Office"), "applications-office", {
            "Office",
            "Presentation",
            "Publishing",
            "Spreadsheet",
            "WordProcessor"
        });

        append ("system", _("System"), "applications-system", {
            "Monitor",
            "System"
        });

        append ("accessibility", _("Universal Access"), "preferences-desktop-accessibility", {"Accessibility"});

        append ("video", _("Video"), "appcenter-video", {
            "Tuner",
            "TV",
            "Video"
        });

        append ("writing-language", _("Writing & Language"), "preferences-desktop-locale", {
            "Dictionary",
            "Languages",
            "Literature",
            "OCR",
            "TextEditor",
            "TextTools",
            "Translation",
            "WordProcessor"
        });

        // FIXME: MISSING ICON
        append ("privacy-security", _("Privacy & Security"), "preferences-system-privacy", {
            "Security"
        });
    }

    private void append (string id, string name, string icon, string[] groups) {
        var category = new AppStream.Category () {
            name = name,
            icon = icon,
            id = id
        };

        foreach (unowned var group in groups) {
            category.add_desktop_group (group);
        }

        categories.add (category);
    }
}
