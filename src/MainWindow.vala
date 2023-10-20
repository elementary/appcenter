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
    public const int VALID_QUERY_LENGTH = 3;

    public bool working { get; set; }

    private AppCenter.SearchView search_view;
    private Gtk.EventControllerKey search_entry_eventcontrollerkey;
    private Gtk.Revealer view_mode_revealer;
    private Gtk.SearchEntry search_entry;
    private Gtk.ModelButton refresh_menuitem;
    private Gtk.Button return_button;
    private Gtk.Label updates_badge;
    private Gtk.Revealer updates_badge_revealer;
    private Granite.Widgets.Toast toast;
    private Granite.Widgets.OverlayBar overlaybar;
    private Hdy.Deck deck;

    private AppCenterCore.Package? last_installed_package;

    private uint configure_id;

    private bool mimetype;

    public static Views.AppListUpdateView installed_view { get; private set; }

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        search_entry.grab_focus_without_selecting ();

        var go_back = new SimpleAction ("go-back", null);
        go_back.activate.connect (() => deck.navigate (BACK));
        add_action (go_back);

        var focus_search = new SimpleAction ("focus-search", null);
        focus_search.activate.connect (() => search_entry.grab_focus ());
        add_action (focus_search);

        app.set_accels_for_action ("win.go-back", {"<Alt>Left", "Back"});
        app.set_accels_for_action ("win.focus-search", {"<Ctrl>f"});

        button_release_event.connect ((event) => {
            // On back mouse button pressed
            if (event.button == 8) {
                deck.navigate (BACK);
                return true;
            }

            return false;
        });

        search_entry.search_changed.connect (() => trigger_search ());

        unowned var aggregator = AppCenterCore.BackendAggregator.get_default ();
        aggregator.bind_property ("working", this, "working", GLib.BindingFlags.SYNC_CREATE);
        aggregator.bind_property ("working", overlaybar, "active", GLib.BindingFlags.SYNC_CREATE);

        aggregator.notify ["job-type"].connect (() => {
            update_overlaybar_label (aggregator.job_type);
        });

        notify["working"].connect (() => {
            Idle.add (() => {
                App.refresh_action.set_enabled (!working);
                App.repair_action.set_enabled (!working);
                return GLib.Source.REMOVE;
            });
        });

        update_overlaybar_label (aggregator.job_type);
    }

    construct {
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

                    message_dialog.present ();
                    message_dialog.response.connect ((response_id) => {
                        message_dialog.destroy ();
                    });
                }
            }
        });

        return_button = new Gtk.Button () {
            action_name = "win.go-back",
            no_show_all = true,
            valign = Gtk.Align.CENTER
        };
        return_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

        var updates_button = new Gtk.Button.from_icon_name ("software-update-available", Gtk.IconSize.LARGE_TOOLBAR);

        var badge_provider = new Gtk.CssProvider ();
        badge_provider.load_from_resource ("io/elementary/appcenter/badge.css");

        updates_badge = new Gtk.Label ("!");

        unowned var badge_context = updates_badge.get_style_context ();
        badge_context.add_class (Granite.STYLE_CLASS_BADGE);
        badge_context.add_provider (badge_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        updates_badge_revealer = new Gtk.Revealer () {
            child = updates_badge,
            halign = Gtk.Align.END,
            valign = Gtk.Align.START,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };

        var eventbox_badge = new Gtk.EventBox () {
            child = updates_badge_revealer,
            halign = Gtk.Align.END
        };

        var updates_overlay = new Gtk.Overlay () {
            child = updates_button,
            tooltip_text = C_("view", "Updates & installed apps")
        };
        updates_overlay.add_overlay (eventbox_badge);

        view_mode_revealer = new Gtk.Revealer () {
            child = updates_overlay,
            reveal_child = true,
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT
        };

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search Apps"),
            valign = Gtk.Align.CENTER
        };

        search_entry_eventcontrollerkey = new Gtk.EventControllerKey (search_entry);

        var search_clamp = new Hdy.Clamp () {
            child = search_entry
        };

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

        var menu_popover = new Gtk.Popover (null) {
            child = menu_popover_box
        };

        var menu_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            popover = menu_popover,
            tooltip_text = _("Settings"),
            valign = Gtk.Align.CENTER
        };

        var headerbar = new Hdy.HeaderBar () {
            show_close_button = true
        };
        headerbar.set_custom_title (search_clamp);
        headerbar.pack_start (return_button);
        headerbar.pack_end (menu_button);
        headerbar.pack_end (view_mode_revealer);

        var homepage = new Homepage ();
        installed_view = new Views.AppListUpdateView ();

        deck = new Hdy.Deck () {
            can_swipe_back = true
        };
        deck.add (homepage);

        var overlay = new Gtk.Overlay () {
            child = deck
        };
        overlay.add_overlay (toast);

        overlaybar = new Granite.Widgets.OverlayBar (overlay);
        overlaybar.bind_property ("active", overlaybar, "visible");

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
        network_info_bar.get_content_area ().add (network_info_bar_label);
        network_info_bar.add_button (_("Network Settings…"), Gtk.ResponseType.ACCEPT);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.add (headerbar);
        box.add (network_info_bar);

        if (Utils.is_running_in_demo_mode ()) {
            var demo_mode_info_bar_label = new Gtk.Label ("<b>%s</b> %s".printf (
                _("Running in Demo Mode"),
                _("Install %s to browse and install apps.").printf (Environment.get_os_info (GLib.OsInfoKey.NAME))
            )) {
                use_markup = true,
                wrap = true
            };

            var demo_mode_info_bar = new Gtk.InfoBar () {
                message_type = Gtk.MessageType.WARNING
            };
            demo_mode_info_bar.get_content_area ().add (demo_mode_info_bar_label);

            box.add (demo_mode_info_bar);
        }

        box.add (overlay);
        box.show_all ();

        child = box;

        App.settings.bind (
            "automatic-updates",
            automatic_updates_button,
            "active",
            SettingsBindFlags.DEFAULT
        );

        var client = AppCenterCore.Client.get_default ();

        automatic_updates_button.notify["active"].connect (() => {
            if (automatic_updates_button.active) {
                client.update_cache.begin (true, AppCenterCore.Client.CacheUpdateType.FLATPAK);
            } else {
                client.cancel_updates (true);
            }
        });

        client.notify["updates-number"].connect (() => {
            show_update_badge (client.updates_number);
        });

        var network_monitor = NetworkMonitor.get_default ();
        network_monitor.bind_property ("network-available", network_info_bar, "revealed", BindingFlags.INVERT_BOOLEAN | BindingFlags.SYNC_CREATE);

        network_info_bar.response.connect (() => {
            try {
                Gtk.show_uri_on_window (this, "settings://network", Gdk.CURRENT_TIME);
            } catch (GLib.Error e) {
                critical (e.message);
            }
        });

        updates_button.clicked.connect (() => {
            go_to_installed ();
        });

        eventbox_badge.button_release_event.connect (() => {
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

        deck.notify["visible-child"].connect (() => {
            if (!deck.transition_running) {
                update_navigation ();
            }
        });

        deck.notify["transition-running"].connect (() => {
            if (!deck.transition_running) {
                update_navigation ();
            }
        });

        search_entry_eventcontrollerkey.key_released.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.Down:
                    search_entry.move_focus (TAB_FORWARD);
                    break;
                case Gdk.Key.Escape:
                    search_entry.text = "";
                    break;
                default:
                    break;
            }
        });

        delete_event.connect (() => {
            ((AppCenter.App) application).request_background.begin (() => destroy ());

            return Gdk.EVENT_STOP;
        });
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id == 0) {
            /* Avoid spamming the settings */
            configure_id = Timeout.add (200, () => {
                configure_id = 0;

                App.settings.set_boolean ("window-maximized", is_maximized);

                if (!is_maximized) {
                    int width, height;
                    get_size (out width, out height);
                    App.settings.set_int ("window-height", height);
                    App.settings.set_int ("window-width", width);
                }

                return GLib.Source.REMOVE;
            });
        }

        return base.configure_event (event);
    }

    public override bool delete_event (Gdk.EventAny event) {
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

    private void show_update_badge (uint updates_number) {
        Idle.add (() => {
            if (updates_number == 0U) {
                updates_badge_revealer.reveal_child = false;
            } else {
                updates_badge.label = updates_number.to_string ();
                updates_badge_revealer.reveal_child = true;
            }

            return GLib.Source.REMOVE;
        });
    }

    public void show_package (AppCenterCore.Package package, bool remember_history = true) {
        if (deck.transition_running) {
            return;
        }

        var package_hash = package.hash;

        var pk_child = deck.get_child_by_name (package_hash) as Views.AppInfoView;
        if (pk_child != null && pk_child.to_recycle) {
            // Don't switch to a view that needs recycling
            pk_child.destroy ();
            pk_child = null;
        }

        if (pk_child != null) {
            pk_child.view_entered ();
            deck.visible_child = pk_child;
            return;
        }

        var app_info_view = new Views.AppInfoView (package);
        app_info_view.show_all ();

        deck.add (app_info_view);
        deck.visible_child = app_info_view;

        if (deck.get_adjacent_child (BACK) is Views.AppInfoView) {
            var adjacent_app_info_view = (Views.AppInfoView)deck.get_adjacent_child (BACK);
            if (
                !remember_history &&
                adjacent_app_info_view.package.normalized_component_id == package.normalized_component_id
            ) {
                deck.remove (adjacent_app_info_view);
                update_navigation ();
            }
        }

        app_info_view.show_other_package.connect ((_package, remember_history, transition) => {
            if (!transition) {
                deck.transition_duration = 0;
            }

            show_package (_package, remember_history);

            deck.transition_duration = 200;
        });
    }

    private void update_navigation () {
        var previous_child = deck.get_adjacent_child (BACK);

        if (deck.visible_child is Homepage) {
            view_mode_revealer.reveal_child = true;
            configure_search (true, _("Search Apps"), "");
        } else if (deck.visible_child is CategoryView) {
            var current_category = ((CategoryView) deck.visible_child).category;
            view_mode_revealer.reveal_child = false;
            configure_search (true, _("Search %s").printf (current_category.name), "");
        } else if (deck.visible_child == search_view) {
            if (previous_child is CategoryView) {
                var previous_category = ((CategoryView) previous_child).category;
                configure_search (true, _("Search %s").printf (previous_category.name));
                view_mode_revealer.reveal_child = false;
            } else {
                configure_search (true);
                view_mode_revealer.reveal_child = true;
            }
        } else if (deck.visible_child is Views.AppInfoView) {
            view_mode_revealer.reveal_child = false;
            configure_search (false);
        } else if (deck.visible_child is Views.AppListUpdateView) {
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

        while (deck.get_adjacent_child (FORWARD) != null) {
            var next_child = deck.get_adjacent_child (FORWARD);
            if (next_child is AppCenter.Views.AppListUpdateView) {
                deck.remove (next_child);
            } else {
                next_child.destroy ();
            }
        }
    }

    public void go_to_installed () {
        if (installed_view.parent == null) {
            deck.add (installed_view);
        }
        installed_view.show_all ();
        deck.visible_child = installed_view;
    }

    public void search (string term, bool mimetype = false) {
        this.mimetype = mimetype;
        search_entry.text = term;
    }

    public void send_installed_toast (AppCenterCore.Package package) {
        last_installed_package = package;

        // Only show a toast when we're not on the installed app's page
        if (deck.visible_child is Views.AppInfoView && ((Views.AppInfoView) deck.visible_child).package == package) {
            return;
        }

        toast.title = _("“%s” has been installed").printf (package.get_name ());
        // Show Open only when a desktop app is installed
        if (package.component.get_kind () == AppStream.ComponentKind.DESKTOP_APP) {
            toast.set_default_action (_("Open"));
        } else {
            toast.set_default_action (null);
        }

        toast.send_notification ();
    }

    private void trigger_search () {
        unowned string search_term = search_entry.text;
        uint query_length = search_term.length;
        bool query_valid = query_length >= VALID_QUERY_LENGTH;

        view_mode_revealer.reveal_child = !query_valid;

        if (query_valid) {
            if (deck.visible_child != search_view) {
                search_view = new AppCenter.SearchView ();
                search_view.show_all ();

                search_view.show_app.connect ((package) => {
                    show_package (package);
                });

                deck.add (search_view);
                deck.visible_child = search_view;
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

                var previous_child = deck.get_adjacent_child (BACK);
                if (previous_child is CategoryView) {
                    current_category = ((CategoryView) previous_child).category;
                }

                found_apps = client.search_applications (search_term, current_category);
                search_view.add_packages (found_apps);
            }

        } else {
            // Prevent navigating away from category views when backspacing
            if (deck.visible_child == search_view) {
                search_view.clear ();
                search_view.current_search_term = search_entry.text;

                // When replacing text with text don't go back
                Idle.add (() => {
                    if (search_entry.text.length == 0) {
                        deck.navigate (BACK);
                    }

                    return Source.REMOVE;
                });
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

        return_button.no_show_all = return_name == null;
        return_button.visible = return_name != null;
    }

    private void configure_search (bool sensitive, string? placeholder_text = _("Search Apps"), string? search_term = null) {
        search_entry.sensitive = sensitive;
        search_entry.placeholder_text = placeholder_text;

        if (search_term != null) {
            search_entry.text = "";
        }

        if (sensitive) {
            search_entry.grab_focus_without_selecting ();
        }
    }

    private void show_category (AppStream.Category category) {
        var child = deck.get_child_by_name (category.name);
        if (child != null) {
            deck.visible_child = child;
            return;
        }

        var category_view = new CategoryView (category);

        deck.add (category_view);
        deck.visible_child = category_view;

        category_view.show_app.connect ((package) => {
            show_package (package);
            set_return_name (category.name);
        });
    }

    private void update_overlaybar_label (AppCenterCore.Job.Type job_type) {
        switch (job_type) {
            case GET_DETAILS_FOR_PACKAGE_IDS:
            case GET_PACKAGE_DEPENDENCIES:
            case GET_PACKAGE_DETAILS:
            case IS_PACKAGE_INSTALLED:
                overlaybar.label = _("Getting app information…");
                break;
            case GET_DOWNLOAD_SIZE:
                overlaybar.label = _("Getting download size…");
                break;
            case GET_PREPARED_PACKAGES:
            case GET_INSTALLED_PACKAGES:
            case GET_UPDATES:
            case REFRESH_CACHE:
                overlaybar.label = _("Checking for updates…");
                break;
            case INSTALL_PACKAGE:
                overlaybar.label = _("Installing…");
                break;
            case UPDATE_PACKAGE:
                overlaybar.label = _("Installing updates…");
                break;
            case REMOVE_PACKAGE:
                overlaybar.label = _("Uninstalling…");
                break;
            case REPAIR:
                overlaybar.label = _("Repairing…");
                break;
        }
    }
}
