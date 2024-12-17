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

    class construct {
        set_css_name ("release");
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        spacing = 6;
        margin_bottom = 6;

        create_header ();
        create_description ();
        create_issues ();
    }

    private void create_header () {
        var header_icon = new Gtk.Image.from_icon_name ("tag-symbolic");
        var header_label = new Gtk.Label (format_version (release.get_version ())) {
            use_markup = true
        };
        header_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var date_label = new Gtk.Label (format_date (release.get_timestamp ())) {
            halign = Gtk.Align.START,
            hexpand = true
        };
        date_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var header_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            margin_bottom = 6
        };
        header_grid.attach (header_icon, 0, 0);
        header_grid.attach (header_label, 1, 0);
        header_grid.attach (date_label, 2, 0);

        append (header_grid);
    }

    private void create_description () {
        var description_label = new Gtk.Label (format_release_description (release.get_description ())) {
            selectable = true,
            use_markup = true,
            max_width_chars = 55,
            wrap = true,
            xalign = 0,
        };
        description_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var description_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            margin_bottom = 6
        };
        description_grid.attach (description_label, 0, 0);

        append (description_grid);
    }

    private void create_issues () {
        var issues = release.get_issues ();
        if (issues.length > 0) {
            var issue_header = new Gtk.Label (_("Fixed Issues")) {
                halign = Gtk.Align.START,
                margin_top = 9
            };
            issue_header.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

            append (issue_header);
        }

        foreach (unowned AppStream.Issue issue in issues) {
            var issue_image = new Gtk.Image.from_icon_name ("bug-symbolic") {
                valign = Gtk.Align.BASELINE_CENTER
            };

            var issue_label = new Gtk.Label (issue.get_id ()) {
                max_width_chars = 35,
                wrap = true,
                xalign = 0
            };

            var issue_linkbutton = new Gtk.LinkButton (issue.get_url ());
            issue_linkbutton.get_child ().destroy ();
            issue_linkbutton.child = issue_label;

            var issue_box = new Gtk.Grid ();
            issue_box.attach (issue_image, 0, 0);
            issue_box.attach (issue_linkbutton, 1, 0);

            append (issue_box);
        }
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

    private string format_release_description (string? description ) {
        if (description != null) {
            try {
                var markup = AppStream.markup_convert (description, TEXT);
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
