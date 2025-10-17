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
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_SHOW_PACKAGE = "show-package";

    private Granite.Toast toast;
    private Adw.NavigationView navigation_view;
    private Granite.OverlayBar overlaybar;

    private AppCenterCore.Package? last_installed_package;

    private Views.AppListUpdateView? installed_view;

    public MainWindow (Gtk.Application app) {
        Object (application: app);

        var focus_search = new SimpleAction ("search", null);
        focus_search.activate.connect (() => search ());
        add_action (focus_search);

        app.set_accels_for_action ("win.search", {"<Ctrl>f"});
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
                    warning ("Failed to launch %s: %s".printf (last_installed_package.name, e.message));

                    var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                        _("Failed to launch “%s“").printf (last_installed_package.name),
                        e.message,
                        "system-software-install",
                        Gtk.ButtonsType.CLOSE
                    );
                    message_dialog.badge_icon = new ThemedIcon ("dialog-error");
                    message_dialog.transient_for = this;

                    message_dialog.present ();
                    message_dialog.response.connect ((dialog, response_id) => {
                        dialog.destroy ();
                    });
                }
            }
        });

        var homepage = new Homepage ();

        navigation_view = new Adw.NavigationView ();
        navigation_view.add (homepage);

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

        var show_package_action = new SimpleAction (ACTION_SHOW_PACKAGE, VariantType.STRING);
        show_package_action.activate.connect (on_show_package);
        add_action (show_package_action);

        var network_monitor = NetworkMonitor.get_default ();
        network_monitor.bind_property ("network-available", network_info_bar, "revealed", BindingFlags.INVERT_BOOLEAN | BindingFlags.SYNC_CREATE);

        network_info_bar.response.connect (() => {
            new Gtk.UriLauncher ("settings://network").launch.begin (this, null);
        });

        homepage.show_category.connect ((category) => {
            show_category (category);
        });

        navigation_view.popped.connect (update_navigation);
        navigation_view.pushed.connect (update_navigation);

        unowned var backend = AppCenterCore.FlatpakBackend.get_default ();
        backend.bind_property ("working", overlaybar, "active", SYNC_CREATE);

        backend.notify["job-type"].connect (update_overlaybar_label);

        overlaybar.label = backend.job_type.to_string ();

        if (installed_view == null) {
            installed_view = new Views.AppListUpdateView ();
        }
    }

    public override bool close_request () {
        if (installed_view != null) {
            installed_view.clear ();
        }

        // We have to wrap in Idle otherwise we crash because libportal hasn't unexported us yet.
        ((AppCenter.App) application).request_background.begin (() =>
            Idle.add_once (() => destroy ())
        );

        return true;
    }

    private void on_show_package (SimpleAction action, Variant? param) {
        var uid = param.get_string ();
        var package = AppCenterCore.FlatpakBackend.get_default ().get_package_by_uid (uid);

        if (package != null) {
            show_package (package);
        }
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

        navigation_view.push (new Views.AppInfoView (package));
        navigation_view.animate_transitions = true;
    }

    private void update_navigation () {
        ((SimpleAction) lookup_action ("search")).set_enabled (!(navigation_view.visible_page is SearchView));
    }

    public void go_to_installed () {
        if (installed_view.parent != null) {
            navigation_view.pop_to_page (installed_view);
        } else {
            navigation_view.push (installed_view);
        }
    }

    public void search (string term = "", bool mimetype = false) {
        var search_view = new AppCenter.SearchView (term) {
            mimetype = mimetype
        };

        navigation_view.push (search_view);
    }

    public void send_installed_toast (AppCenterCore.Package package) {
        last_installed_package = package;

        // Only show a toast when we're not on the installed app's page
        if (navigation_view.visible_page is Views.AppInfoView && ((Views.AppInfoView) navigation_view.visible_page).package == package) {
            return;
        }

        toast.title = _("“%s” has been installed").printf (package.name);
        // Show Open only when a desktop app is installed
        if (package.component.get_kind () == AppStream.ComponentKind.DESKTOP_APP) {
            toast.set_default_action (_("Open"));
        } else {
            toast.set_default_action (null);
        }

        toast.send_notification ();
    }

    private void update_overlaybar_label () {
        overlaybar.label = AppCenterCore.FlatpakBackend.get_default ().job_type.to_string ();
    }

    private void show_category (AppStream.Category category) {
        navigation_view.push (new CategoryView (category));
    }
}
