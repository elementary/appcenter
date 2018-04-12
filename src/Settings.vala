// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
* Copyright (c) 2012-2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Corentin Noël <corentin@elementary.io>
*/

public class AppCenter.Settings : Granite.Services.Settings {
    public enum WindowState {
        NORMAL,
        MAXIMIZED,
        FULLSCREEN
    }

    public int window_width { get; set; }
    public int window_height { get; set; }
    public WindowState window_state { get; set; }
    public int window_x { get; set; }
    public int window_y { get; set; }
    public bool developer_mode { get; set; }
    public bool reset_paid_apps { get; set; }
    public string[] paid_apps { get; set; }

    private static Settings main_settings;
    public static unowned Settings get_default () {
        if (main_settings == null)
            main_settings = new Settings ();
        return main_settings;
    }

    public void add_paid_app (string id) {
        if (!(id in paid_apps)) {
            var apps_copy = paid_apps;
            apps_copy += id;
            paid_apps = apps_copy;
        }
    }

    private Settings ()  {
        base ("io.elementary.appcenter.settings");
    }
}
