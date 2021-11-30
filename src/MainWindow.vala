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

public class AppCenter.MainWindow : Hdy.ApplicationWindow {
    public bool working { get; set; }

    private Gtk.Revealer view_mode_revealer;
    private Gtk.Stack custom_title_stack;
    private Gtk.Label homepage_header;
    private Granite.Widgets.ModeButton view_mode;
    private Gtk.Stack stack;
    private Gtk.SearchEntry search_entry;
    private Gtk.Spinner spinner;
    private Homepage homepage;
    private Views.SearchView search_view;
    private Gtk.Button return_button;
    private Gee.LinkedList<string> return_button_history;
    private Gtk.Label updates_badge;
    private Gtk.Revealer updates_badge_revealer;
    private Granite.Widgets.Toast toast;

    private AppCenterCore.Package? last_installed_package;
    private AppCenterCore.Package? selected_package;

    private uint configure_id;
    private int homepage_view_id;
    private int installed_view_id;

    private bool mimetype;

    private const int VALID_QUERY_LENGTH = 3;

    public static Views.InstalledView installed_view { get; private set; }

    public signal void homepage_loaded ();

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/appcenter/icons");

        view_mode.selected = homepage_view_id;
        search_entry.grab_focus_without_selecting ();

        var go_back = new SimpleAction ("go-back", null);
        go_back.activate.connect (view_return);
        add_action (go_back);

        var focus_search = new SimpleAction ("focus-search", null);
        focus_search.activate.connect (() => search_entry.grab_focus ());
        add_action (focus_search);

        app.set_accels_for_action ("win.go-back", {"<Alt>Left", "Back"});
        app.set_accels_for_action ("win.focus-search", {"<Ctrl>f"});

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

            if (event.keyval == Gdk.Key.Down) {
                search_entry.move_focus (Gtk.DirectionType.TAB_FORWARD);
                return true;
            }

