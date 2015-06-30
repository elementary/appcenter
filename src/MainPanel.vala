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

namespace AppCenter {
    public class MainPanel : Gtk.Grid {
        public signal void show_button (int index);
        public signal void hide_button ();

        private Gtk.Stack               tab1_stack;
        private Gtk.Stack               tab2_stack;
        private Gtk.Stack               stack;
        private Gtk.ScrolledWindow      content_window;

        private Widgets.InfoBar         infobar;

        private Views.BrowseView        browse_view;
        private Views.UpdateView        update_view;
        private Views.SettingsView      settings_view;
        private Views.AppInfoView       app_info_view;

        private Details? app_details = null;

        public MainPanel () {
            expand = true;
            build_ui ();
        }

        private void build_ui () {
            infobar = new Widgets.InfoBar ();
            attach (infobar, 0, 0, 1, 1);

            content_window = new Gtk.ScrolledWindow (null, null);

            stack = new Gtk.Stack ();
            stack.expand = true;
            stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            content_window.add (stack);

            browse_view = new Views.BrowseView ();
            update_view = new Views.UpdateView ();
            settings_view = new Views.SettingsView ();
            app_info_view = new Views.AppInfoView ();

            tab1_stack = new Gtk.Stack ();
            tab1_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            tab1_stack.add_named (browse_view, "browse-view");
            tab1_stack.add_named (app_info_view, "app-info-view");
            tab1_stack.set_visible_child (browse_view);

            tab2_stack = new Gtk.Stack ();
            tab2_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            tab2_stack.add_named (update_view, "update-view");
            tab2_stack.add_named (settings_view, "settings-view");
            tab2_stack.set_visible_child (update_view);

            stack.add_named (tab1_stack, "tab1-stack");
            stack.add_named (tab2_stack, "tab2-stack");
            stack.set_visible_child (tab1_stack);

            browse_view.show_app_info.connect ((app_name) => {
                app_details = new Details (app_name);
                app_info_view.reload_for_app (app_details);
                tab1_stack.set_visible_child (app_info_view);
                show_button (1);
            });

            update_view.show_settings.connect (() => {
                tab2_stack.set_visible_child (settings_view);
                show_button (2);
            });

            attach (content_window, 0, 1, 1, 1);
        }

        public void change_tab (int index) {
            stack.set_visible_child_name ("tab%d-stack".printf (index));

            if (index == 1 && tab1_stack.get_visible_child_name () != "browse-view" 
                || index == 2 && tab2_stack.get_visible_child_name () != "update-view")
                    show_button (index);
            else
                hide_button ();
        }

        public void go_back () {
            if (stack.get_visible_child_name () == "tab1-stack") {
                tab1_stack.set_visible_child_name ("browse-view");
            } else if (stack.get_visible_child_name () == "tab2-stack") {
                tab2_stack.set_visible_child_name ("update-view");
            }
        }
    }
}
