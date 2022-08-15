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
    private Gtk.Stack stack;
    private Gtk.SearchEntry search_entry;
    private Gtk.Spinner spinner;
    private Gtk.ModelButton refresh_menuitem;
    private Homepage homepage;
    private Gtk.Button return_button;
    private Gtk.Label updates_badge;
    private Gtk.Revealer updates_badge_revealer;
    private Granite.Widgets.Toast toast;

    private AppCenterCore.Package? last_installed_package;
    private AppCenterCore.Package? selected_package;

    private uint configure_id;

    private bool mimetype;

    private const int VALID_QUERY_LENGTH = 3;

    public static Views.InstalledView installed_view { get; private set; }

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/appcenter/icons");

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
        installed_view.package_selected.connect (package_selected);

        unowned var aggregator = AppCenterCore.BackendAggregator.get_default ();
        aggregator.bind_property ("working", this, "working", GLib.BindingFlags.SYNC_CREATE);

        notify["working"].connect (() => {
            Idle.add (() => {
                spinner.active = working;
                App.refresh_action.set_enabled (!working);
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

        var home_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("go-home", Gtk.IconSize.LARGE_TOOLBAR),
            tooltip_text = _("Home")
        };

        var updates_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("software-update-available", Gtk.IconSize.LARGE_TOOLBAR),
        };

        var badge_provider = new Gtk.CssProvider ();
        badge_provider.load_from_resource ("io/elementary/appcenter/badge.css");

        updates_badge = new Gtk.Label ("!");

        unowned var badge_context = updates_badge.get_style_context ();
        badge_context.add_class (Granite.STYLE_CLASS_BADGE);
        badge_context.add_provider (badge_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        updates_badge_revealer = new Gtk.Revealer () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.START,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        updates_badge_revealer.add (updates_badge);

        var eventbox_badge = new Gtk.EventBox () {
            halign = Gtk.Align.END
        };
        eventbox_badge.add (updates_badge_revealer);

        var updates_overlay = new Gtk.Overlay () {
            tooltip_text = C_("view", "Updates & installed apps")
        };
        updates_overlay.add (updates_button);
        updates_overlay.add_overlay (eventbox_badge);

        var view_mode_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        view_mode_box.add (home_button);
        view_mode_box.add (updates_overlay);

        view_mode_revealer = new Gtk.Revealer () {
            reveal_child = true,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        view_mode_revealer.add (view_mode_box);

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

        var automatic_updates_button = new Granite.SwitchModelButton (_("Automatic App Updates")) {
            description = _("System updates and unpaid apps will not update automatically")
        };

        var refresh_accellabel = new Granite.AccelLabel.from_action_name (
            _("Check for Updates"),
            "app.refresh"
        );

        refresh_menuitem = new Gtk.ModelButton () {
            action_name = "app.refresh"
        };
        refresh_menuitem.get_child ().destroy ();
        refresh_menuitem.add (refresh_accellabel);

        var menu_popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 6,
            margin_top = 6
        };
        menu_popover_box.add (automatic_updates_button);
        menu_popover_box.add (refresh_menuitem);
        menu_popover_box.show_all ();

        var menu_popover = new Gtk.Popover (null);
        menu_popover.add (menu_popover_box);

        var menu_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            popover = menu_popover,
            tooltip_text = _("Settings"),
            valign = Gtk.Align.CENTER
        };

        var headerbar = new Hdy.HeaderBar () {
            show_close_button = true
        };
        headerbar.set_custom_title (custom_title_stack);
        headerbar.pack_start (return_button);
        headerbar.pack_end (menu_button);
        headerbar.pack_end (search_entry);
        headerbar.pack_end (spinner);

        homepage = new Homepage ();
        installed_view = new Views.InstalledView ();

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        };
        stack.add (homepage);
        stack.add (installed_view);

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
        App.settings.bind (
            "automatic-updates",
            automatic_updates_button,
            "active",
            SettingsBindFlags.DEFAULT
        );

        if (window_x != -1 || window_y != -1) {
            move (window_x, window_y);
        }

        resize (window_width, window_height);

        if (App.settings.get_boolean ("window-maximized")) {
            maximize ();
        }

        stack.notify["visible-child"].connect (on_view_mode_changed);

        automatic_updates_button.notify["active"].connect (() => {
            if (automatic_updates_button.active) {
                AppCenterCore.Client.get_default ().update_cache.begin (true, AppCenterCore.Client.CacheUpdateType.FLATPAK);
            } else {
                AppCenterCore.Client.get_default ().cancel_updates (true);
            }
        });

        home_button.clicked.connect (() => {
            stack.visible_child = homepage;
        });

        updates_button.clicked.connect (() => {
            stack.visible_child = installed_view;
        });

        eventbox_badge.button_release_event.connect (() => {
            stack.visible_child = installed_view;
        });
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

    public void show_package (AppCenterCore.Package package) {
        stack.visible_child = homepage;
        homepage.show_package (package);
    }

    public void go_to_installed () {
        stack.visible_child = installed_view;
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
            homepage.search (query, mimetype);
        } else if (stack.visible_child == homepage) {
            homepage.search ("");
        }

        if (mimetype) {
            mimetype = false;
        }
    }

    private void package_selected (AppCenterCore.Package package) {
        selected_package = package;
    }

    public void set_return_name (string? return_name) {
        if (return_name != null) {
            return_button.label = return_name;
        }

        return_button.no_show_all = return_name == null;
        return_button.visible = return_name != null;
    }

    public void configure_search (bool sensitive, string? placeholder_text = _("Search Apps"), string? search_term = null) {
        search_entry.sensitive = sensitive;
        search_entry.placeholder_text = placeholder_text;

        if (search_term != null) {
            search_entry.text = "";
        }

        if (sensitive) {
            search_entry.grab_focus_without_selecting ();
        }
    }

    public void set_custom_header (string? custom_header) {
        if (custom_header != null) {
            homepage_header.label = custom_header;
            custom_title_stack.visible_child = homepage_header;
        } else {
            custom_title_stack.visible_child = view_mode_revealer;
        }
    }

    private void view_return () {
        selected_package = null;

        var view = (AbstractView) stack.visible_child;
        view.navigate (Hdy.NavigationDirection.BACK);
    }

    private void on_view_mode_changed () {
        if (stack.visible_child == homepage) {
            search_entry.sensitive = !homepage.viewing_package;
            view_mode_revealer.reveal_child = true;
        } else if (stack.visible_child == installed_view) {
            search_entry.sensitive = false;
        }
    }

    public void show_category (AppStream.Category category) {
        stack.visible_child = homepage;
        homepage.show_app_list_for_category (category);
    }

}
