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
    /** AppList for Category and Search Views.  Sorts by name and does not show Uninstall Button **/
    public class AppListView : AbstractAppList {

        public AppListView () {}

        protected override Widgets.AppListRow make_row (AppCenterCore.Package package)  {
            return (Widgets.AppListRow)(new Widgets.PackageRow (package, action_button_group, false));
        }
    }

    /** AppList for the Updates View.  Sorts update_available first and shows headers.
      * Does not show Uninstall Button **/
    public class AppListUpdateView : AbstractAppList {
        private bool updates_on_top;
        private Widgets.UpdateHeaderRow updates_header;
        private Widgets.UpdateHeaderRow updated_header;
        private Widgets.AppActionButton update_all_button;
        private Widgets.AppActionButton restart_button;
        private bool updating_all_apps = false;
        private bool apps_remaining_started = false;
        private GLib.Mutex update_mutex;
        private uint apps_done = 0;
        private Gee.LinkedList<AppCenterCore.Package> apps_to_update;
        private AppCenterCore.Package first_package;
        private SuspendControl sc;

        private bool _updating_cache;
        public bool updating_cache {
            get {
                return _updating_cache;
            }
            set {
                if (_updating_cache != value) {
                    _updating_cache = value;
                    update_headers ();
                }
            }
        }

        construct {
            updates_on_top = true;

            update_all_button = new Widgets.AppActionButton (_("Update All"));
            update_all_button.set_suggested_action_header ();
            update_all_button.clicked.connect (on_update_all);
            update_all_button.no_show_all = true;
            action_button_group.add_widget (update_all_button);
            
            restart_button = new Widgets.AppActionButton (_("Restart Now"));
            restart_button.set_suggested_action_header ();
            //restart_button.clicked.connect ();
            restart_button.no_show_all = true;
            action_button_group.add_widget (restart_button);

            updates_header = new Widgets.UpdateHeaderRow.updates ();
            updates_header.add_widget (update_all_button);

            updated_header = new Widgets.UpdateHeaderRow.updated ();
            updated_header.add_widget (restart_button);

            list_box.add (updates_header);
            list_box.add (updated_header);

            update_mutex = GLib.Mutex ();
            apps_to_update = new Gee.LinkedList<AppCenterCore.Package> ();

            sc = new SuspendControl ();
        }

        public AppListUpdateView () {
            _updating_cache = true;
        }

        protected override void after_add_remove_change_row () {update_headers ();}

        protected override Widgets.AppListRow make_row (AppCenterCore.Package package) {
            return (Widgets.AppListRow)(new Widgets.PackageRow (package, action_button_group, false));
        }

        protected override void on_package_changing (AppCenterCore.Package package, bool is_changing) {
            base.on_package_changing (package, is_changing);
            update_all_button.sensitive = packages_changing == 0;
        }

        [CCode (instance_pos = -1)]
        protected override int package_row_compare (Widgets.AppListRow row1, Widgets.AppListRow row2) {
            bool a_is_header = !row1.has_package ();
            bool b_is_header = !row2.has_package ();
            bool a_has_updates = row1.get_update_available ();
            bool b_has_updates = row2.get_update_available ();

            if (a_is_header) {
                return (a_has_updates || !b_has_updates) ? -1 : 1;
            } else if (b_is_header) {
                return (b_has_updates || !a_has_updates) ? 1 : -1;
            }

            bool a_is_os = row1.get_is_os_updates ();
            bool b_is_os = row2.get_is_os_updates ();

            if (a_is_os || b_is_os) { /* OS update row sorts ahead of other update rows */
                return a_is_os ? -1 : 1;
            } else if ((a_has_updates && !b_has_updates) || (!a_has_updates && b_has_updates)) { /* Updates rows sort ahead of updated rows */
                return a_has_updates ? -1 : 1;
            }

            return row1.get_name_label ().collate (row2.get_name_label ()); /* Else sort in name order */
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
                if (package.update_available) {
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
                sc.inhibit ();

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
            sc.uninhibit ();

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

        private void update_headers () {
            /* Do not repeatedly update headers while rapidly adding packages to list */
            schedule_header_update ();
        }

        uint grid_timeout_id = 0;
        private void schedule_header_update () {
            if (grid_timeout_id > 0) {
                return;
            }

            grid_timeout_id = GLib.Timeout.add (20, () => {
                update_updates_grid ();
                update_updated_grid ();
                grid_timeout_id = 0;
                return false;
            });
        }

        private void update_updates_grid () {
            uint update_numbers = 0U;
            uint64 update_real_size = 0ULL;
            foreach (var package in get_packages ()) {
                if (package.state == AppCenterCore.Package.State.UPDATE_AVAILABLE) {
                    update_numbers++;
                    update_real_size += package.change_information.get_size ();
                }
            }

            updates_header.update (update_numbers, update_real_size, updating_cache, false);
            update_all_button.visible = !updating_cache && update_numbers > 0;
        }

        private void update_updated_grid () {
            if (!updating_all_apps && !updating_cache) {
                var client = AppCenterCore.Client.get_default ();
                client.check_restart.begin (false, (obj, res) => {
                    var restart = client.check_restart.end (res);
                    
                    updated_header.update (0, 0, updating_cache, restart);
                    restart_button.visible = restart;
                });
            } else {        
                updated_header.update (0, 0, updating_cache, false);
            }
        }
    }
}
