/*
 * Copyright (c) 2018 elementary, Inc. (https://elementary.io)
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

namespace AppCenter.Widgets {
    public class ContentWarningDialog : Gtk.Dialog {
        public string app_name { get; construct set; }

        public ContentWarningDialog (string _app_name) {
            Object (
                app_name: _app_name,
                resizable: false,
                title: _("Content Warning"),
                window_position: Gtk.WindowPosition.CENTER_ALWAYS
            );
        }

        construct {
            deletable = false;

            var icon = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
            icon.valign = Gtk.Align.START;

            var primary_label = new Gtk.Label (_("%s Contains Explicit Content").printf (app_name));
            primary_label.halign = Gtk.Align.START;
            primary_label.max_width_chars = 50;
            primary_label.wrap = true;
            primary_label.xalign = 0;
            primary_label.get_style_context ().add_class ("primary");

            var secondary_label = new Gtk.Label (_("%s may contain content only suitable for adults or that may be sensitive or disturbing. In general, elementary does not review or endorse the contents of this app.").printf (app_name));
            secondary_label.max_width_chars = 50;
            secondary_label.wrap = true;
            secondary_label.xalign = 0;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.margin_start = grid.margin_end = grid.margin_bottom = 12;

            grid.attach (icon, 0, 0, 1, 2);
            grid.attach (primary_label, 1, 0);
            grid.attach (secondary_label, 1, 1);

            var cancel = add_button (_("Don’t Install"), Gtk.ResponseType.CANCEL) as Gtk.Button;
            cancel.clicked.connect (() => { destroy (); });

            var confirm = add_button (_("Install Anyway"), Gtk.ResponseType.OK) as Gtk.Button;

            set_default (confirm);

            get_content_area ().add (grid);

            var action_area = get_action_area ();
            action_area.margin_end = action_area.margin_start = 6;
            action_area.margin_bottom = 6;
        }
    }
}

