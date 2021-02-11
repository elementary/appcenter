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

public class AppCenter.Widgets.AppHistoryDialog : Granite.Dialog {
    public AppHistoryDialog () {
        Object (
            deletable: false,
            default_width: 400,
            default_height: 500,
            title: _("App History")
        );
    }

    construct {
        var primary_label = new Gtk.Label (_("App History"));
        primary_label.wrap = true;
        primary_label.max_width_chars = 60;
        primary_label.xalign = 0;
        primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

        var secondary_label = new Gtk.Label (_("Download previously installed apps."));
        secondary_label.wrap = true;
        secondary_label.max_width_chars = 60;
        secondary_label.xalign = 0;

        var search_entry = new Gtk.SearchEntry ();
        search_entry.margin = 6;
        search_entry.placeholder_text = _("Search App History");

        var placeholder = new Granite.Widgets.AlertView (
            _("No apps in history"),
            _("Download or purchase an app for it to show up here."),
            ""
        );
        placeholder.show_all ();

        var list_box = new Gtk.ListBox ();
        list_box.activate_on_single_click = true;
        list_box.expand = true;
        list_box.selection_mode = Gtk.SelectionMode.SINGLE;
        list_box.set_placeholder (placeholder);

        list_box.add (new AppHistoryRow (
            "Example App",
            "App description goes here",
            "com.example.app",
            "application-default-icon"
        ));

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_window.add (list_box);

        var filter_check_button = new Gtk.CheckButton ();
        filter_check_button.label = _("Include currently-installed apps");
        filter_check_button.margin = 6;

        var list_box_grid = new Gtk.Grid ();
        list_box_grid.orientation = Gtk.Orientation.VERTICAL;
        list_box_grid.add (search_entry);
        list_box_grid.add (scrolled_window);

        var frame = new Gtk.Frame (null);
        frame.margin_top = 24;
        frame.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        frame.add (list_box_grid);

        var grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.margin_top = 0;
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.add (primary_label);
        grid.add (secondary_label);
        grid.add (frame);
        grid.add (filter_check_button);
        grid.show_all ();

        get_content_area ().add (grid);
        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        list_box.row_activated.connect ((row) => {
            (row as Widgets.AppHistoryRow).open_app ();
            destroy ();
        });

        response.connect (() => {
            destroy ();
        });
    }
}
