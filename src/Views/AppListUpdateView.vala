/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
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

        private Gtk.FlowBox installed_flowbox;
        private Gtk.FlowBox updates_flowbox;
        private Gtk.SizeGroup action_button_group;
        private bool updating_all_apps = false;
        private Cancellable? refresh_cancellable = null;
        private AsyncMutex refresh_mutex = new AsyncMutex ();

        construct {
            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);

            var loading_view = new Granite.Widgets.AlertView (
                _("Checking for Updates"),
                _("Downloading a list of available updates to the OS and installed apps"),
                "sync-synchronizing"
            );
            loading_view.show_all ();

            uint update_numbers = 0U;
            uint nag_numbers = 0U;
            uint64 update_real_size = 0ULL;
            bool using_flatpak = false;
            foreach (var package in get_packages ()) {
                if (package.update_available || package.is_updating) {
                    if (package.should_pay) {
                        nag_numbers++;
                    }

                    if (!using_flatpak && package.is_flatpak) {
                        using_flatpak = true;
                    }

                    update_numbers++;
                    update_real_size += package.change_information.size;
                }
            }

            var update_all_button = new Gtk.Button.with_label (_("Update All")) {
                valign = Gtk.Align.CENTER
            };
            update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            if (update_numbers == nag_numbers || updating_all_apps) {
                update_all_button.sensitive = false;
            }

            action_button_group.add_widget (update_all_button);

            var updates_header = new Widgets.UpdateHeaderRow.updatable (update_numbers, update_real_size, using_flatpak);
            updates_header .add (update_all_button);

            updates_flowbox = new Gtk.FlowBox () {
                column_spacing = 24,
                homogeneous = true,
                max_children_per_line = 4,
                row_spacing = 12,
                valign = Gtk.Align.START
            };

            var installed_header = new Granite.HeaderLabel (_("Up to Date")) {
                margin_top = 24,
                margin_end = 12,
                margin_bottom = 12,
                margin_start = 12,
            };

            installed_flowbox = new Gtk.FlowBox () {
                column_spacing = 24,
                homogeneous = true,
                max_children_per_line = 4,
                row_spacing = 12,
                valign = Gtk.Align.START
            };

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                vexpand = true
            };
            box.add (updates_header);
            box.add (updates_flowbox);
            box.add (installed_header);
            box.add (installed_flowbox);
            box.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

            var scrolled = new Gtk.ScrolledWindow (null, null) {
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            scrolled.add (box);

            var info_label = new Gtk.Label (_("A restart is required to finish installing updates"));
            info_label.show ();

            var infobar = new Gtk.InfoBar ();
            infobar.message_type = Gtk.MessageType.WARNING;
            infobar.no_show_all = true;
            infobar.get_content_area ().add (info_label);

            var restart_button = infobar.add_button (_("Restart Now"), 0);
            action_button_group.add_widget (restart_button);

            orientation = Gtk.Orientation.VERTICAL;
            add (infobar);
            add (scrolled);

            get_apps.begin ();

            AppCenterCore.UpdateManager.get_default ().bind_property ("restart-required", infobar, "visible", BindingFlags.SYNC_CREATE);

            unowned var client = AppCenterCore.Client.get_default ();
            client.installed_apps_changed.connect (() => {
                Idle.add (() => {
                    get_apps.begin ();
                    return GLib.Source.REMOVE;
                });
            });

            // list_box.row_activated.connect ((row) => {
            //     if (row is Widgets.PackageRow) {
            //         show_app (((Widgets.PackageRow) row).get_package ());
            //     }
            // });

            update_all_button.clicked.connect (on_update_all);

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

        }

        private async void get_apps () {
            if (refresh_cancellable != null) {
                refresh_cancellable.cancel (); // Cancel any ongoing `get_installed_applications ()`
            }

            yield refresh_mutex.lock (); // Wait for any previous operation to end
            // We know refresh_cancellable is now null as it was set so before mutex was unlocked.
            refresh_cancellable = new Cancellable ();
            unowned var client = AppCenterCore.Client.get_default ();

            var installed_apps = yield client.get_installed_applications (refresh_cancellable);

            if (!refresh_cancellable.is_cancelled ()) {
                clear ();

                var os_updates = AppCenterCore.UpdateManager.get_default ().os_updates;
                add_package (os_updates);
                add_packages (installed_apps);
            }

            refresh_cancellable = null;
            refresh_mutex.unlock ();
        }

        public void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
            foreach (var package in packages) {
                add_row_for_package (package);
            }
        }

        public void add_package (AppCenterCore.Package package) {
            add_row_for_package (package);
        }

        private void add_row_for_package (AppCenterCore.Package package) {
            if (package.state == AppCenterCore.Package.State.UPDATE_AVAILABLE) {
                var row = new Widgets.InstalledPackageRowGrid (package, action_button_group);
                updates_flowbox.add (row);
            } else if (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT) {
                var row = new Widgets.InstalledPackageRowGrid (package, action_button_group);
                installed_flowbox.add (row);
            }

            show_all ();
        }

        // [CCode (instance_pos = -1)]
        // private int package_row_compare (Widgets.PackageRow row1, Widgets.PackageRow row2) {
        //     var row1_package = row1.get_package ();
        //     var row2_package = row2.get_package ();

        //     bool a_has_updates = false;
        //     bool a_is_driver = false;
        //     bool a_is_os = false;
        //     bool a_is_updating = false;
        //     string a_package_name = "";
        //     if (row1_package != null) {
        //         a_has_updates = row1_package.update_available;
        //         a_is_driver = row1_package.kind == AppStream.ComponentKind.DRIVER;
        //         a_is_os = row1_package.is_os_updates;
        //         a_is_updating = row1_package.is_updating;
        //         a_package_name = row1_package.get_name ();
        //     }

        //     bool b_has_updates = false;
        //     bool b_is_driver = false;
        //     bool b_is_os = false;
        //     bool b_is_updating = false;
        //     string b_package_name = "";
        //     if (row2_package != null) {
        //         b_has_updates = row2_package.update_available;
        //         b_is_driver = row2_package.kind == AppStream.ComponentKind.DRIVER;
        //         b_is_os = row2_package.is_os_updates;
        //         b_is_updating = row2_package.is_updating;
        //         b_package_name = row2_package.get_name ();
        //     }

        //     // The currently updating package is always top of the list
        //     if (a_is_updating || b_is_updating) {
        //         return a_is_updating ? -1 : 1;
        //     }

        //     // Sort updatable OS updates first, then other updatable packages
        //     if (a_has_updates != b_has_updates) {
        //         if (a_is_os && a_has_updates) {
        //             return -1;
        //         }

        //         if (b_is_os && b_has_updates) {
        //             return 1;
        //         }

        //         if (a_has_updates) {
        //             return -1;
        //         }

        //         if (b_has_updates) {
        //             return 1;
        //         }
        //     }

        //     if (a_is_driver != b_is_driver) {
        //         return a_is_driver ? - 1 : 1;
        //     }

        //     // Ensures OS updates are sorted to the top amongst up-to-date packages
        //     if (a_is_os || b_is_os) {
        //         return a_is_os ? -1 : 1;
        //     }

        //     return a_package_name.collate (b_package_name); /* Else sort in name order */
        // }

        // [CCode (instance_pos = -1)]
        // private void row_update_header (Widgets.PackageRow row, Widgets.PackageRow? before) {
        //     bool update_available = false;
        //     bool is_driver = false;
        //     var row_package = row.get_package ();
        //     if (row_package != null) {
        //         update_available = row_package.update_available || row_package.is_updating;
        //         is_driver = row_package.kind == AppStream.ComponentKind.DRIVER;
        //     }


        //     bool before_update_available = false;
        //     bool before_is_driver = false;
        //     if (before != null) {
        //         var before_package = before.get_package ();
        //         if (before_package != null) {
        //             before_update_available = before_package.update_available || before_package.is_updating;
        //             before_is_driver = before_package.kind == AppStream.ComponentKind.DRIVER;
        //         }
        //     }

        //     if (update_available) {
        //         if (before != null && update_available == before_update_available) {
        //             row.set_header (null);
        //             return;
        //         }

        //         uint update_numbers = 0U;
        //         uint nag_numbers = 0U;
        //         uint64 update_real_size = 0ULL;
        //         bool using_flatpak = false;
        //         foreach (var package in get_packages ()) {
        //             if (package.update_available || package.is_updating) {
        //                 if (package.should_pay) {
        //                     nag_numbers++;
        //                 }

        //                 if (!using_flatpak && package.is_flatpak) {
        //                     using_flatpak = true;
        //                 }

        //                 update_numbers++;
        //                 update_real_size += package.change_information.size;
        //             }
        //         }

        //         var header = new Widgets.UpdateHeaderRow.updatable (update_numbers, update_real_size, using_flatpak);

        //         // Unfortunately the update all button needs to be recreated everytime the header needs to be updated
        //         var update_all_button = new Gtk.Button.with_label (_("Update All"));
        //         if (update_numbers == nag_numbers || updating_all_apps) {
        //             update_all_button.sensitive = false;
        //         }

        //         update_all_button.valign = Gtk.Align.CENTER;
        //         update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        //         update_all_button.clicked.connect (on_update_all);
        //         action_button_group.add_widget (update_all_button);

        //         header.add (update_all_button);

        //         header.show_all ();
        //         row.set_header (header);
        //     } else if (is_driver) {
        //         if (before != null && is_driver == before_is_driver) {
        //             row.set_header (null);
        //             return;
        //         }

        //         var header = new Widgets.UpdateHeaderRow.drivers ();
        //         header.show_all ();
        //         row.set_header (header);
        //     } else {
        //         if (before != null && is_driver == before_is_driver && update_available == before_update_available) {
        //             row.set_header (null);
        //             return;
        //         }

        //         var header = new Widgets.UpdateHeaderRow.up_to_date ();
        //         header.show_all ();
        //         row.set_header (header);
        //     }
        // }

        private void on_update_all () {
            perform_all_updates.begin ();
        }

        private async void perform_all_updates () {
            if (updating_all_apps) {
                return;
            }

            updating_all_apps = true;

            // foreach (var row in list_box.get_children ()) {
            //     if (row is Widgets.PackageRow) {
            //         ((Widgets.PackageRow) row).set_action_sensitive (false);
            //     }
            // };

            foreach (var package in get_packages ()) {
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

        private Gee.Collection<AppCenterCore.Package> get_packages () {
            var tree_set = new Gee.TreeSet<AppCenterCore.Package> ();
            // foreach (unowned var child in list_box.get_children ()) {
            //     if (child is Widgets.PackageRow) {
            //         tree_set.add (((Widgets.PackageRow) child).get_package ());
            //     }
            // }

            return tree_set;
        }

        public async void add_app (AppCenterCore.Package package) {
            unowned AppCenterCore.Client client = AppCenterCore.Client.get_default ();
            var installed_apps = yield client.get_installed_applications ();
            foreach (var app in installed_apps) {
                if (app == package) {
                    add_package (app);
                    break;
                }
            }
        }

        public async void remove_app (AppCenterCore.Package package) {
            // foreach (unowned var child in list_box.get_children ()) {
            //     if (child is Widgets.PackageRow) {
            //         unowned var row = (Widgets.PackageRow) child;

            //         if (row.get_package () == package) {
            //             row.destroy ();
            //             break;
            //         }
            //     }
            // }
        }

        public void clear () {
            foreach (unowned var child in updates_flowbox.get_children ()) {
                updates_flowbox.remove (child);
            };

            foreach (unowned var child in installed_flowbox.get_children ()) {
                installed_flowbox.remove (child);
            };
        }
    }
}