            return false;
        });

        return_button.clicked.connect (view_return);

        homepage.package_selected.connect (package_selected);
        homepage.subview_entered.connect (view_opened);
        installed_view.package_selected.connect (package_selected);
        installed_view.subview_entered.connect (view_opened);
        search_view.package_selected.connect (package_selected);
        search_view.subview_entered.connect (view_opened);
        search_view.home_return_clicked.connect (show_homepage);

        unowned var aggregator = AppCenterCore.BackendAggregator.get_default ();
        aggregator.bind_property ("working", this, "working", GLib.BindingFlags.SYNC_CREATE);

        notify["working"].connect (() => {
            Idle.add (() => {
                spinner.active = working;
                return GLib.Source.REMOVE;
            });
        });

        show.connect (on_view_mode_changed);
    }

    construct {
        Hdy.init ();
        icon_name = Build.PROJECT_NAME;
        set_default_size (910, 640);
        height_request = 500;

        title = _(Build.APP_NAME);

        toast = new Granite.Widgets.Toast ("");

        toast.default_action.connect (() => {
            if (last_installed_package != null) {
                try {
                    last_installed_package.launch ();
                } catch (Error e) {
                    warning ("Failed to launch %s: %s".printf (last_installed_package.get_name (), e.message));

                    var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                        _("Failed to launch “%s“").printf (last_installed_package.get_name ()),
                        e.message,
                        "system-software-install",
                        Gtk.ButtonsType.CLOSE
                    );
                    message_dialog.badge_icon = new ThemedIcon ("dialog-error");
                    message_dialog.transient_for = this;

                    message_dialog.show_all ();
                    message_dialog.response.connect ((response_id) => {
                        message_dialog.destroy ();
                    });
                }
            }
        });

        return_button = new Gtk.Button () {
            no_show_all = true,
            valign = Gtk.Align.CENTER
        };
        return_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

        return_button_history = new Gee.LinkedList<string> ();

        view_mode = new Granite.Widgets.ModeButton () {
            margin = 12,
            margin_top = 7,
            margin_bottom = 7
        };

        homepage_view_id = view_mode.append_text (_("Home"));
        installed_view_id = view_mode.append_text (C_("view", "Installed"));

        var badge_provider = new Gtk.CssProvider ();
        badge_provider.load_from_resource ("io/elementary/appcenter/badge.css");

        updates_badge = new Gtk.Label ("!");

        unowned var badge_context = updates_badge.get_style_context ();
        badge_context.add_class (Granite.STYLE_CLASS_BADGE);
        badge_context.add_provider (badge_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var eventbox_badge = new Gtk.EventBox ();
        eventbox_badge.add (updates_badge);
        eventbox_badge.button_release_event.connect (badge_event);

        updates_badge_revealer = new Gtk.Revealer () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.START,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        updates_badge_revealer.add (eventbox_badge);

        var view_mode_overlay = new Gtk.Overlay ();
        view_mode_overlay.add (view_mode);
        view_mode_overlay.add_overlay (updates_badge_revealer);

        view_mode_revealer = new Gtk.Revealer () {
            reveal_child = true,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        view_mode_revealer.add (view_mode_overlay);

        homepage_header = new Gtk.Label (null);
        homepage_header.get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);

        custom_title_stack = new Gtk.Stack ();
        custom_title_stack.add (view_mode_revealer);
        custom_title_stack.add (homepage_header);
        custom_title_stack.set_visible_child (view_mode_revealer);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search Apps"),
            valign = Gtk.Align.CENTER
        };

        spinner = new Gtk.Spinner ();

        var headerbar = new Hdy.HeaderBar () {
            show_close_button = true
        };
        headerbar.set_custom_title (custom_title_stack);
        headerbar.pack_start (return_button);
        headerbar.pack_end (search_entry);
        headerbar.pack_end (spinner);

        homepage = new Homepage ();
        installed_view = new Views.InstalledView ();
        search_view = new Views.SearchView ();

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        };
        stack.add (homepage);
        stack.add (installed_view);
        stack.add (search_view);

        var overlay = new Gtk.Overlay ();
        overlay.add_overlay (toast);
        overlay.add (stack);

        var network_info_bar = new AppCenter.Widgets.NetworkInfoBar ();

        var grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL
        };
        grid.add (headerbar);
        grid.add (network_info_bar);
        grid.add (overlay);

        add (grid);

        int window_x, window_y;
        int window_width, window_height;
        App.settings.get ("window-position", "(ii)", out window_x, out window_y);
        App.settings.get ("window-size", "(ii)", out window_width, out window_height);

        if (window_x != -1 || window_y != -1) {
            move (window_x, window_y);
        }

        resize (window_width, window_height);

        if (App.settings.get_boolean ("window-maximized")) {
            maximize ();
        }

        homepage.page_loaded.connect (() => homepage_loaded ());
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id == 0) {
            /* Avoid spamming the settings */
            configure_id = Timeout.add (200, () => {
                configure_id = 0;

                if (is_maximized) {
                    App.settings.set_boolean ("window-maximized", true);
                } else {
                    App.settings.set_boolean ("window-maximized", false);

                    int width, height;
                    get_size (out width, out height);
                    App.settings.set ("window-size", "(ii)", width, height);

                    int root_x, root_y;
                    get_position (out root_x, out root_y);
                    App.settings.set ("window-position", "(ii)", root_x, root_y);
                }

                return GLib.Source.REMOVE;
            });
        }

        return base.configure_event (event);
    }

    public override bool delete_event (Gdk.EventAny event) {
        if (working) {
            hide ();

            notify["working"].connect (() => {
                if (!visible && !working) {
                    destroy ();
                }
            });

            AppCenterCore.Client.get_default ().cancel_updates (false); //Timeouts keep running
            return true;
        }

        return false;
    }

    public void show_update_badge (uint updates_number) {
        if (updates_number == 0U) {
            updates_badge_revealer.reveal_child = false;
        } else {
            updates_badge.label = updates_number.to_string ();
            updates_badge_revealer.reveal_child = true;
        }
    }

    private bool badge_event (Gtk.Widget sender, Gdk.EventButton evt) {
        go_to_installed ();
        return Gdk.EVENT_STOP;
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

    public void search (string term, bool mimetype = false) {
        this.mimetype = mimetype;
        search_entry.text = term;
    }

    public void send_installed_toast (AppCenterCore.Package package) {
        last_installed_package = package;

        // Only show a toast when we're not on the installed app's page, i.e if
        // no package is selected (we are not on an app page), or a package is 
        // selected but it's not the app we're installing.
        if (selected_package == null || (selected_package != null && selected_package.get_name () != package.get_name ())) {
            toast.title = _("“%s” has been installed").printf (package.get_name ());
            // Show Open only when a desktop app is installed
            if (package.component.get_kind () == AppStream.ComponentKind.DESKTOP_APP) {
                toast.set_default_action (_("Open"));
            } else {
                toast.set_default_action (null);
            }

            toast.send_notification ();
        }
    }

    private void trigger_search () {
        unowned string query = search_entry.text;
        uint query_length = query.length;
        bool query_valid = query_length >= VALID_QUERY_LENGTH;

        view_mode_revealer.reveal_child = !query_valid;

        if (query_valid) {
            search_view.search (query, homepage.currently_viewed_category, mimetype);
            stack.visible_child = search_view; // Only show search view after search completed.
        } else {
            if (stack.visible_child == search_view) {
                if (homepage.currently_viewed_category != null) {
                    return_button_history.poll_head ();
                    return_button.label = return_button_history.peek_head ();
                } else {
                    return_button_history.clear ();
                    return_button.no_show_all = true;
                    return_button.visible = false;
                }
            }

            search_view.reset ();
            stack.visible_child = homepage;
        }

        if (mimetype) {
            mimetype = false;
        }
    }

    private void package_selected (AppCenterCore.Package package) {
        selected_package = package;
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
        selected_package = null;

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

        var view = (AbstractView) stack.visible_child;
        view.return_clicked ();
    }

    private void on_view_mode_changed () {
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
    }

    private void show_homepage () {
        search ("");
        search_view.reset ();
        stack.visible_child = homepage;
        view_mode_revealer.reveal_child = true;
    }
}
