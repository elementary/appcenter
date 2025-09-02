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

        append ("communication", _("Communication"), "", {
            "Chat",
            "ContactManagement",
            "Email",
            "InstantMessaging",
            "IRCClient",
            "Telephony",
            "VideoConference"
        });

        append ("development", _("Development"), "", {
            "Database",
            "Debugger",
            "Development",
            "GUIDesigner",
            "IDE",
            "RevisionControl",
            "TerminalEmulator",
            "WebDevelopment"
        });

        append ("education", _("Education"), "applications-education-symbolic", {"Education"});

        append ("finance", _("Finance"), "appcenter-finance", {
            "Economy",
            "Finance"
        });

        append ("games", _("Fun & Games"), "appcenter-games-symbolic", {
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

        append ("graphics", _("Graphics"), "", {
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

        append ("science", _("Math, Science, & Engineering"), "", {
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

        append ("media-production", _("Media Production"), "appcenter-multimedia-symbolic", {
            "AudioVideoEditing",
            "Midi",
            "Mixer",
            "Recorder",
            "Sequencer"
        });

        append ("office", _("Office"), "appcenter-office-symbolic", {
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

        append ("accessibility", _("Universal Access"), "appcenter-accessibility-symbolic", {"Accessibility"});

        append ("video", _("Video"), "appcenter-video-symbolic", {
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
