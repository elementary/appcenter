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

namespace AppCenter.Views {
    public class AppInfoView : Gtk.ScrolledWindow {
        public weak Details app_details { public get; private set; }

        private Gtk.Stack       stack;
        private Gtk.Grid        main_grid;
        private Gtk.Grid        spinner_grid;
        private Gtk.Spinner     spinner;

        private Gtk.Image       app_image;
        private Gtk.Label       name_label;
        private Gtk.Label       size_label;
        private Gtk.Label       description_label;

        private Widgets.ActionButton    action_button;

        public AppInfoView () {
            stack = new Gtk.Stack ();
            add (stack);

            main_grid = new Gtk.Grid ();
            main_grid.margin = 20;
            main_grid.expand = true;
            main_grid.set_row_spacing (10);
            main_grid.set_column_spacing (10);

            spinner_grid = new Gtk.Grid ();
            spinner_grid.halign = Gtk.Align.CENTER;
            spinner_grid.valign = Gtk.Align.CENTER;
            spinner_grid.expand = true;

            stack.add_named (main_grid, "main-grid");
            stack.add_named (spinner_grid, "spinner-grid");

            build_ui ();
            show_all ();
        }

        public void reload_for_app (Details app_details) {
            this.app_details = app_details;

            stack.set_visible_child (spinner_grid);
            spinner.start ();
            this.app_details.loading_finished.connect (() => {
                update_ui ();
                spinner.stop (); 
                stack.set_visible_child (main_grid);
            });
        }

        private void build_ui () {
            spinner = new Gtk.Spinner ();
            spinner.set_size_request (75, 75);
            spinner.halign = Gtk.Align.CENTER;
            spinner.valign = Gtk.Align.CENTER;
            spinner_grid.attach (spinner, 0, 0, 1, 1);

            spinner_grid.show_all ();

            app_image = new Gtk.Image ();
            app_image.halign = Gtk.Align.START;
            main_grid.attach (app_image, 0, 0, 1, 2);

            name_label = new Gtk.Label ("");
            name_label.use_markup = true;
            name_label.hexpand = true;
            name_label.halign = Gtk.Align.START;
            main_grid.attach (name_label, 1, 0, 1, 1);

            size_label = new Gtk.Label ("5MB");
            size_label.halign = Gtk.Align.END;
            size_label.set_opacity (0.5);
            size_label.margin_top = 15;
            main_grid.attach (size_label, 2, 0, 1, 1);

            action_button = new Widgets.ActionButton.with_label (_("Install"));
            action_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            action_button.set_size_request (125, 25);
            action_button.margin_top = 15;
            action_button.halign = Gtk.Align.END;
            action_button.clicked.connect (() => {
                Client.get_default ().install_package ((Info)app_details);
            });
            main_grid.attach (action_button, 3, 0, 1, 1);

            Gtk.Separator sep_1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep_1.hexpand = true;
            main_grid.attach (sep_1, 0, 2, 4, 1);

            description_label = new Gtk.Label ("");
            description_label.wrap = true;
            description_label.halign = Gtk.Align.START;
            main_grid.attach (description_label, 0, 3, 2, 1);
        }

        private void update_ui () {
            app_image.set_from_icon_name ("application-default-icon", Gtk.IconSize.DIALOG);

            name_label.set_label (@"<span font_weight=\"bold\" size=\"x-large\">%s</span> <span size=\"large\">%s</span>"
                .printf (app_details.display_name, app_details.display_version));

            double size = (double)app_details.size / (1024*1024);
            size_label.set_label ("%.2f MB".printf (size));
            description_label.set_label (app_details.description);
        }
    }
}
