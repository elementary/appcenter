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
    public class AppListUpdateView : Gtk.Box {
        public signal void show_app (AppCenterCore.Package package);

        private Granite.HeaderLabel header_label;
        private Gtk.Button update_all_button;
        private Gtk.ListBox list_box;
        private Gtk.Revealer header_revealer;
        private Gtk.Revealer updated_revealer;
        private Gtk.Label updated_label;
        private Gtk.SizeGroup action_button_group;
        private ListStore package_liststore;
        private Widgets.SizeLabel size_label;
        private bool updating_all_apps = false;
        private Cancellable? refresh_cancellable = null;
        private AsyncMutex refresh_mutex = new AsyncMutex ();

        construct {
            package_liststore = new ListStore (typeof (AppCenterCore.Package));

            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("io/elementary/appcenter/AppListUpdateView.css");

            var loading_view = new Granite.Placeholder (_("Checking for Updates")) {
                description = _("Downloading a list of available updates to the OS and installed apps"),
                icon = new ThemedIcon ("sync-synchronizing")
            };

            header_label = new Granite.HeaderLabel ("") {
                hexpand = true
            };

            size_label = new Widgets.SizeLabel () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER
            };

            updated_label = new Gtk.Label ("");
            updated_label.get_style_context ().add_class (Granite.STYLE_CLASS_DIM_LABEL);

            var updated_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin = 12
            };
            updated_box.append (new Gtk.Image.from_icon_name ("process-completed-symbolic"));
            updated_box.append (updated_label);

            updated_revealer = new Gtk.Revealer () {
                child = updated_box
            };

            update_all_button = new Gtk.Button.with_label (_("Update All")) {
                valign = Gtk.Align.CENTER
            };
            update_all_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
            header.append (header_label);
            header.append (size_label);
            header.append (update_all_button);
            header.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            header_revealer = new Gtk.Revealer () {
                child = header
            };
            header_revealer.add_css_class ("header");
            header_revealer.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            list_box = new Gtk.ListBox () {
                activate_on_single_click = true,
                hexpand = true,
                vexpand = true
            };
            list_box.bind_model (package_liststore, create_row_from_package);
            list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) row_update_header);
            list_box.set_placeholder (loading_view);

            var scrolled = new Gtk.ScrolledWindow () {
                child = list_box,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            scrolled.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var info_label = new Gtk.Label (_("A restart is required to finish installing updates"));

            var infobar = new Gtk.InfoBar () {
                message_type = Gtk.MessageType.WARNING
            };
            infobar.add_child (info_label);

            var restart_button = infobar.add_button (_("Restart Now"), 0);

            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
            action_button_group.add_widget (update_all_button);
            action_button_group.add_widget (restart_button);

            infobar.response.connect ((response) => {
                if (response == 0) {
                    try {
                        SuspendControl.get_default ().reboot ();
                    } catch (GLib.Error e) {
                        if (!(e is IOError.CANCELLED)) {
                            info_label.label = _("Requesting a restart failed. Restart manually to finish installing updates");
                            infobar.message_type = Gtk.MessageType.ERROR;
                            restart_button.visible = false;
                        }
                    }
                }
            });

            AppCenterCore.UpdateManager.get_default ().bind_property ("restart-required", infobar, "visible", BindingFlags.SYNC_CREATE);

            orientation = Gtk.Orientation.VERTICAL;
            append (infobar);
            append (updated_revealer);
            append (header_revealer);
            append (scrolled);

            get_apps.begin ();

            unowned var client = AppCenterCore.Client.get_default ();
            client.installed_apps_changed.connect (() => {
                Idle.add (() => {
                    get_apps.begin ();
                    return GLib.Source.REMOVE;
                });
            });

            package_liststore.items_changed.connect (() => {
                list_box.show_all ();
            });

            list_box.row_activated.connect ((row) => {
                if (row is Widgets.PackageRow) {
                    show_app (((Widgets.PackageRow) row).get_package ());
                }
            });

            update_all_button.clicked.connect (on_update_all);

            unowned var aggregator = AppCenterCore.BackendAggregator.get_default ();
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

        private async void get_apps () {
            if (refresh_cancellable != null) {
                refresh_cancellable.cancel (); // Cancel any ongoing `get_installed_applications ()`
            }

            yield refresh_mutex.lock (); // Wait for any previous operation to end
            // We know refresh_cancellable is now null as it was set so before mutex was unlocked.
            refresh_cancellable = new Cancellable ();
            unowned var client = AppCenterCore.Client.get_default ();
            unowned var update_manager = AppCenterCore.UpdateManager.get_default ();
            if (client.updates_number > 0) {
                header_revealer.reveal_child = true;

                if (client.updates_number == update_manager.unpaid_apps_number || updating_all_apps) {
                    update_all_button.sensitive = false;
                } else {
                    update_all_button.sensitive = true;
                }

                header_label.label = ngettext (
                    "%u Update Available",
                    "%u Updates Available",
                    client.updates_number
                ).printf (client.updates_number);

                size_label.update (update_manager.updates_size, update_manager.has_flatpak_updates);
            } else {
                header_revealer.reveal_child = false;

                if (!update_manager.restart_required) {
                    updated_revealer.reveal_child = true;
                    updated_label.label = _("Everything is up to date. Last checked %s.").printf (
                        Granite.DateTime.get_relative_datetime (
                            new DateTime.from_unix_local (AppCenter.App.settings.get_int64 ("last-refresh-time"))
                        )
                    );
                }
            }

            var installed_apps = yield client.get_installed_applications (refresh_cancellable);

            if (!refresh_cancellable.is_cancelled ()) {
                package_liststore.remove_all ();

                var os_updates = AppCenterCore.UpdateManager.get_default ().os_updates;
                var os_updates_size = yield os_updates.get_download_size_including_deps ();
                if (os_updates_size > 0) {
                    package_liststore.insert_sorted (os_updates, compare_package_func);
                }

                var runtime_updates = AppCenterCore.UpdateManager.get_default ().runtime_updates;
                var runtime_updates_size = yield runtime_updates.get_download_size_including_deps ();
                if (runtime_updates_size > 0) {
                    package_liststore.insert_sorted (runtime_updates, compare_package_func);
                }

                foreach (var package in installed_apps) {
                    var needs_update = package.state == AppCenterCore.Package.State.UPDATE_AVAILABLE;
                    // Only add row if this package needs an update or it's not a font or plugin
                    if (needs_update || (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT)) {
                        package_liststore.insert_sorted (package, compare_package_func);
                    }
                }
            }

            yield client.get_prepared_applications (refresh_cancellable);

            refresh_cancellable = null;
            refresh_mutex.unlock ();
        }

        private Gtk.Widget create_row_from_package (Object object) {
            unowned var package = (AppCenterCore.Package) object;
            return new Widgets.PackageRow.installed (package, action_button_group);
        }

        private int compare_package_func (Object object1, Object object2) {
            var package1 = (AppCenterCore.Package) object1;
            var package2 = (AppCenterCore.Package) object2;

            bool a_has_updates = false;
            bool a_is_driver = false;
            bool a_is_os = false;
            bool a_is_runtime = false;
            bool a_is_updating = false;
            string a_package_name = "";
            if (package1 != null) {
                a_has_updates = package1.update_available;
                a_is_driver = package1.kind == AppStream.ComponentKind.DRIVER;
                a_is_os = package1.is_os_updates;
                a_is_runtime = package1.is_runtime_updates;
                a_is_updating = package1.is_updating;
                a_package_name = package1.get_name ();
            }

            bool b_has_updates = false;
            bool b_is_driver = false;
            bool b_is_os = false;
            bool b_is_runtime = false;
            bool b_is_updating = false;
            string b_package_name = "";
            if (package2 != null) {
                b_has_updates = package2.update_available;
                b_is_driver = package2.kind == AppStream.ComponentKind.DRIVER;
                b_is_os = package2.is_os_updates;
                b_is_runtime = package2.is_runtime_updates;
                b_is_updating = package2.is_updating;
                b_package_name = package2.get_name ();
            }

            // The currently updating package is always top of the list
            if (a_is_updating || b_is_updating) {
                return a_is_updating ? -1 : 1;
            }

            // Sort updatable OS updates first, then other updatable packages
            if (a_has_updates != b_has_updates) {
                if (a_is_os && a_has_updates) {
                    return -1;
                }

                if (b_is_os && b_has_updates) {
                    return 1;
                }

                if (a_has_updates) {
                    return -1;
                }

                if (b_has_updates) {
                    return 1;
                }
            }

            if (a_is_driver != b_is_driver) {
                return a_is_driver ? - 1 : 1;
            }

            // Ensures OS updates are sorted to the top amongst up-to-date packages
            if (a_is_os || b_is_os) {
                return a_is_os ? -1 : 1;
            }

            // Ensures runtime updates are sorted to the top amongst up-to-date packages but below OS updates
            if (a_is_runtime || b_is_runtime) {
                return a_is_runtime ? -1 : 1;
            }

            return a_package_name.collate (b_package_name); /* Else sort in name order */
        }

        [CCode (instance_pos = -1)]
        private void row_update_header (Widgets.PackageRow row, Widgets.PackageRow? before) {
            bool update_available = false;
            bool is_driver = false;
            var row_package = row.get_package ();
            if (row_package != null) {
                update_available = row_package.update_available || row_package.is_updating;
                is_driver = row_package.kind == AppStream.ComponentKind.DRIVER;
            }


            bool before_update_available = false;
            bool before_is_driver = false;
            if (before != null) {
                var before_package = before.get_package ();
                if (before_package != null) {
                    before_update_available = before_package.update_available || before_package.is_updating;
                    before_is_driver = before_package.kind == AppStream.ComponentKind.DRIVER;
                }
            }

            if (update_available) {
                if (before != null && update_available == before_update_available) {
                    row.set_header (null);
                    return;
                }
            } else if (is_driver) {
                if (before != null && is_driver == before_is_driver) {
                    row.set_header (null);
                    return;
                }

                var header = new Granite.HeaderLabel (_("Drivers")) {
                    margin_top = 12,
                    margin_end = 9,
                    margin_start = 9
                };

                row.set_header (header);
            } else {
                if (before != null && is_driver == before_is_driver && update_available == before_update_available) {
                    row.set_header (null);
                    return;
                }

                var header = new Granite.HeaderLabel (_("Up to Date")) {
                    margin_top = 12,
                    margin_end = 9,
                    margin_start = 9
                };

                row.set_header (header);
            }
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

            for (int i = 0; i < package_liststore.get_n_items (); i++) {
                var package = (AppCenterCore.Package) package_liststore.get_item (i);
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
                                transient_for = (Gtk.Window) get_toplevel ()
                            };
                            fail_dialog.present ();
                            break;
                        }
                    }
                }
            }

            unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
            yield client.refresh_updates ();

            updating_all_apps = false;
        }

        public async void add_app (AppCenterCore.Package package) {
            unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
            var installed_apps = yield client.get_installed_applications ();
            foreach (var app in installed_apps) {
                if (app == package) {
                    package_liststore.insert_sorted (package, compare_package_func);
                    break;
                }
            }
        }

        // public async void remove_app (AppCenterCore.Package package) {
        //     var child = list_box.get_first_child ();
        //     while (child != null) {
        //         if (child is Widgets.PackageRow) {
        //             unowned var row = (Widgets.PackageRow) child;

        //             if (row.get_package () == package) {
        //                 list_box.remove (row);
        //                 break;
        //             }
        //         }

        //         child = child.get_next_sibling ();
        //     }

        //     list_box.invalidate_sort ();
        // }

        public void clear () {
            package_liststore.remove_all ();
        }
    }
}
