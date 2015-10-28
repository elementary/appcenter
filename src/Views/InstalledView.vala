/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

using AppCenterCore;

public class AppCenter.Views.InstalledView : Gtk.ScrolledWindow {
    public signal void show_settings ();

    private Gtk.Grid        main_grid;
    private Gtk.Button      settings_button;
    private Gtk.Button      update_button;
    private Gtk.Label       number_label;

    private Gtk.ListBox     list_box;

    private Gee.HashMap<Summary, Gtk.ListBoxRow> update_widgets;

    public InstalledView () {
        unowned Client client = Client.get_default ();
        client.operation_changed.connect ((operation, running) => {
            if (operation == Operation.UPDATE_REFRESH && !running)
                update_ui (client.update_list);
        });

        client.refresh_updates.begin ();
        update_ui (client.update_list);
    }

    construct {
        update_widgets = new Gee.HashMap<Summary, Gtk.ListBoxRow> ();
        main_grid = new Gtk.Grid ();
        main_grid.margin = 20;
        main_grid.expand = true;
        main_grid.set_row_spacing (10);
        main_grid.set_column_spacing (10);
        //halign = Gtk.Align.CENTER;
        add (main_grid);

        Gtk.Label head_label = new Gtk.Label (_("Software Updates"));
        head_label.use_markup = true;
        head_label.halign = Gtk.Align.START;
        head_label.get_style_context ().add_class ("h2");
        main_grid.attach (head_label, 0, 0, 1, 1);

        number_label = new Gtk.Label (_("%d Updates").printf (0));
        number_label.halign = Gtk.Align.START;
        number_label.get_style_context ().add_class ("h3");
        number_label.set_opacity (0.75);
        main_grid.attach (number_label, 1, 0, 1, 1);

        Gtk.Label total_size_label = new Gtk.Label (_("Total size:"));
        total_size_label.halign = Gtk.Align.END;
        total_size_label.set_opacity (0.5);
        main_grid.attach (total_size_label, 2, 0, 1, 1);

        Gtk.Label size_label = new Gtk.Label ("0.0 MB");
        size_label.set_opacity (0.5);
        main_grid.attach (size_label, 3, 0, 1, 1);

        settings_button = new Gtk.Button.with_label (_("Settings"));
        settings_button.set_size_request (50, 25);
        settings_button.clicked.connect (() => show_settings ());
        main_grid.attach (settings_button, 4, 0, 1, 1);

        update_button = new Gtk.Button.with_label (_("Update All"));
        update_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        update_button.set_size_request (50, 25);
        update_button.set_sensitive (false);
        main_grid.attach (update_button, 5, 0, 1, 1);

        Gtk.Separator sep_1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep_1.hexpand = true;
        main_grid.attach (sep_1, 0, 1, 6, 1);

        list_box = new Gtk.ListBox ();
        list_box.selection_mode = Gtk.SelectionMode.NONE;
        list_box.expand = true;
        main_grid.attach (list_box, 0, 2, 6, 1);
    }

    private void update_ui (Gee.ArrayList<Summary> update_list) {
        number_label.set_label (_("%d Updates").printf (update_list.size));

        update_widgets.clear ();

        foreach (Summary summary in update_list) {
            var row = create_row (summary);
            update_widgets.set (summary, row);
            list_box.add (create_row (summary));
        }

        list_box.show_all ();
    }

    private Gtk.ListBoxRow create_row (Summary summary) {
        var row = new Gtk.ListBoxRow ();
        row.expand = true;
        row.activatable = false;

        var grid = new Gtk.Grid ();
        grid.expand = true;
        grid.margin = 2;
        row.add (grid);

        Gtk.Image icon = new Gtk.Image.from_icon_name ("application-default-icon", Gtk.IconSize.DIALOG);
        icon.halign = Gtk.Align.START;
        grid.attach (icon, 0, 0, 1, 1);

        Gtk.Label label = new Gtk.Label ("<span font_weight=\"bold\" size=\"x-large\">%s</span>".printf (summary.display_name));
        label.use_markup = true;
        label.halign = Gtk.Align.START;
        label.hexpand = true;
        grid.attach (label, 1, 0, 1, 1);

        Widgets.ActionButton button = new Widgets.ActionButton.with_label (_("Update"));
        button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        button.set_size_request (120, 25);
        button.margin_top = 10;
        button.margin_bottom = 10;
        grid.attach (button, 2, 0, 1, 1);

        return row;
    }
}
