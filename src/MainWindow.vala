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

public class AppCenter.MainWindow : Gtk.Window {
    private Granite.Widgets.ModeButton view_mode;
    private Gtk.HeaderBar headerbar;
    private Gtk.Stack stack;
    private Gtk.SearchEntry search_entry;
    private Views.CategoryView category_view;
    private Views.FeaturedView featured_view;
    private Views.InstalledView installed_view;
    private Views.SearchView search_view;
    private Gtk.Button current_button;
    private ulong task_finished_connection = 0U;

    public MainWindow () {
        window_position = Gtk.WindowPosition.CENTER;
        create_headerbar ();
        create_views ();
        title = _("App Center");
        icon_name = "system-software-installer";
        set_size_request (750, 550);
        unowned Settings saved_state = Settings.get_default ();
        set_default_size (saved_state.window_width, saved_state.window_height);

        // Maximize window if necessary
        switch (saved_state.window_state) {
            case Settings.WindowState.MAXIMIZED:
                this.maximize ();
                break;
            default:
                break;
        }

        view_mode.selected = 0;
        stack.set_visible_child (featured_view);
    }

    public override bool delete_event (Gdk.EventAny event) {
        int window_width;
        int window_height;
        get_size (out window_width, out window_height);
        unowned Settings saved_state = Settings.get_default ();
        saved_state.window_width = window_width;
        saved_state.window_height = window_height;
        if (is_maximized) {
            saved_state.window_state = Settings.WindowState.MAXIMIZED;
        } else {
            saved_state.window_state = Settings.WindowState.NORMAL;
        }

        unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
        if (client.has_tasks ()) {
            if (task_finished_connection != 0U) {
                client.disconnect (task_finished_connection);
            }

            hide ();
            task_finished_connection = client.tasks_finished.connect (() => {
                if (!visible) {
                    delete_event (event);
                }
            });

            return true;
        }

        return false;
    }

    private void create_headerbar () {
        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        set_titlebar (headerbar);

        view_mode = new Granite.Widgets.ModeButton ();
        view_mode.append_text (_("Featured"));
        view_mode.append_text (_("Categories"));
        view_mode.append_text (C_("view", "Installed"));

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search App");

        headerbar.set_custom_title (view_mode);
        headerbar.pack_end (search_entry);

        view_mode.notify["selected"].connect (() => {
            switch (view_mode.selected) {
                case 0:
                    stack.set_visible_child (featured_view);
                    break;
                case 1:
                    stack.set_visible_child (category_view);
                    break;
                default:
                    stack.set_visible_child (installed_view);
                    break;
            }
        });
    }

    private void create_views () {
        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        stack.expand = true;

        featured_view = new Views.FeaturedView ();
        category_view = new Views.CategoryView ();
        installed_view = new Views.InstalledView ();
        search_view = new Views.SearchView ();
        stack.add (featured_view);
        stack.add (category_view);
        stack.add (installed_view);
        stack.add (search_view);
        add (stack);

        category_view.subview_entered.connect ((name) => {
            show_return_button (name, category_view);
        });

        installed_view.subview_entered.connect ((name) => {
            show_return_button (name, installed_view);
        });
    }

    private void show_return_button (string return_label, View view) {
        var return_button = new Gtk.Button.with_label (return_label);
        return_button.get_style_context ().add_class ("back-button");
        return_button.show_all ();
        if (current_button != null) {
            current_button.destroy ();
        }

        current_button = return_button;
        headerbar.pack_start (return_button);
        view_mode.sensitive = false;
        return_button.clicked.connect (() => {
            view_mode.sensitive = true;
            view.return_clicked ();
            return_button.destroy ();
        });
    }
}
