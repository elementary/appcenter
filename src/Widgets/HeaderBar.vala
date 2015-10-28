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

namespace AppCenter.Widgets {
    public class HeaderBar : Gtk.HeaderBar {
        private Gtk.SearchEntry             search_entry;
        private Granite.Widgets.ModeButton  view_mode_button;
        private ActionButton                update_button;
        private Gtk.Button                  back_button;
        private Gtk.Image                   browse_icon;
        private Gtk.Image                   updates_icon;

        public signal void tab_changed (int index);
        public signal void go_back ();

        public HeaderBar () {
            get_style_context ().add_class ("primary-toolbar");
            show_close_button = true;

            build_ui ();
        }

        public void show_button (int index) {
            if (index == 1)
                back_button.set_label (_("Browse Applications"));
            else if (index == 2)
                back_button.set_label (_("Show Updates"));

            back_button.set_no_show_all (false);
            back_button.show ();

            view_mode_button.hide ();
        }

        public void hide_button () {
            back_button.set_no_show_all (true);
            back_button.hide ();

            view_mode_button.show ();
        }

        private void build_ui () {
            search_entry = new Gtk.SearchEntry ();
            search_entry.set_placeholder_text (_("Search ..."));
            pack_end (search_entry);

            update_button = new ActionButton.from_icon_name ("view-refresh", Gtk.IconSize.LARGE_TOOLBAR);
            update_button.set_tooltip_text (_("Refresh cache"));
            update_button.clicked.connect (() => Client.get_default ().refresh_cache.begin ());
            pack_end (update_button);

            back_button = new Gtk.Button ();
            back_button.get_style_context ().add_class ("back-button");
            back_button.can_focus = false;
            back_button.valign = Gtk.Align.CENTER;
            back_button.vexpand = false;
            pack_start (back_button);
            back_button.set_no_show_all (true);

            browse_icon = new Gtk.Image.from_icon_name ("system-software-installer", Gtk.IconSize.LARGE_TOOLBAR);
            browse_icon.set_tooltip_text (_("Browse applications"));

            updates_icon = new Gtk.Image.from_icon_name ("system-software-update", Gtk.IconSize.LARGE_TOOLBAR);
            updates_icon.set_tooltip_text (_("Update your system"));

            view_mode_button = new Granite.Widgets.ModeButton ();
            view_mode_button.append (browse_icon);
            view_mode_button.append (updates_icon);
            view_mode_button.set_active (0);
            set_custom_title (view_mode_button);

            back_button.clicked.connect (() => {
                hide_button ();
                go_back ();
            });

            view_mode_button.mode_changed.connect ((widget) => {
                if (widget == browse_icon)
                    tab_changed (1);
                else if (widget == updates_icon)
                    tab_changed (2);
            });

        }
    }
}
