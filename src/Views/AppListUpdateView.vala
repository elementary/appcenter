/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014-2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Jeremy Wootten <jeremy@elementaryos.org>
 */

/** AppList for the Updates View. Sorts update_available first and shows headers.
 * Does not show Uninstall Button **/
public class AppCenter.Views.AppListUpdateView : Adw.NavigationPage {
    public signal void show_app (AppCenterCore.Package package);

    private Granite.HeaderLabel header_label;
    private Gtk.FlowBox installed_flowbox;
    private Gtk.ListBox list_box;
    private Gtk.Revealer header_revealer;
    private Gtk.Revealer updated_revealer;
    private Gtk.Label updated_label;
    private Gtk.SizeGroup action_button_group;
    private Granite.HeaderLabel installed_header;

    private uint updated_label_timeout_id = 0;

    construct {
        var update_manager = AppCenterCore.UpdateManager.get_default ();
        unowned var flatpak_backend = AppCenterCore.FlatpakBackend.get_default ();

        header_label = new Granite.HeaderLabel ("") {
            hexpand = true,
            valign = CENTER
        };
        flatpak_backend.bind_property (
            "n-updatable-packages", header_label, "label", SYNC_CREATE,
            (binding, from_value, ref to_value) => {
                var n_updatable_packages = from_value.get_uint ();

                to_value.set_string (ngettext (
                    "%u Update Available",
                    "%u Updates Available",
                    n_updatable_packages
                ).printf (n_updatable_packages));

                return true;
            }
        );

        var size_label = new Widgets.SizeLabel () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER
        };
        flatpak_backend.bind_property ("updates-size", size_label, "size", SYNC_CREATE);

        updated_label = new Gtk.Label ("");
        updated_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var updated_box = new Gtk.Box (HORIZONTAL, 6);
        updated_box.append (new Gtk.Image.from_icon_name ("process-completed-symbolic"));
        updated_box.append (updated_label);

        updated_revealer = new Gtk.Revealer () {
            child = updated_box
        };
        updated_revealer.add_css_class ("header");
        flatpak_backend.bind_property (
            "up-to-date", updated_revealer, "reveal-child", SYNC_CREATE
        );

        var update_all_button = new Gtk.Button.with_label (_("Update All")) {
            valign = Gtk.Align.CENTER,
            action_name = "app.update-all"
        };
        update_all_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);

        var header = new Gtk.Box (HORIZONTAL, 16);
        header.append (header_label);
        header.append (size_label);
        header.append (update_all_button);

        header_revealer = new Gtk.Revealer () {
            child = header
        };
        header_revealer.add_css_class ("header");
        flatpak_backend.bind_property (
            "has-updatable-packages", header_revealer, "reveal-child", SYNC_CREATE
        );

        list_box = new Gtk.ListBox () {
            activate_on_single_click = true,
            hexpand = true,
        };
        list_box.bind_model (flatpak_backend.updatable_packages, create_row_from_package);

        installed_header = new Granite.HeaderLabel (_("Up to Date")) {
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12
        };
        flatpak_backend.bind_property ("has-updated-packages", installed_header, "visible", SYNC_CREATE);

        installed_flowbox = new Gtk.FlowBox () {
            column_spacing = 24,
            max_children_per_line = 5,
            row_spacing = 12
        };
        installed_flowbox.bind_model (flatpak_backend.updated_packages, create_installed_from_package);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (list_box);
        box.append (installed_header);
        box.append (installed_flowbox);

        var scrolled = new Gtk.ScrolledWindow () {
            child = box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        action_button_group.add_widget (update_all_button);

        var automatic_updates_button = new Granite.SwitchModelButton (_("Automatically Update Free & Purchased Apps")) {
            description = _("Apps being tried for free will not update automatically")
        };

        var refresh_accellabel = new Granite.AccelLabel.from_action_name (
            _("Check for Updates"),
            "app.refresh"
        );

        var refresh_menuitem = new Gtk.Button () {
            action_name = "app.refresh",
            child = refresh_accellabel,
            sensitive = false
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
            primary = true,
            tooltip_markup = ("%s\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP).printf (
                _("Settings"),
                "F10"
            )
        };
        menu_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var search_button = new Gtk.Button.from_icon_name ("edit-find") {
            action_name = "win.search",
            /// TRANSLATORS: the action of searching
            tooltip_text = C_("action", "Search")
        };
        search_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var headerbar = new Gtk.HeaderBar () {
            title_widget = new Gtk.Grid () { visible = false }
        };
        headerbar.pack_start (new BackButton ());
        headerbar.pack_end (menu_button);
        headerbar.pack_end (search_button);

        var toolbarview = new Adw.ToolbarView () {
            content = scrolled
        };
        toolbarview.add_top_bar (headerbar);
        toolbarview.add_top_bar (updated_revealer);
        toolbarview.add_top_bar (header_revealer);
        toolbarview.add_css_class (Granite.STYLE_CLASS_VIEW);

        child = toolbarview;
        /// TRANSLATORS: the name of the Installed Apps view
        title = C_("view", "Installed");

        list_box.row_activated.connect ((row) => {
            if (row.get_child () is Widgets.InstalledPackageRowGrid) {
                show_app (((Widgets.InstalledPackageRowGrid) row.get_child ()).package);
            }
        });

        installed_flowbox.child_activated.connect ((child) => {
            if (child.get_child () is Widgets.InstalledPackageRowGrid) {
                show_app (((Widgets.InstalledPackageRowGrid) child.get_child ()).package);
            }
        });

        automatic_updates_button.notify["active"].connect (() => {
            if (automatic_updates_button.active) {
                // TODO: Follow up: think about this? Only update all and handle in manager?
                update_manager.refresh.begin ();
            }
        });

        App.settings.bind (
            "automatic-updates",
            automatic_updates_button,
            "active",
            SettingsBindFlags.DEFAULT
        );

        map.connect (start_updated_label_timeout);
        unmap.connect (stop_updated_label_timeout);

        App.settings.changed["last-refresh-time"].connect (set_updated_label);
    }

    private void set_updated_label () {
        updated_label.label = _("Everything is up to date. Last checked %s.").printf (
            Granite.DateTime.get_relative_datetime (
                new DateTime.from_unix_local (AppCenter.App.settings.get_int64 ("last-refresh-time"))
            )
        );
    }

    private void start_updated_label_timeout () {
        if (updated_label_timeout_id == 0) {
            updated_label_timeout_id = Timeout.add_seconds (60, () => {
                set_updated_label ();
                return Source.CONTINUE;
            });
        }
        set_updated_label ();
    }

    private void stop_updated_label_timeout () {
        if (updated_label_timeout_id != 0) {
            Source.remove (updated_label_timeout_id);
            updated_label_timeout_id = 0;
        }
    }

    private Gtk.Widget create_row_from_package (Object object) {
        unowned var package = (AppCenterCore.Package) object;
        var row = new Widgets.InstalledPackageRowGrid (package, action_button_group);

        unowned var update_manager = AppCenterCore.UpdateManager.get_default ();
        update_manager.bind_property ("updating-all", row, "action-sensitive", SYNC_CREATE | INVERT_BOOLEAN);

        return row;
    }

    private Gtk.Widget create_installed_from_package (Object object) {
        unowned var package = (AppCenterCore.Package) object;
        return new Widgets.InstalledPackageRowGrid (package, action_button_group);
    }

    public void clear () {
        // Free widgets with all their connected signals https://github.com/elementary/appcenter/pull/846
        list_box.remove_all ();
        installed_flowbox.remove_all ();
    }
}
