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
    public bool working {
        set {
            if (value) {
                spinner.start ();
            } else {
                spinner.stop ();
            }
        }
    }

    private Gtk.Revealer view_mode_revealer;
    private Gtk.Stack custom_title_stack;
    private Gtk.Label homepage_header;
    private Granite.Widgets.ModeButton view_mode;
    private Gtk.HeaderBar headerbar;
    private Gtk.Stack stack;
    private Gtk.SearchEntry search_entry;
    private Gtk.Spinner spinner;
    private Homepage homepage;
    private Views.SearchView search_view;
    private Gtk.Button return_button;
    private ulong task_finished_connection = 0U;
    private Gee.LinkedList<string> return_button_history;
    private Granite.Widgets.AlertView network_alert_view;
    private Gtk.Grid network_view;
    private Gtk.Label updates_badge;

    private int homepage_view_id;
    private int installed_view_id;

    private const int VALID_QUERY_LENGTH = 3;

    public static Views.InstalledView installed_view { get; private set; }

    public signal void homepage_loaded ();

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/appcenter/icons");

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

        view_mode.selected = homepage_view_id;
        search_entry.grab_focus_without_selecting ();

        var go_back = new SimpleAction ("go-back", null);
        go_back.activate.connect (view_return);
        add_action (go_back);
        app.set_accels_for_action ("win.go-back", {"<Alt>Left", "Back"});

        button_release_event.connect ((event) => {
            // On back mouse button pressed
            if (event.button == 8) {
                view_return ();
                return true;
            }

            return false;
        });

        search_entry.search_changed.connect (() => trigger_search ());

        view_mode.notify["selected"].connect (on_view_mode_changed);

        search_entry.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                search_entry.text = "";
                return true;
            }

            return false;
        });

        return_button.clicked.connect (view_return);

        installed_view.get_apps.begin ();

        homepage.subview_entered.connect (view_opened);
        installed_view.subview_entered.connect (view_opened);
        search_view.subview_entered.connect (view_opened);

        NetworkMonitor.get_default ().network_changed.connect (on_view_mode_changed);

        network_alert_view.action_activated.connect (() => {
            try {
                string[] args = {
                  "gnome-control-center", "network"
                };
                Process.spawn_async (
                    null,
                    args,
                    null,
                    SpawnFlags.SEARCH_PATH,
                    null,
                    null
                );
            } catch (Error e) {
                warning (e.message);
            }
        });

        unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
        client.notify["task-count"].connect (() => {
            working = client.task_count > 0;
        });

        show.connect (on_view_mode_changed);
    }

    construct {
        icon_name = "system-software-install";
        set_size_request (910, 640);
        title = _(Build.APP_NAME);
        window_position = Gtk.WindowPosition.CENTER;

        return_button = new Gtk.Button ();
        return_button.no_show_all = true;
        return_button.valign = Gtk.Align.CENTER;
        return_button.get_style_context ().add_class ("back-button");
        return_button_history = new Gee.LinkedList<string> ();

        view_mode = new Granite.Widgets.ModeButton ();
        view_mode.margin_end = view_mode.margin_start = 12;
        view_mode.margin_bottom = view_mode.margin_top = 7;
        homepage_view_id = view_mode.append_text (_("Home"));
        installed_view_id = view_mode.append_text (C_("view", "Installed"));

        updates_badge = new Gtk.Label ("!");
        updates_badge.halign = Gtk.Align.END;
        updates_badge.valign = Gtk.Align.START;
        updates_badge.get_style_context ().add_class ("badge");
        set_widget_visibility (updates_badge, false);

        var view_mode_overlay = new Gtk.Overlay ();
        view_mode_overlay.add (view_mode);
        view_mode_overlay.add_overlay (updates_badge);

        view_mode_revealer = new Gtk.Revealer ();
        view_mode_revealer.reveal_child = true;
        view_mode_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        view_mode_revealer.add (view_mode_overlay);

        homepage_header = new Gtk.Label (null);
        homepage_header.get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);

        custom_title_stack = new Gtk.Stack ();
        custom_title_stack.add (view_mode_revealer);
        custom_title_stack.add (homepage_header);
        custom_title_stack.set_visible_child (view_mode_revealer);

        search_entry = new Gtk.SearchEntry ();
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.placeholder_text = _("Search Apps");

        spinner = new Gtk.Spinner ();

        /* HeaderBar */
        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_custom_title (custom_title_stack);
        headerbar.pack_start (return_button);
        headerbar.pack_end (search_entry);
        headerbar.pack_end (spinner);

        set_titlebar (headerbar);

        homepage = new Homepage (this);
        installed_view = new Views.InstalledView ();
        search_view = new Views.SearchView ();

        network_alert_view = new Granite.Widgets.AlertView (_("Network Is Not Available"),
                                                            _("Connect to the Internet to install or update apps."),
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

    public void show_update_badge (uint updates_number) {
        if (updates_number == 0U) {
            set_widget_visibility (updates_badge, false);
        } else {
            updates_badge.label = updates_number.to_string ();
            set_widget_visibility (updates_badge, true);
        }
    }

    public void show_package (AppCenterCore.Package package) {
        search ("");
        return_button_history.clear ();
        view_mode.selected = homepage_view_id;
        stack.visible_child = homepage;
        homepage.show_package (package);
    }

    public void go_to_installed () {
        view_mode.selected = installed_view_id;
    }

    public void search (string term) {
        search_entry.text = term;
    }

    private void trigger_search () {
        unowned string query = search_entry.text;
        uint query_length = query.length;
        bool query_valid = query_length >= VALID_QUERY_LENGTH;

        view_mode_revealer.reveal_child = !query_valid;

        if (query_valid) {
            search_view.search (query, homepage.currently_viewed_category);
            stack.visible_child = search_view;
        } else {
            if (stack.visible_child == search_view && homepage.currently_viewed_category != null) {
                return_button_history.poll_head ();
                return_button.label = return_button_history.peek_head ();
            }

            search_view.reset ();
            stack.visible_child = homepage;
        }
    }

    private void view_opened (string? return_name, bool allow_search, string? custom_header = null, string? custom_search_placeholder = null) {
        if (return_name != null) {
            if (return_button_history.peek_head () != return_name) {
                return_button_history.offer_head (return_name);
            }

            return_button.label = return_name;
            return_button.no_show_all = false;
            return_button.visible = true;
        } else {
            return_button.no_show_all = true;
            return_button.visible = false;
        }

        if (custom_header != null) {
            homepage_header.label = custom_header;
            custom_title_stack.visible_child = homepage_header;
        } else {
            custom_title_stack.visible_child = view_mode_revealer;
        }

        if (custom_search_placeholder != null) {
            search_entry.placeholder_text = custom_search_placeholder;
        } else {
            search_entry.placeholder_text = _("Search Apps");
        }

        search_entry.sensitive = allow_search;
        search_entry.grab_focus_without_selecting ();
    }

    private void view_return () {
        if (stack.visible_child == search_view && !search_view.viewing_package && homepage.currently_viewed_category != null) {
            homepage.return_clicked ();

            return_button_history.clear ();
            return_button.no_show_all = true;
            return_button.visible = false;
        }

        return_button_history.poll_head ();
        if (!return_button_history.is_empty) {
            return_button.label = return_button_history.peek_head ();
            return_button.no_show_all = false;
            return_button.visible = true;
        } else {
            return_button.no_show_all = true;
            return_button.visible = false;
        }

        View view = (View) stack.visible_child;
        view.return_clicked ();
    }

    private void on_view_mode_changed () {
        var connection_available = NetworkMonitor.get_default ().get_network_available ();
        if (connection_available) {
            if (search_entry.text.length >= VALID_QUERY_LENGTH) {
                stack.visible_child = search_view;
                search_entry.sensitive = !search_view.viewing_package;
            } else {
                if (view_mode.selected == homepage_view_id) {
                    stack.visible_child = homepage;
                    search_entry.sensitive = !homepage.viewing_package;
                } else if (view_mode.selected == installed_view_id) {
                    stack.visible_child = installed_view;
                    search_entry.sensitive = false;
                }
            }
        } else {
            stack.visible_child = network_view;
            search_entry.sensitive = false;
        }

        custom_title_stack.sensitive = connection_available;
        return_button.sensitive = connection_available;
    }
}
