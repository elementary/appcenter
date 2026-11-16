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
    private Granite.Box updatable_header;
    private Granite.HeaderLabel in_progress_header;
    private Granite.HeaderLabel installed_header;

    private Gtk.SizeGroup action_button_group;

    private uint updated_label_timeout_id = 0;

    construct {
        var update_manager = AppCenterCore.UpdateManager.get_default ();
        unowned var flatpak_backend = AppCenterCore.FlatpakBackend.get_default ();

        var updatable_header_label = new Granite.HeaderLabel (_("Available Updates")) {
            hexpand = true
        };
        flatpak_backend.updatable_packages.bind_property (
            "n-items", updatable_header_label, "label", SYNC_CREATE,
            (binding, from_value, ref to_value) => {
                var n_updatable_packages = from_value.get_uint ();

                to_value.set_string (ngettext (
                    "%u Available Update",
                    "%u Available Updates",
                    n_updatable_packages
                ).printf (n_updatable_packages));

                return true;
            }
        );
        flatpak_backend.bind_property (
            "updates-size", updatable_header_label, "secondary-text", SYNC_CREATE,
            (binding, from_value, ref to_value) => {
                to_value.set_string (_("Up to %s").printf (
                    GLib.format_size (from_value.get_uint64 ())
                ));

                return true;
            }
        );

        var update_all_button = new Gtk.Button.with_label (_("Update All")) {
            valign = Gtk.Align.CENTER,
            action_name = "app.update-all"
        };
        update_all_button.add_css_class (Granite.CssClass.SUGGESTED);

        updatable_header = new Granite.Box (HORIZONTAL) {
            margin_end = 6,
            margin_start = 6
        };
        updatable_header.append (updatable_header_label);
        updatable_header.append (update_all_button);

        in_progress_header = new Granite.HeaderLabel (_("In Progress")) {
            margin_end = 6,
            margin_start = 6
        };

        installed_header = new Granite.HeaderLabel (_("Up to Date")) {
            margin_end = 6,
            margin_start = 6
        };

        var installed_sort_model = new Gtk.SortListModel (
            flatpak_backend.updated_packages,
            new Gtk.CustomSorter ((CompareDataFunc<GLib.Object>) AppCenterCore.Package.compare_newest_release)
        );

        var model_store = new ListStore (typeof (ListModel));
        model_store.append (flatpak_backend.updatable_packages);
        model_store.append (flatpak_backend.working_packages);
        model_store.append (installed_sort_model);

        var flatten_model = new Gtk.FlattenListModel (model_store);
        var selection_model = new Gtk.NoSelection (flatten_model);

        var item_factory = new Gtk.SignalListItemFactory ();
        item_factory.bind.connect (on_item_bind);

        var header_factory = new Gtk.SignalListItemFactory ();
        header_factory.bind.connect (on_header_bind);
        header_factory.unbind.connect (on_header_unbind);

        var list_view = new Gtk.ListView (selection_model, item_factory) {
            header_factory = header_factory,
            single_click_activate = true,
        };
        list_view.activate.connect (on_row_activated);

        var clamp = new Adw.ClampScrollable () {
            child = list_view,
            maximum_size = AppInfoView.MAX_WIDTH,
        };

        var scrolled = new Gtk.ScrolledWindow () {
            child = clamp,
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
        toolbarview.add_css_class (Granite.STYLE_CLASS_VIEW);

        child = toolbarview;
        /// TRANSLATORS: the name of the Installed Apps view
        title = C_("view", "Installed");

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
        installed_header.secondary_text = _("Last checked %s").printf (
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

    private void on_item_bind (Object obj) {
        var list_item = (Gtk.ListItem) obj;
        var package = (AppCenterCore.Package) list_item.get_item ();

        var row = new Widgets.InstalledPackageRowGrid (package, action_button_group);

        if (package.working || package.update_available) {
            unowned var update_manager = AppCenterCore.UpdateManager.get_default ();
            update_manager.bind_property ("updating-all", row, "action-sensitive", SYNC_CREATE | INVERT_BOOLEAN);
        }

        list_item.set_child (row);
    }

    private void on_header_bind (Object obj) {
        var header = (Gtk.ListHeader) obj;
        var package = (AppCenterCore.Package) header.item;

        if (package.working) {
            header.set_child (in_progress_header);
        } else if (package.update_available) {
            header.set_child (updatable_header);
        } else {
            header.set_child (installed_header);
        }
    }

    private void on_header_unbind (Object obj) {
        var list_item = (Gtk.ListHeader) obj;
        list_item.set_child (null);
    }

    private void on_row_activated (Gtk.ListView list_view, uint pos) {
        var package = (AppCenterCore.Package) list_view.model.get_item (pos);
        activate_action_variant (MainWindow.ACTION_PREFIX + MainWindow.ACTION_SHOW_PACKAGE, package.uid);
    }
}
