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
    public bool working { get; set; }

    private AppCenter.SearchView search_view;
    private Gtk.Revealer view_mode_revealer;
    private Gtk.SearchEntry search_entry;
    private Gtk.Spinner spinner;
    private Gtk.Button refresh_menuitem;
    private Gtk.Button return_button;
    private Gtk.Label updates_badge;
    private Gtk.Revealer updates_badge_revealer;
    private Granite.Toast toast;
    private Adw.Leaflet leaflet;

    private AppCenterCore.Package? last_installed_package;
    private AppCenterCore.Package? selected_package;

    private bool mimetype;

    private const int VALID_QUERY_LENGTH = 3;

    public static Views.AppListUpdateView installed_view { get; private set; }

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        search_entry.grab_focus ();

        var go_back = new SimpleAction ("go-back", null);
        go_back.activate.connect (view_return);
        add_action (go_back);

        var focus_search = new SimpleAction ("focus-search", null);
        focus_search.activate.connect (() => search_entry.grab_focus ());
        add_action (focus_search);

        app.set_accels_for_action ("win.go-back", {"<Alt>Left", "Back"});
        app.set_accels_for_action ("win.focus-search", {"<Ctrl>f"});

        search_entry.search_changed.connect (() => trigger_search ());

        return_button.clicked.connect (view_return);

        unowned var aggregator = AppCenterCore.BackendAggregator.get_default ();
        aggregator.bind_property ("working", this, "working", GLib.BindingFlags.SYNC_CREATE);

        notify["working"].connect (() => {
            Idle.add (() => {
                spinner.spinning = working;
                App.refresh_action.set_enabled (!working);
                return GLib.Source.REMOVE;
            });
        });
    }

    construct {
        icon_name = Build.PROJECT_NAME;
        set_default_size (910, 640);
        height_request = 500;

        Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).add_resource_path ("/io/elementary/appcenter/icons");

        title = _(Build.APP_NAME);

        toast = new Granite.Toast ("");

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

                    message_dialog.present ();
                    message_dialog.response.connect ((response_id) => {
                        message_dialog.destroy ();
                    });
                }
            }
        });

        return_button = new Gtk.Button () {
            valign = Gtk.Align.CENTER,
            visible = false
        };
        return_button.add_css_class (Granite.STYLE_CLASS_BACK_BUTTON);

        var updates_button = new Gtk.Button.from_icon_name ("software-update-available");
        updates_button.add_css_class ("large-icons");

        var badge_provider = new Gtk.CssProvider ();
        badge_provider.load_from_resource ("io/elementary/appcenter/badge.css");

        updates_badge = new Gtk.Label ("!");

        unowned var badge_context = updates_badge.get_style_context ();
        badge_context.add_class (Granite.STYLE_CLASS_BADGE);
        badge_context.add_provider (badge_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        updates_badge_revealer = new Gtk.Revealer () {
            can_target = false,
            child = updates_badge,
            halign = Gtk.Align.END,
            valign = Gtk.Align.START,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };

        var updates_overlay = new Gtk.Overlay () {
            child = updates_button,
            tooltip_text = C_("view", "Updates & installed apps")
        };
        updates_overlay.add_overlay (updates_badge_revealer);

        view_mode_revealer = new Gtk.Revealer () {
            child = updates_overlay,
            reveal_child = true,
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT
        };

        var search_entry_eventcontrollerkey = new Gtk.EventControllerKey ();

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search Apps"),
            valign = Gtk.Align.CENTER
        };
        search_entry.add_controller (search_entry_eventcontrollerkey);

        var search_clamp = new Adw.Clamp () {
            child = search_entry
        };

        spinner = new Gtk.Spinner ();

        var automatic_updates_button = new Granite.SwitchModelButton (_("Automatic App Updates")) {
            description = _("System updates and unpaid apps will not update automatically")
        };

        var refresh_accellabel = new Granite.AccelLabel.from_action_name (
            _("Check for Updates"),
            "app.refresh"
        );

        refresh_menuitem = new Gtk.Button () {
            action_name = "app.refresh",
            child = refresh_accellabel
        };
        refresh_menuitem.add_css_class (Granite.STYLE_CLASS_MENUITEM);

        var menu_popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        menu_popover_box.append (automatic_updates_button);
        menu_popover_box.append (refresh_menuitem);

        var menu_popover = new Gtk.Popover () {
            child = menu_popover_box
        };
        menu_popover.add_css_class (Granite.STYLE_CLASS_MENU);

        var menu_button = new Gtk.MenuButton () {
            icon_name = "open-menu",
            popover = menu_popover,
            tooltip_text = _("Settings"),
            valign = Gtk.Align.CENTER
        };
        menu_button.add_css_class ("large-icons");

        var headerbar = new Gtk.HeaderBar () {
            show_title_buttons = true,
            title_widget = search_clamp
        };
        headerbar.pack_start (return_button);
        headerbar.pack_end (menu_button);
        headerbar.pack_end (view_mode_revealer);
        headerbar.pack_end (spinner);

        var homepage = new Homepage ();
        installed_view = new Views.AppListUpdateView () {
            name = "installed-view"
        };

        leaflet = new Adw.Leaflet () {
            can_navigate_back = true,
            can_unfold = false
        };
        leaflet.append (homepage);

        var overlay = new Gtk.Overlay () {
            child = leaflet
        };
        overlay.add_overlay (toast);

        var network_info_bar_label = new Gtk.Label ("<b>%s</b> %s".printf (
            _("Network Not Available."),
            _("Connect to the Internet to browse and install apps.")
        )) {
            use_markup = true,
            wrap = true
        };

        var network_info_bar = new Gtk.InfoBar () {
            message_type = Gtk.MessageType.WARNING
        };
        network_info_bar.add_child (network_info_bar_label);
        network_info_bar.add_button (_("Network Settings…"), Gtk.ResponseType.ACCEPT);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (network_info_bar);
        box.append (overlay);

        child = box;
        set_titlebar (headerbar);

        App.settings.bind (
            "automatic-updates",
            automatic_updates_button,
            "active",
            SettingsBindFlags.DEFAULT
        );

        automatic_updates_button.notify["active"].connect (() => {
            if (automatic_updates_button.active) {
                AppCenterCore.Client.get_default ().update_cache.begin (true, AppCenterCore.Client.CacheUpdateType.FLATPAK);
            } else {
                AppCenterCore.Client.get_default ().cancel_updates (true);
            }
        });

        var network_monitor = NetworkMonitor.get_default ();
        network_monitor.bind_property ("network-available", network_info_bar, "revealed", BindingFlags.INVERT_BOOLEAN | BindingFlags.SYNC_CREATE);

        network_info_bar.response.connect (() => {
            try {
                Gtk.show_uri (this, "settings://network", Gdk.CURRENT_TIME);
            } catch (GLib.Error e) {
                critical (e.message);
            }
        });

        updates_button.clicked.connect (() => {
            go_to_installed ();
        });

        homepage.show_category.connect ((category) => {
            show_category (category);
        });

        homepage.show_package.connect ((package) => {
            show_package (package);
        });

        installed_view.show_app.connect ((package) => {
            show_package (package);
        });

        leaflet.notify["visible-child"].connect (() => {
            if (!leaflet.child_transition_running) {
                update_navigation ();
            }
        });

        leaflet.notify["child-transition-running"].connect (() => {
            if (!leaflet.child_transition_running) {
                update_navigation ();
            }
        });


        search_entry_eventcontrollerkey.key_released.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.Down:
                    search_entry.move_focus (Gtk.DirectionType.TAB_FORWARD);
                    break;
                case Gdk.Key.Escape:
                    search_entry.text = "";
                    break;
                default:
                    break;
            }
        });
    }

    public override bool close_request () {
       installed_view.clear ();

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

    public void show_package (AppCenterCore.Package package, bool remember_history = true) {
        if (leaflet.child_transition_running) {
            return;
        }

        selected_package = package;

        var package_hash = package.hash;

        var pk_child = leaflet.get_child_by_name (package_hash) as Views.AppInfoView;
        if (pk_child != null && pk_child.to_recycle) {
            // Don't switch to a view that needs recycling
            pk_child.destroy ();
            pk_child = null;
        }

        if (pk_child != null) {
            pk_child.view_entered ();
            leaflet.visible_child = pk_child;
            return;
        }

        var app_info_view = new Views.AppInfoView (package);

        leaflet.append (app_info_view);
        leaflet.visible_child = app_info_view;

        app_info_view.show_other_package.connect ((_package, remember_history, transition) => {
            if (!transition) {
                leaflet.mode_transition_duration = 0;
            }

            show_package (_package, remember_history);
            if (remember_history) {
                set_return_name (package.get_name ());
            }
            leaflet.mode_transition_duration = 200;
        });
    }

    private void update_navigation () {
        var previous_child = leaflet.get_adjacent_child (Adw.NavigationDirection.BACK);

        if (leaflet.visible_child is Homepage) {
            view_mode_revealer.reveal_child = true;
            configure_search (true, _("Search Apps"), "");
        } else if (leaflet.visible_child is CategoryView) {
            var current_category = ((CategoryView) leaflet.visible_child).category;
            view_mode_revealer.reveal_child = false;
            configure_search (true, _("Search %s").printf (current_category.name), "");
        } else if (leaflet.visible_child == search_view) {
            if (previous_child is CategoryView) {
                var previous_category = ((CategoryView) previous_child).category;
                configure_search (true, _("Search %s").printf (previous_category.name));
                view_mode_revealer.reveal_child = false;
            } else {
                configure_search (true);
                view_mode_revealer.reveal_child = true;
            }
        } else if (leaflet.visible_child is Views.AppInfoView) {
            view_mode_revealer.reveal_child = false;
            configure_search (false);
        } else if (leaflet.visible_child is Views.AppListUpdateView) {
            view_mode_revealer.reveal_child = true;
            configure_search (false);
        }

        if (previous_child == null) {
            set_return_name (null);
        } else if (previous_child is Homepage) {
            set_return_name (_("Home"));
        } else if (previous_child == search_view) {
            /// TRANSLATORS: the name of the Search view
            set_return_name (C_("view", "Search"));
        } else if (previous_child is Views.AppInfoView) {
            set_return_name (((Views.AppInfoView) previous_child).package.get_name ());
        } else if (previous_child is CategoryView) {
            set_return_name (((CategoryView) previous_child).category.name);
        } else if (previous_child is Views.AppListUpdateView) {
            set_return_name (C_("view", "Installed"));
        }

        while (leaflet.get_adjacent_child (Adw.NavigationDirection.FORWARD) != null) {
            var next_child = leaflet.get_adjacent_child (Adw.NavigationDirection.FORWARD);
            leaflet.remove (next_child);

            if (!(next_child is AppCenter.Views.AppListUpdateView)) {
                next_child.destroy ();
            }
        }
    }

    public void go_to_installed () {
        if (leaflet.get_child_by_name ("installed-view") == null) {
            leaflet.append (installed_view);
        }

        leaflet.visible_child = installed_view;
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
        unowned string search_term = search_entry.text;
        uint query_length = search_term.length;
        bool query_valid = query_length >= VALID_QUERY_LENGTH;

        view_mode_revealer.reveal_child = !query_valid;

        if (query_valid) {
            if (leaflet.visible_child != search_view) {
                search_view = new AppCenter.SearchView ();

                search_view.show_app.connect ((package) => {
                    show_package (package);
                });

                leaflet.append (search_view);
                leaflet.visible_child = search_view;
            }

            search_view.clear ();
            search_view.current_search_term = search_term;

            unowned var client = AppCenterCore.Client.get_default ();

            Gee.Collection<AppCenterCore.Package> found_apps;

            if (mimetype) {
                found_apps = client.search_applications_mime (search_term);
                search_view.add_packages (found_apps);
            } else {
                AppStream.Category current_category = null;

                var previous_child = leaflet.get_adjacent_child (Adw.NavigationDirection.BACK);
                if (previous_child is CategoryView) {
                    current_category = ((CategoryView) previous_child).category;
                }

                found_apps = client.search_applications (search_term, current_category);
                search_view.add_packages (found_apps);
            }

        } else {
            // Prevent navigating away from category views when backspacing
            if (leaflet.visible_child == search_view) {
                leaflet.navigate (Adw.NavigationDirection.BACK);
            }
        }

        if (mimetype) {
            mimetype = false;
        }
    }

    private void set_return_name (string? return_name) {
        if (return_name != null) {
            return_button.label = return_name;
        }

        return_button.visible = return_name != null;
    }

    private void configure_search (bool sensitive, string? placeholder_text = _("Search Apps"), string? search_term = null) {
        search_entry.sensitive = sensitive;
        search_entry.placeholder_text = placeholder_text;

        if (search_term != null) {
            search_entry.text = "";
        }

        if (sensitive) {
            search_entry.grab_focus ();
        }
    }

    private void view_return () {
        selected_package = null;
        leaflet.navigate (Adw.NavigationDirection.BACK);
    }

    private void show_category (AppStream.Category category) {
        var child = leaflet.get_child_by_name (category.name);
        if (child != null) {
            leaflet.visible_child = child;
            return;
        }

        var category_view = new CategoryView (category);

        leaflet.append (category_view);
        leaflet.visible_child = category_view;

        category_view.show_app.connect ((package) => {
            show_package (package);
            set_return_name (category.name);
        });
    }
}
