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

    private Granite.Toast toast;
    private Granite.OverlayBar overlaybar;
    private Adw.NavigationView navigation_view;

    private AppCenterCore.Package? last_installed_package;

    public static Views.AppListUpdateView installed_view { get; private set; }

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        var go_back = new SimpleAction ("go-back", null);
        go_back.activate.connect (() => navigation_view.pop ());
        add_action (go_back);

        var focus_search = new SimpleAction ("search", null);
        focus_search.activate.connect (() => search ());
        add_action (focus_search);

        app.set_accels_for_action ("win.search", {"<Ctrl>f"});

        unowned var backend = AppCenterCore.FlatpakBackend.get_default ();
        backend.bind_property ("working", this, "working", GLib.BindingFlags.SYNC_CREATE);
        backend.bind_property ("working", overlaybar, "active", GLib.BindingFlags.SYNC_CREATE);

        backend.notify ["job-type"].connect (() => {
            update_overlaybar_label (backend.job_type);
        });

        notify["working"].connect (() => {
            Idle.add (() => {
                App.refresh_action.set_enabled (!working && !Utils.is_running_in_guest_session ());
                App.repair_action.set_enabled (!working);
                return GLib.Source.REMOVE;
            });
        });

        update_overlaybar_label (backend.job_type);
    }

    construct {
        icon_name = Build.PROJECT_NAME;
        set_default_size (910, 640);
        height_request = 500;

        title = _("AppCenter");

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

        var homepage = new Homepage ();
        installed_view = new Views.AppListUpdateView ();

        navigation_view = new Adw.NavigationView ();
        navigation_view.add (homepage);
        navigation_view.add (installed_view);

        var overlay = new Gtk.Overlay () {
            child = navigation_view
        };
        overlay.add_overlay (toast);

        overlaybar = new Granite.OverlayBar (overlay);
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
        network_info_bar.add_child (network_info_bar_label);
        network_info_bar.add_button (_("Network Settings…"), Gtk.ResponseType.ACCEPT);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (overlay);
        box.append (network_info_bar);

        if (Utils.is_running_in_demo_mode ()) {
            var demo_mode_info_bar_label = new Gtk.Label ("<b>%s</b> %s".printf (
                _("Running in Demo Mode"),
                _("Install %s to browse and install apps.").printf (Environment.get_os_info (GLib.OsInfoKey.NAME))
            )) {
                use_markup = true,
                wrap = true
            };

            var demo_mode_info_bar = new Gtk.InfoBar () {
                message_type = WARNING
            };
            demo_mode_info_bar.add_child (demo_mode_info_bar_label);

            box.append (demo_mode_info_bar);
        }

        child = box;
        titlebar = new Gtk.Grid () { visible = false };

        var network_monitor = NetworkMonitor.get_default ();
        network_monitor.bind_property ("network-available", network_info_bar, "revealed", BindingFlags.INVERT_BOOLEAN | BindingFlags.SYNC_CREATE);

        network_info_bar.response.connect (() => {
            new Gtk.UriLauncher ("settings://network").launch.begin (this, null);
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

        navigation_view.popped.connect (update_navigation);
        navigation_view.pushed.connect (update_navigation);
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

            AppCenterCore.UpdateManager.get_default ().cancel_updates (false); //Timeouts keep running
            return true;
        }

        ((AppCenter.App) application).request_background.begin (() => destroy ());

        return false;
    }

    public void show_package (AppCenterCore.Package package) {
        var pk_child = navigation_view.find_page (package.hash);
        if (pk_child != null) {
            navigation_view.pop_to_page (pk_child);
            return;
        }

        // Remove old pages when switching package origins
        if (navigation_view.visible_page is Views.AppInfoView) {
            var visible_page = (Views.AppInfoView) navigation_view.visible_page;
            if (visible_page.package.normalized_component_id == package.normalized_component_id) {
                navigation_view.animate_transitions = false;
                navigation_view.pop ();
            }
        }

        var app_info_view = new Views.AppInfoView (package);
        navigation_view.push (app_info_view);
        navigation_view.animate_transitions = true;

        app_info_view.show_other_package.connect (show_package);
    }

    private void update_navigation () {
        ((SimpleAction) lookup_action ("search")).set_enabled (!(navigation_view.visible_page is SearchView));
    }

    public void go_to_installed () {
        navigation_view.push (installed_view);
    }

    public void search (string term = "", bool mimetype = false) {
        var search_view = new AppCenter.SearchView (term) {
            mimetype = mimetype
        };

        search_view.show_app.connect ((package) => {
            show_package (package);
        });

        navigation_view.push (search_view);
    }

    public void send_installed_toast (AppCenterCore.Package package) {
        last_installed_package = package;

        // Only show a toast when we're not on the installed app's page
        if (navigation_view.visible_page is Views.AppInfoView && ((Views.AppInfoView) navigation_view.visible_page).package == package) {
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

    private void show_category (AppStream.Category category) {
        var category_view = new CategoryView (category);

        navigation_view.push (category_view);

        category_view.show_app.connect ((package) => {
            show_package (package);
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
