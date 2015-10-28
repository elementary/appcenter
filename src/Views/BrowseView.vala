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
    public class BrowseView : Gtk.Grid {
        private Gtk.Stack           tab_stack;
        private Gtk.StackSwitcher   tab_stack_switcher;

        private FeaturedTab         featured_tab;
        private PopularTab          popular_tab;
        private CategoryTab         category_tab;

        public signal void show_app_info (string app_name);
        public signal void show_category_list (string category_name);

        public BrowseView () {
            margin = 20;
            expand = true;
            set_row_spacing (10);
            set_column_spacing (10);
            halign = Gtk.Align.CENTER;

            build_ui ();
            show_all ();
        }

        private void build_ui () {

            tab_stack = new Gtk.Stack ();
            tab_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            attach (tab_stack, 0, 2, 3, 1);

            featured_tab = new FeaturedTab (this);
            tab_stack.add_titled (featured_tab, "featured-tab", _("Featured"));
            popular_tab = new PopularTab (this);
            tab_stack.add_titled (popular_tab, "popular-tab", _("Most Popular"));
            category_tab = new CategoryTab (this);
            tab_stack.add_titled (category_tab, "category-tab", _("Categories"));

            tab_stack.set_visible_child (featured_tab);

            tab_stack_switcher = new Gtk.StackSwitcher ();
            tab_stack_switcher.halign = Gtk.Align.CENTER;
            tab_stack_switcher.set_stack (tab_stack);
            attach (tab_stack_switcher, 0, 1, 3, 1);
        }
    }

    private class CategoryTab : Gtk.Grid {

        public CategoryTab (BrowseView view) {
            build_ui ();
            show_all ();
        }

        private void build_ui () {
        }
    }

    private class PopularTab : Gtk.Grid {
        public PopularTab (BrowseView  view) {
            build_ui ();
            show_all ();
        }

        private void build_ui () { }
    }

    private class FeaturedTab : Gtk.Grid {
        private weak BrowseView view;

        public FeaturedTab (BrowseView view) {
            this.view = view;

            set_row_spacing (10);
            set_column_spacing (10);

            build_ui ();
            show_all ();
        }

        private void build_ui () {
            Gtk.Button button_noise = new Gtk.Button.with_label ("Show App Info for Eidete");
            button_noise.clicked.connect (() => view.show_app_info ("eidete;0.1~r197-0+pkg16~daily~ubuntu15.10.1;amd64;wily"));
            attach (button_noise, 0, 0, 1, 1);

            Gtk.Button button_audience = new Gtk.Button.with_label ("Show App Info for Audience");
            button_audience.clicked.connect (() => view.show_app_info ("audience;0.1.0.1+r529-0+pkg19~daily~ubuntu0.3.1;amd64;trusty"));
            attach (button_audience, 1, 0, 1, 1);
        }
    }
}
