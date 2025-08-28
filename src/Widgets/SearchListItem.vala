/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.SearchListItem : Gtk.Grid {
    private const int SCREENSHOT_HEIGHT = 180;

    public AppCenterCore.Package package {
        set {
            app_icon.package = value;
            name_label.label = value.name;
            summary_label.label = value.get_summary ();

            if (action_stack != null) {
                remove (action_stack);
            }

            action_stack = new ActionStack (value) {
                halign = END
            };
            attach (action_stack, 2, 0, 1, 2);

            load_screenshot (value);
        }
    }

    private static AppCenterCore.ScreenshotCache? screenshot_cache;

    private AppCenter.ActionStack action_stack;
    private AppCenter.AppIcon app_icon;
    private Gtk.Label name_label;
    private Gtk.Label summary_label;
    private AppCenter.Screenshot screenshot_picture;

    static construct {
        screenshot_cache = new AppCenterCore.ScreenshotCache ();
    }

    class construct {
        set_css_name ("search-list-item");
    }

    construct {
        app_icon = new AppIcon (48);

        name_label = new Gtk.Label (null) {
            valign = END,
            wrap = true,
            xalign = 0
        };
        name_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        summary_label = new Gtk.Label (null) {
            ellipsize = END,
            hexpand = true,
            lines = 2,
            valign = START,
            wrap = true,
            xalign = 0
        };
        summary_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        summary_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        screenshot_picture = new AppCenter.Screenshot () {
            height_request = 180,
        };

        attach (app_icon, 0, 0, 1, 2);
        attach (name_label, 1, 0);
        attach (summary_label, 1, 1);
        attach (screenshot_picture, 0, 2, 3);
    }

    private void load_screenshot (AppCenterCore.Package package) {
        screenshot_picture.visible = false;

        screenshot_picture.set_branding (package);

        string? screenshot_url = null;

        var screenshots = package.get_screenshots ();
        foreach (unowned var screenshot in screenshots) {
            screenshot_url = screenshot.get_image (-1, SCREENSHOT_HEIGHT, scale_factor).get_url ();
            screenshot_picture.tooltip_text = screenshot.get_caption ();

            if (screenshot.get_kind () == DEFAULT && screenshot_url != null) {
                break;
            }
        }

        if (screenshot_url == null) {
            return;
        }

        screenshot_cache.fetch.begin (screenshot_url, (obj, res) => {
            string? screenshot_path = null;
            var fetched = screenshot_cache.fetch.end (res, out screenshot_path);

            if (!fetched || screenshot_path == null) {
                return;
            }

            screenshot_picture.path = screenshot_path;
            screenshot_picture.visible = true;
        });
    }
}
