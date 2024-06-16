/*-
 * Copyright 2014-2023 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace AppCenter.Views {
/** AppList for the Updates View. Sorts update_available first and shows headers.
      * Does not show Uninstall Button **/
    public class AppListUpdateView : Adw.NavigationPage {
        public signal void show_app (AppCenterCore.Package package);

        private Granite.HeaderLabel header_label;
        private Gtk.Button update_all_button;
        private Gtk.FlowBox installed_flowbox;
        private Gtk.ListBox list_box;
        private Gtk.Revealer header_revealer;
        private Gtk.Revealer updated_revealer;
        private Gtk.Label updated_label;
        private Gtk.SizeGroup action_button_group;
        private ListStore installed_liststore;
        private Widgets.SizeLabel size_label;
        private bool updating_all_apps = false;
        private Cancellable? refresh_cancellable = null;
        private AsyncMutex refresh_mutex = new AsyncMutex ();

        construct {
            var update_manager = AppCenterCore.UpdateManager.get_default ();

            installed_liststore = new ListStore (typeof (AppCenterCore.Package));

            var loading_view = new Granite.Placeholder (_("Checking for Updates")) {
                description = _("Downloading a list of available updates to the OS and installed apps"),
                icon = new ThemedIcon ("sync-synchronizing")
            };

            header_label = new Granite.HeaderLabel ("") {
                hexpand = true,
                valign = CENTER
            };

            size_label = new Widgets.SizeLabel () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER
            };

            updated_label = new Gtk.Label ("");
            updated_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            var updated_box = new Gtk.Box (HORIZONTAL, 6);
            updated_box.append (new Gtk.Image.from_icon_name ("process-completed-symbolic"));
            updated_box.append (updated_label);

            updated_revealer = new Gtk.Revealer () {
                child = updated_box
            };
            updated_revealer.add_css_class ("header");

            update_all_button = new Gtk.Button.with_label (_("Update All")) {
                valign = Gtk.Align.CENTER
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

            list_box = new Gtk.ListBox () {
                activate_on_single_click = true,
                hexpand = true,
                vexpand = true
            };
            list_box.bind_model (update_manager.updates_liststore, create_row_from_package);

            var installed_header = new Granite.HeaderLabel (_("Up to Date")) {
                margin_top = 12,
                margin_end = 12,
                margin_bottom = 12,
                margin_start = 12,
            };

            installed_flowbox = new Gtk.FlowBox () {
                column_spacing = 24,
                homogeneous = true,
                max_children_per_line = 4,
                row_spacing = 12
            };
            installed_flowbox.bind_model (installed_liststore, create_installed_from_package);

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

            var toolbarview = new Adw.ToolbarView () {
                content = scrolled
            };
            toolbarview.add_top_bar (updated_revealer);
            toolbarview.add_top_bar (header_revealer);
            toolbarview.add_css_class (Granite.STYLE_CLASS_VIEW);

            var stack = new Gtk.Stack () {
                transition_type = UNDER_UP
            };
            stack.add_child (toolbarview);
            stack.add_child (loading_view);
            stack.visible_child = loading_view;

            child = stack;
            /// TRANSLATORS: the name of the Installed Apps view
            title = C_("view", "Installed");

            on_installed_changed.begin ((obj, res) => {
                on_installed_changed.end (res);
                stack.visible_child = toolbarview;
            });

            update_manager.updates_liststore.items_changed.connect (() => {
                Idle.add (() => {
                    on_updates_changed ();
                    return GLib.Source.REMOVE;
                });
            });

            update_manager.installed_apps_changed.connect (() => {
                Idle.add (() => {
                    on_installed_changed.begin ();
                    return GLib.Source.REMOVE;
                });
            });

            list_box.row_activated.connect ((row) => {
                if (row is Widgets.PackageRow) {
                    show_app (((Widgets.PackageRow) row).get_package ());
                }
            });

            installed_flowbox.child_activated.connect ((child) => {
                if (child.get_child () is Widgets.InstalledPackageRowGrid) {
                    show_app (((Widgets.InstalledPackageRowGrid) child.get_child ()).package);
                }
            });

            update_all_button.clicked.connect (on_update_all);

            unowned var aggregator = AppCenterCore.FlatpakBackend.get_default ();
            aggregator.notify ["job-type"].connect (() => {
                switch (aggregator.job_type) {
                    case GET_PREPARED_PACKAGES:
                    case GET_INSTALLED_PACKAGES:
                    case GET_UPDATES:
                    case REFRESH_CACHE:
                    case INSTALL_PACKAGE:
                    case UPDATE_PACKAGE:
                    case REMOVE_PACKAGE:
                        updated_revealer.reveal_child = false;
                        break;
                }
            });
        }

        private void on_updates_changed () {
            unowned var update_manager = AppCenterCore.UpdateManager.get_default ();

            header_revealer.reveal_child = update_manager.updates_number > 0;
            updated_revealer.reveal_child = update_manager.updates_number == 0;

            if (update_manager.updates_number > 0) {
                if (update_manager.updates_number == update_manager.unpaid_apps_number || updating_all_apps) {
                    update_all_button.sensitive = false;
                } else {
                    update_all_button.sensitive = true;
                }

                header_label.label = ngettext (
                    "%u Update Available",
                    "%u Updates Available",
                    update_manager.updates_number
                ).printf (update_manager.updates_number);

                size_label.update (update_manager.updates_size);
            } else {
                updated_label.label = _("Everything is up to date. Last checked %s.").printf (
                    Granite.DateTime.get_relative_datetime (
                        new DateTime.from_unix_local (AppCenter.App.settings.get_int64 ("last-refresh-time"))
                    )
                );
            }
        }

        private async void on_installed_changed () {
            if (refresh_cancellable != null) {
                refresh_cancellable.cancel (); // Cancel any ongoing `get_installed_applications ()`
            }

            yield refresh_mutex.lock (); // Wait for any previous operation to end
            // We know refresh_cancellable is now null as it was set so before mutex was unlocked.
            refresh_cancellable = new Cancellable ();

            if (!refresh_cancellable.is_cancelled ()) {
                installed_liststore.remove_all ();

                unowned var flatpak_backend = AppCenterCore.FlatpakBackend.get_default ();
                var installed_apps = yield flatpak_backend.get_installed_applications (refresh_cancellable);

                foreach (var package in installed_apps) {
                    if (package.state != UPDATE_AVAILABLE && package.kind != ADDON && package.kind != FONT) {
                        installed_liststore.insert_sorted (package, compare_installed_func);
                    }
                }
            }

            refresh_cancellable = null;
            refresh_mutex.unlock ();
        }

        private Gtk.Widget create_row_from_package (Object object) {
            unowned var package = (AppCenterCore.Package) object;
            return new Widgets.PackageRow.installed (package, action_button_group);
        }

        private Gtk.Widget create_installed_from_package (Object object) {
            unowned var package = (AppCenterCore.Package) object;
            return new Widgets.InstalledPackageRowGrid (package, action_button_group);
        }

        private void on_update_all () {
            perform_all_updates.begin ();
        }

        private async void perform_all_updates () {
            if (updating_all_apps) {
                return;
            }

            update_all_button.sensitive = false;
            updating_all_apps = true;

            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is Widgets.PackageRow) {
                    ((Widgets.PackageRow) child).set_action_sensitive (false);
                }

                child = child.get_next_sibling ();
            }

            unowned var update_manager = AppCenterCore.UpdateManager.get_default ();
            for (int i = 0; i < update_manager.updates_liststore.get_n_items (); i++) {
                var package = (AppCenterCore.Package) update_manager.updates_liststore.get_item (i);
                if (package.update_available && !package.should_pay) {
                    try {
                        yield package.update (false);
                    } catch (Error e) {
                        // If one package update was cancelled, drop out of the loop of updating the rest
                        if (e is GLib.IOError.CANCELLED) {
                            break;
                        } else {
                            var fail_dialog = new UpgradeFailDialog (package, e.message) {
                                modal = true,
                                transient_for = (Gtk.Window) get_root ()
                            };
                            fail_dialog.present ();
                            break;
                        }
                    }
                }
            }

            yield AppCenterCore.UpdateManager.get_default ().get_updates ();

            updating_all_apps = false;
        }

        private int compare_installed_func (Object object1, Object object2) {
            var package1 = (AppCenterCore.Package) object1;
            var package2 = (AppCenterCore.Package) object2;

            string a_package_name = "";
            if (package1 != null) {
                a_package_name = package1.get_name ();
            }

            string b_package_name = "";
            if (package2 != null) {
                b_package_name = package2.get_name ();
            }

            return a_package_name.collate (b_package_name);
        }

        public void clear () {
            // Free widgets with all their connected signals https://github.com/elementary/appcenter/pull/846
            list_box.remove_all ();
            installed_flowbox.remove_all ();
        }
    }
}
