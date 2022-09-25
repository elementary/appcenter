/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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

public class AppCenter.Widgets.ReleaseRow : Gtk.ListBoxRow {
    public AppStream.Release release { get; construct; }

    private Gtk.Label header_label;
    private Gtk.Label description_label;

    public ReleaseRow (AppStream.Release release) {
        Object (release: release);
    }

    construct {
        string header = format_release_header (release, true);
        string description = format_release_description (release);

        header_label = new Gtk.Label (header);
        header_label.use_markup = true;
        header_label.xalign = 0;
        header_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        description_label = new Gtk.Label (description);
        description_label.max_width_chars = 100;
        description_label.selectable = true;
        description_label.use_markup = true;
        description_label.wrap = true;
        description_label.xalign = 0;
        description_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_bottom = 6
        };
        box.add (header_label);
        box.add (description_label);

        var issues = release.get_issues ();

        if (issues.length > 0) {
            var issue_header = new Gtk.Label (_("Fixed Issues")) {
                halign = Gtk.Align.START
            };
            issue_header.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            box.add (issue_header);
        }

        foreach (unowned AppStream.Issue issue in issues) {
            var issue_image = new Gtk.Image.from_icon_name ("bug-symbolic", Gtk.IconSize.MENU);

            var issue_linkbutton = new Gtk.LinkButton.with_label (issue.get_url (), issue.get_id ()) {
                xalign = 0
            };

            var issue_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
            issue_box.add (issue_image);
            issue_box.add (issue_linkbutton);

            box.add (issue_box);
        }

        add (box);
    }

    private static string format_release_header (AppStream.Release release, bool with_date) {
        string label;

        unowned string version = release.get_version ();

        uint64 timestamp = release.get_timestamp ();
        if (with_date && timestamp != 0) {
            var date_time = new DateTime.from_unix_utc ((int64)timestamp);
            string format = Granite.DateTime.get_default_date_format (false, true, true);
            string date = date_time.format (format);

            if (version != null) {
                label = _("<b>%s</b> – %s").printf (version, date);
            } else {
                label = date;
            }
        } else if (version != null) {
            label = "<b>%s</b>".printf (version);
        } else {
            label = _("Unknown version");
        }

        return label;
    }

    private string format_release_description (AppStream.Release release) {
        string description = release.get_description ();
        if (description != null) {
            try {
                description = AppStream.markup_convert_simple (description);
            } catch (Error e) {
                warning (e.message);
            }

            if (description.strip () == "") {
                description = _("No description available");
            }
        } else {
            description = _("No description available");
        }

        return description;
    }
}
