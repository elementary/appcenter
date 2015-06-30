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

namespace AppCenter {
     public class MainWindow : Gtk.Window {
        private Widgets.HeaderBar       headerbar;
        private MainPanel               main_panel;

        public MainWindow () {
            window_position = Gtk.WindowPosition.CENTER;
            set_size_request (1000, 700);
            set_resizable (false);

            build_ui ();
        }

        private void build_ui () {
            headerbar = new Widgets.HeaderBar ();
            set_titlebar (headerbar);

            main_panel = new MainPanel ();
            add (main_panel);

            headerbar.tab_changed.connect (main_panel.change_tab);
            headerbar.go_back.connect (main_panel.go_back);
            main_panel.show_button.connect (headerbar.show_button);
            main_panel.hide_button.connect (headerbar.hide_button);

            show_all ();
        }
     }
}
