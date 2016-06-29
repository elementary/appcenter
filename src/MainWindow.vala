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

public class AppCenter.MainWindow : Gtk.ApplicationWindow {
    private Gtk.Revealer view_mode_revealer;
    private Granite.Widgets.ModeButton view_mode;
    private Gtk.HeaderBar headerbar;
    private Gtk.Stack stack;
    private Gtk.SearchEntry search_entry;
    private Views.CategoryView category_view;
    private Views.SearchView search_view;
    private Gtk.Button return_button;
    private ulong task_finished_connection = 0U;
    
    public static Views.InstalledView installed_view { get; private set; }

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/org/pantheon/appcenter/icons");

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
        search_entry.grab_focus_without_selecting ();

        var go_back = new SimpleAction ("go-back", null);
        go_back.activate.connect (view_return);
        add_action (go_back);
        app.set_accels_for_action ("win.go-back", {"<Alt>Left"});

        search_entry.search_changed.connect (() => trigger_search ());

        view_mode.notify["selected"].connect (() => {
            switch (view_mode.selected) {
                case 0:
                    stack.set_visible_child (category_view);
                    break;
                default:
                    stack.set_visible_child (installed_view);
                    break;
            }
        });

        search_entry.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                search_entry.text = "";
                return true;
            }
            
            return false;
        });

        return_button.clicked.connect (view_return);

        installed_view.get_apps.begin ();

        category_view.subview_entered.connect (view_opened);
        installed_view.subview_entered.connect (view_opened);
        search_view.subview_entered.connect (view_opened);
    }

    construct {
        icon_name = "system-software-installer";
        title = _("AppCenter");
        window_position = Gtk.WindowPosition.CENTER;

        return_button = new Gtk.Button ();
        return_button.no_show_all = true;
        return_button.get_style_context ().add_class ("back-button");

        view_mode = new Granite.Widgets.ModeButton ();
        view_mode.append_text (_("Categories"));
        view_mode.append_text (C_("view", "Updates"));

        view_mode_revealer = new Gtk.Revealer ();
        view_mode_revealer.reveal_child = true;
        view_mode_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        view_mode_revealer.add (view_mode);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Apps");

        /* HeaderBar */
        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_custom_title (view_mode_revealer);
        headerbar.pack_start (return_button);
        headerbar.pack_end (search_entry);

        set_titlebar (headerbar);

        category_view = new Views.CategoryView ();
        installed_view = new Views.InstalledView ();
        search_view = new Views.SearchView ();

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        stack.add (category_view);
        stack.add (installed_view);
        stack.add (search_view);

        add (stack);
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
                    destroy ();
                }
            });

            client.interface_cancellable.cancel ();
            return true;
        }

        return false;
    }

    public void go_to_installed () {
        view_mode.selected = 1;
    }

    private void trigger_search () {
        unowned string research = search_entry.text;
        if (research.length < 2) {
            view_mode_revealer.reveal_child = true;
            switch (view_mode.selected) {
                case 0:
                    stack.visible_child = category_view;
                    break;
                default:
                    stack.visible_child = installed_view;
                    break;
            }
        } else {
            search_view.search (research);
            if (!return_button.visible) {
                view_mode_revealer.reveal_child = false;
                stack.visible_child = search_view;
            }
        }
    }

    private void view_opened (string name) {
        return_button.label = name;
        return_button.no_show_all = false;
        return_button.show_all ();

        view_mode_revealer.reveal_child = false;
        search_entry.sensitive = false;
    }

    private void view_return () {
        view_mode_revealer.reveal_child = true;
        search_entry.sensitive = true;
        search_entry.grab_focus_without_selecting ();
        return_button.no_show_all = true;
        return_button.hide ();

        View view = (View) stack.visible_child;
        view.return_clicked ();
    }
}
