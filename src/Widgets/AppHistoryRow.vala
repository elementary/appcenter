/*
 * Copyright © 2020 elementary, Inc. (https://elementary.io)
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
 */

public class AppCenter.Widgets.AppHistoryRow : Gtk.ListBoxRow {
    public string description { get; construct; }
    public string title_text { get; construct set; }
    public string icon_name { get; construct set; }

    public AppHistoryRow (string? _title_text, string? _description, string? _icon_name = "application-default-icon") {
        Object (
            title_text: _title_text,
            description: _description,
            icon_name: _icon_name
        );
    }

    construct {
        var image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DND);
        image.pixel_size = 32;

        var title_label = new Gtk.Label (title_text);
        title_label.ellipsize = Pango.EllipsizeMode.END;
        title_label.halign = Gtk.Align.START;

        var description_label = new Gtk.Label ("<span font_size='small'>%s</span>".printf (Markup.escape_text (description)));
        description_label.ellipsize = Pango.EllipsizeMode.END;
        description_label.halign = Gtk.Align.START;
        description_label.use_markup = true;

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.column_spacing = 6;
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (description_label, 1, 1);

        add (grid);

        title_label.bind_property ("label", this, "title-text");
    }
}

