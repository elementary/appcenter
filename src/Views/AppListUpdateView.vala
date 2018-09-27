// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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
    public class AppListUpdateView : AbstractAppList {
        private Gtk.Button? update_all_button;
        private bool updating_all_apps = false;
        private bool apps_remaining_started = false;
        private GLib.Mutex update_mutex;
        private uint apps_done = 0;
        private Gee.LinkedList<AppCenterCore.Package> apps_to_update;
        private AppCenterCore.Package first_package;

        private bool _updating_cache;
        public bool updating_cache {
            get {
                if (packages_changing > 0) {
                    return false;
                }
                return _updating_cache;
            }
            set {
                if (_updating_cache != value) {
                    _updating_cache = value;
                    list_box.invalidate_headers ();
                }
            }
        }

        construct {
            list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) row_update_header);

            update_mutex = GLib.Mutex ();
            apps_to_update = new Gee.LinkedList<AppCenterCore.Package> ();

            var info_label = new Gtk.Label (_("A restart is required to complete the installation of updates"));
            info_label.show ();

            var infobar = new Gtk.InfoBar ();
            infobar.message_type = Gtk.MessageType.WARNING;
            infobar.no_show_all = true;
            infobar.get_content_area ().add (info_label);

            var restart_button = infobar.add_button (_("Restart Now"), 0);
            action_button_group.add_widget (restart_button);

            infobar.response.connect ((response) => {
                if (response == 0) {
                    Utils.reboot ();
                }
            });

            AppCenterCore.UpdateManager.get_default ().bind_property ("restart-required", infobar, "visible", BindingFlags.SYNC_CREATE);

            add (infobar);
            add (scrolled);
        }

        protected override void on_list_changed () {
            list_box.invalidate_sort ();
        }

        protected override Widgets.AppListRow construct_row_for_package (AppCenterCore.Package package) {
            return new Widgets.PackageRow.installed (package, info_grid_group, action_button_group, false);
        }

        protected override void on_package_changing (AppCenterCore.Package package, bool is_changing) {
            base.on_package_changing (package, is_changing);
            if (update_all_button != null) {
                update_all_button.sensitive = packages_changing == 0;
            }
        }

        [CCode (instance_pos = -1)]
        protected override int package_row_compare (Widgets.AppListRow row1, Widgets.AppListRow row2) {
            bool a_is_updating = row1.get_is_updating ();
            bool b_is_updating = row2.get_is_updating ();

            if (a_is_updating || b_is_updating) {
                return a_is_updating ? -1 : 1;
            }

            bool a_is_os = row1.get_is_os_updates ();
            bool b_is_os = row2.get_is_os_updates ();

            if (a_is_os || b_is_os) { /* OS update row sorts ahead of other update rows */
                return a_is_os ? -1 : 1;
            }

            bool a_has_updates = row1.get_update_available ();
            bool b_has_updates = row2.get_update_available ();

            if (a_has_updates != b_has_updates) { /* Updates rows sort ahead of updated rows */
                return a_has_updates ? -1 : 1;
            }

            bool a_is_driver = row1.get_is_driver ();
            bool b_is_driver = row2.get_is_driver ();

            if (a_is_driver != b_is_driver) {
                return a_is_driver ? - 1 : 1;
            }

            return row1.get_name_label ().collate (row2.get_name_label ()); /* Else sort in name order */
        }

        [CCode (instance_pos = -1)]
        private void row_update_header (Widgets.AppListRow row, Widgets.AppListRow? before) {
            bool update_available = row.get_update_available ();
            bool is_driver = row.get_is_driver ();

            if (update_available) {
                if (before != null && update_available == before.get_update_available ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.UpdatesGrid ();

                uint update_numbers = 0U;
                uint nag_numbers = 0U;
                uint64 update_real_size = 0ULL;
                foreach (var package in get_packages ()) {
                    if (package.update_available || package.is_updating) {
                        if (package.should_nag_update) {
                            nag_numbers++;
                        }

                        update_numbers++;
                        update_real_size += package.change_information.get_size ();
                    }
                }

                header.update (update_numbers, update_real_size, updating_cache);

                // Unfortunately the update all button needs to be recreated everytime the header needs to be updated
                if (!updating_cache && update_numbers > 0) {
                    update_all_button = new Gtk.Button.with_label (_("Update All"));
                    if (update_numbers == nag_numbers) {
                        update_all_button.sensitive = false;
                    }

                    update_all_button.valign = Gtk.Align.CENTER;
                    update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                    update_all_button.clicked.connect (on_update_all);
                    action_button_group.add_widget (update_all_button);

                    header.add_widget (update_all_button);
                }

                header.show_all ();
                row.set_header (header);
            } else if (is_driver) {
                if (before != null && is_driver == before.get_is_driver ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.DriverGrid ();
                header.show_all ();
                row.set_header (header);
            } else {
                if (before != null && is_driver == before.get_is_driver () && update_available == before.get_update_available ()) {
                    row.set_header (null);
                    return;
                }

                var header = new Widgets.UpdatedGrid ();
                header.update (0, 0, updating_cache);
                header.show_all ();
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

            updating_all_apps = true;
            apps_done = 0; // Cancelled or updated apps
            apps_remaining_started = false;

            apps_to_update.clear ();
            // Collect all ready to update apps
            foreach (var package in get_packages ()) {
                if (package.update_available && !package.should_nag_update) {
                    apps_to_update.add (package);
                }
            }

            foreach (var row in list_box.get_children ()) {
                if (row is Widgets.PackageRow) {
                    ((Widgets.PackageRow) row).set_action_sensitive (false);
                }
            };

            // Update all updateable apps
            if (apps_to_update.size > 0) {
                // Prevent computer from sleeping while updating apps
                SuspendControl.get_default ().inhibit ();

                first_package = apps_to_update[0];
                first_package.info_changed.connect_after (after_first_package_info_changed);
                first_package.update.begin (() => {
                    on_app_update_end ();
                });
            } else {
                updating_all_apps = false;
            }
        }

        private void after_first_package_info_changed (Pk.Status status) {
            assert (!apps_remaining_started);

            /* Only interested if the first package has started running or has been cancelled (before starting) */
            if (status != Pk.Status.CANCEL && status != Pk.Status.RUNNING) {
                return;
            }

            /* Not interested in any future changes for first_package */
            first_package.info_changed.disconnect (after_first_package_info_changed);

            if (status != Pk.Status.CANCEL) { /* must  be running */
                apps_remaining_started = true;
                for (int i = 1; i < apps_to_update.size; i++) {
                    apps_to_update[i].update.begin (() => {
                        on_app_update_end ();
                    });
                }
            } else { /* it was aborted - do not start updating the rest */
                finish_updating_all_apps ();
            }
        }

        private void on_app_update_end () {
            update_mutex.@lock ();
            if (updating_all_apps) {
                apps_done++;

                if (apps_done >= apps_to_update.size) {
                    finish_updating_all_apps ();
                }
            }
            update_mutex.unlock ();
        }

        private void finish_updating_all_apps () {
            assert (updating_all_apps && packages_changing == 0);

            updating_all_apps = false;
            SuspendControl.get_default ().uninhibit ();

            /* Set the action button sensitive and emit "changed" on each row in order to update
             * the sort order and headers (any change would have been ignored while updating) */
            Idle.add_full (GLib.Priority.LOW, () => {
                foreach (var row in list_box.get_children ()) {
                    if (row is Widgets.PackageRow) {
                        var pkg_row = ((Widgets.PackageRow)(row));
                        var pkg = pkg_row.get_package ();

                        /* clear update information if the package was successfully updated */
                        /* This information is refreshed by Client on start up (log in) or at daily intervals */
                        /* TODO: Implement refresh on demand (or on list display?) */
                        if (pkg.state == AppCenterCore.Package.State.INSTALLED) {
                            pkg.change_information.clear_update_info ();
                        }

                        pkg_row.set_action_sensitive (true);
                        pkg_row.changed ();
                    }
                }
                return GLib.Source.REMOVE;
            });
        }
    }
}
