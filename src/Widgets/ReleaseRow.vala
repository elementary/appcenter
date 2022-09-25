/*-
 * Copyright 2017-2022 elementary, Inc. (https://elementary.io)
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
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class AppCenter.Widgets.ReleaseRow : Gtk.Box {
    public AppStream.Release release { get; construct; }

    public ReleaseRow (AppStream.Release release) {
        Object (release: release);
    }

    construct {
        var header_icon = new Gtk.Image.from_icon_name ("tag-symbolic", Gtk.IconSize.MENU);

        var header_label = new Gtk.Label (format_version (release.get_version ())) {
            use_markup = true
        };
        header_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var date_label = new Gtk.Label (format_date (release.get_timestamp ())) {
            halign = Gtk.Align.START,
            hexpand = true
        };
        date_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var description_label = new Gtk.Label (format_release_description (release.get_description ())) {
            selectable = true,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        description_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            margin_bottom = 6
        };
        grid.attach (header_icon, 0, 0);
        grid.attach (header_label, 1, 0);
        grid.attach (date_label, 2, 0);
        grid.attach (description_label, 0, 1, 3);

        add (grid);
    }

    private string format_date (uint64 timestamp) {
        if (timestamp != 0) {
            return Granite.DateTime.get_relative_datetime (new DateTime.from_unix_utc ((int64) timestamp));
        }

        return _("Unknown date");
    }

    private string format_version (string version) {
        if (version != null) {
            return "<b>%s</b>".printf (version);
        } else {
            return _("Unknown version");
        }
    }

    public static string format_release_description (string? description ) {
        if (description != null) {
            try {
                var markup = AppStream.markup_convert_simple (description);

                if (markup.strip () != "") {
                    return markup;
                }
            } catch (Error e) {
                warning (e.message);
            }
        }

        return _("No description available");
    }
}
