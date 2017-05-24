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
    private Gtk.Stack custom_title_stack;
    private Gtk.Label homepage_header;
    private Granite.Widgets.ModeButton view_mode;
    private Gtk.HeaderBar headerbar;
    private Gtk.Stack stack;
    private Gtk.SearchEntry search_entry;
    private Homepage homepage;
    private Views.SearchView search_view;
    private Gtk.Button return_button;
    private Gtk.Button search_all_button;
    private Gtk.Stack button_stack;
    private ulong task_finished_connection = 0U;
    private Gee.Deque<string> return_button_history;
    private Granite.Widgets.AlertView network_alert_view;
    private Gtk.Grid network_view;

    public static Views.InstalledView installed_view { get; private set; }

    public signal void homepage_loaded ();

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/appcenter/icons");

        unowned Settings saved_state = Settings.get_default ();
        set_default_size (saved_state.window_width, saved_state.window_height);

        Gdk.Geometry hints = Gdk.Geometry ();
        hints.max_width = 1500;
        hints.max_height = 1080;
        set_geometry_hints (null, hints, Gdk.WindowHints.MAX_SIZE);

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
            update_view ();
        });

        search_entry.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                search_entry.text = "";
                return true;
            }

            return false;
        });

        return_button.clicked.connect (view_return);
        search_all_button.clicked.connect (search_all_apps);

        installed_view.get_apps.begin ();

        homepage.subview_entered.connect (view_opened);
        installed_view.subview_entered.connect (view_opened);
        search_view.subview_entered.connect (view_opened);

        NetworkMonitor.get_default ().network_changed.connect (update_view);

        network_alert_view.action_activated.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://network", null);
            } catch (Error e) {
                warning (e.message);
            }
        });

        this.show.connect (update_view);
    }

    construct {
        icon_name = "system-software-install";
        set_size_request (910, 640);
        title = _("AppCenter");
        window_position = Gtk.WindowPosition.CENTER;

        return_button = new Gtk.Button ();
        return_button.no_show_all = true;
        return_button.get_style_context ().add_class ("back-button");
        return_button_history = new Gee.LinkedList<string> ();

        search_all_button = new Gtk.Button.with_label (_("Search Apps"));
        search_all_button.no_show_all = true;
        search_all_button.get_style_context ().add_class ("back-button");

        button_stack = new Gtk.Stack ();
        button_stack.add (return_button);
        button_stack.add (search_all_button);
        button_stack.set_visible_child (return_button);

        view_mode = new Granite.Widgets.ModeButton ();
        view_mode.margin = 1;
        view_mode.append_text (_("Home"));
        view_mode.append_text (C_("view", "Updates"));

        view_mode_revealer = new Gtk.Revealer ();
        view_mode_revealer.reveal_child = true;
        view_mode_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        view_mode_revealer.add (view_mode);

        homepage_header = new Gtk.Label ("Homepage Header");
        homepage_header.get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);

        custom_title_stack = new Gtk.Stack ();
        custom_title_stack.add (view_mode_revealer);
        custom_title_stack.add (homepage_header);
        custom_title_stack.set_visible_child (view_mode_revealer);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Apps");

        /* HeaderBar */
        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_custom_title (custom_title_stack);
        headerbar.pack_start (button_stack);
        headerbar.pack_end (search_entry);

        set_titlebar (headerbar);

        homepage = new Homepage (this);
        installed_view = new Views.InstalledView ();
        search_view = new Views.SearchView ();

        network_alert_view = new Granite.Widgets.AlertView (_("Network Is Not Available"),
                                                            _("Connect to the internet to install or update apps."),
                                                            "network-error");
        network_alert_view.get_style_context ().remove_class (Gtk.STYLE_CLASS_VIEW);
        network_alert_view.show_action (_("Network Settings…"));

        network_view = new Gtk.Grid ();
        network_view.margin = 24;
        network_view.attach (network_alert_view, 0, 0, 1, 1);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        stack.add (homepage);
        stack.add (installed_view);
        stack.add (search_view);
        stack.add (network_view);

        homepage.package_selected.connect ((package) => {
            stack.set_visible_child (homepage);
            show_package (package);
            return_button.label = (_("Home"));
        });

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
            task_finished_connection = client.notify["task-count"].connect (() => {
                if (!visible && client.task_count == 0) {
                    destroy ();
                }
            });

            client.cancel_updates (false); //Timeouts keep running
            return true;
        }

        return false;
    }

    public void show_package (AppCenterCore.Package package) {
        stack.set_visible_child (homepage);
        homepage.show_package (package);
        view_opened (_("Home"), false, null);

        update_view ();
    }

    public void go_to_installed () {
        view_mode.selected = 1;
    }

    public void search (string term) {
        search_entry.text = term;
        trigger_search ();
    }

    private void trigger_search () {
        unowned string research = search_entry.text;
        if (research.length < 2) {
            if (homepage.currently_viewed_category == null) {
                custom_title_stack.set_visible_child (view_mode_revealer);
            }

            view_mode_revealer.reveal_child = true;
            update_view ();
            if (!return_button_history.is_empty) {
                return_button.no_show_all = false;
                return_button.show_all ();
            }

            button_stack.visible_child = return_button;
            search_all_button.no_show_all = true;
            search_all_button.hide ();
        } else {
            search_view.search (research, homepage.currently_viewed_category);
            if (homepage.currently_viewed_category != null) {
                button_stack.visible_child = search_all_button;
                search_all_button.no_show_all = false;
                search_all_button.show_all ();
            } else {
                button_stack.visible_child = return_button;
                search_all_button.no_show_all = true;
                search_all_button.hide ();
            }

            view_mode_revealer.reveal_child = false;
            stack.visible_child = search_view;
            return_button.no_show_all = true;
            return_button.hide ();
        }

        update_view ();
    }

    private void view_opened (string return_name, bool allow_search, string? custom_header = null) {
        if (stack.visible_child == search_view && homepage.currently_viewed_category != null) {
            button_stack.visible_child = return_button;
            search_all_button.no_show_all = true;
            search_all_button.hide ();
        }

        if (return_button_history.is_empty || return_button_history.peek_head () != return_name) {
            return_button_history.offer_head (return_name);
        }
        return_button.label = return_name;
        return_button.no_show_all = false;
        return_button.show_all ();

        view_mode_revealer.reveal_child = false;
        if (custom_header != null) {
            homepage_header.label = custom_header;
            custom_title_stack.set_visible_child (homepage_header);
        }

        search_entry.sensitive = allow_search;
        search_entry.grab_focus_without_selecting ();
        if (stack.visible_child == homepage && homepage.currently_viewed_category != null) {
            search_entry.placeholder_text = _("Search %s").printf (homepage.currently_viewed_category.get_name ());
        }
    }

    private void view_return () {
        if (stack.visible_child != search_view) {
            view_mode_revealer.reveal_child = true;
            custom_title_stack.set_visible_child (view_mode_revealer);
            homepage_header.label = "";
        } else {
            if (homepage.currently_viewed_category != null) {
                button_stack.visible_child = search_all_button;
                search_all_button.no_show_all = false;
                search_all_button.show_all ();
            }
        }

        if (stack.visible_child == homepage) {
            search_entry.placeholder_text = _("Search Apps");
        }
        search_entry.sensitive = true;
        search_entry.grab_focus_without_selecting ();

        return_button_history.poll_head ();
        if (!return_button_history.is_empty && stack.visible_child == search_view) {
            return_button.label = return_button_history.peek_head ();
            return_button.no_show_all = true;
            return_button.hide ();
        } else {
            return_button.no_show_all = true;
            return_button.hide ();
        }

        View view = (View) stack.visible_child;
        view.return_clicked ();
    }

    private void search_all_apps () {
        homepage_header.label = "";

        search_entry.placeholder_text = _("Search Apps");
        search_entry.grab_focus_without_selecting ();

        return_button_history.poll_head ();
        return_button.no_show_all = true;
        return_button.hide ();

        homepage.return_clicked ();
        trigger_search ();
    }

    private void update_view () {
        var connection_available = NetworkMonitor.get_default ().get_network_available ();
        if (connection_available) {
            if (search_entry.text.length >= 2) {
                stack.visible_child = search_view;
            } else {
                switch (view_mode.selected) {
                    case 0:
                        stack.visible_child = homepage;
                        break;
                    default:
                        stack.visible_child = installed_view;
                        break;
                }
            }
        } else {
            stack.set_visible_child (network_view);
        }

        button_stack.sensitive = connection_available;
        search_entry.sensitive = connection_available && !search_view.viewing_package && !homepage.viewing_package;
    }
}
