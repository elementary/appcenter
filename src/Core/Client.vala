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

namespace AppCenterCore {
    public class Client : Object {
        public signal void operation_progress (Operation operation, int progress);
        public signal void operation_changed (Operation operation, bool running, string info = "");

        public signal void connection_changed ();

        public signal void updates_available ();


        public bool connected { public get; private set; }
        public bool operation_running { public get; private set; default = false; }

        private Gee.LinkedList<Pk.Task> task_list;
        private Gee.HashMap<string, AppCenterCore.Package> package_list;
        private Pk.Control control;
        private AppStream.Database appstream_database;

        private Client () {
            task_list = new Gee.LinkedList<Pk.Task> ();
            package_list = new Gee.HashMap<string, AppCenterCore.Package> (null, null);

            appstream_database = new AppStream.Database ();
            appstream_database.open ();

            control = new Pk.Control ();
            control.get_properties_async.begin (null, (obj, res) => {
                try {
                    var result = control.get_properties_async.end (res);
                    if (result) {
                        warning ("Achieved");
                    }
                } catch (Error e) {
                    critical (e.message);
                }
            });
            //connected = control.connected;
            connected = true;
            connection_changed ();
        }

        public int get_task_count () { return task_list.size; }

        private Pk.Task request_task () {
            Pk.Task task = new Pk.Task ();
            task_list.add (task);
            return task;
        }

        private void release_task (Pk.Task task) {
            task_list.remove (task);
        }

        public async void install_package (Info info) {
            Pk.Task install_task = request_task ();
            operation_changed (Operation.PACKAGE_INSTALL, true, info.display_name);

            try {
                yield install_task.install_packages_async ({ info.package_id, null }, null,
                    (prog, type) => operation_progress (Operation.PACKAGE_INSTALL, prog.percentage));
            } catch (Error e) {
                critical (e.message);
            }

            operation_changed (Operation.PACKAGE_INSTALL, false);
            release_task (install_task);
        }

        public async void update_package (Info info) {
            Pk.Task update_task = request_task ();
            operation_changed (Operation.PACKAGE_UPDATE, true, info.display_name);

            try {
                yield update_task.update_packages_async ({ info.package_id, null }, null,
                    (prog, type) => operation_progress (Operation.PACKAGE_UPDATE, prog.percentage));
            } catch (Error e) {
                critical (e.message);
            }
        }

        public async void refresh_updates () {
            Pk.Task update_task = request_task ();
            operation_changed (Operation.UPDATE_REFRESH, true);

            try {
                Pk.Results result = yield update_task.get_updates_async (Pk.Filter.INSTALLED, null, (t, p) => { });
                result.get_package_array ().foreach ((pk_package) => {
                    AppCenterCore.Package package = package_list.get (pk_package.get_name ());
                    if (package == null) {
                        warning (pk_package.get_name ());
                        package = new AppCenterCore.Package (pk_package);
                        package_list.set (pk_package.get_name (), package);
                    }

                    package.update_available = true;
                });
            } catch (Error e) {
                critical (e.message);
            }

            operation_changed (Operation.UPDATE_REFRESH, false);
            release_task (update_task);
            updates_available ();
        }

        public async void refresh_cache () {
            Pk.Task cache_task = request_task ();
            operation_changed (Operation.CACHE_REFRESH, true);

            try {
                yield cache_task.refresh_cache_async (false, null,
                        (prog, type) => operation_progress (Operation.CACHE_REFRESH, prog.percentage));
            } catch (Error e) {
                critical (e.message);
            }

            operation_changed (Operation.CACHE_REFRESH, false);
            release_task (cache_task);
        }

        public async Gee.Collection<AppCenterCore.Package> get_installed_applications () {
            Pk.Task packages_task = request_task ();
            var packages = new Gee.TreeSet<AppCenterCore.Package> ();

            try {
                var install_filter = Utils.bitfield_from_filter (Pk.Filter.INSTALLED);
                var new_filter = Utils.bitfield_from_filter (Pk.Filter.NEWEST);
                Pk.Results result = yield packages_task.get_packages_async (install_filter|new_filter, null,
                        (prog, type) => {});
                result.get_package_array ().foreach ((pk_package) => {
                    AppCenterCore.Package package = package_list.get (pk_package.get_name ());
                    if (package == null) {
                        package = new AppCenterCore.Package (pk_package);
                        package_list.set (pk_package.get_name (), package);
                    }
                    packages.add (package);
                });
            } catch (Error e) {
                critical (e.message);
            }
            

            release_task (packages_task);
            return packages;
        }

        public async Gee.Collection<AppCenterCore.Package> get_applications (Pk.Bitfield filter, Pk.Group group, GLib.Cancellable? cancellable = null) {
            Pk.Task packages_task = request_task ();
            var packages = new Gee.TreeSet<AppCenterCore.Package> ();

            try {
                var group_string = Pk.Group.enum_to_string (group);
                Pk.Results result = yield packages_task.search_groups_async (filter, {group_string, null}, cancellable, () => {});
                result.get_package_array ().foreach ((pk_package) => {
                    AppCenterCore.Package package = package_list.get (pk_package.get_name ());
                    if (package == null) {
                        package = new AppCenterCore.Package (pk_package);
                        package_list.set (pk_package.get_name (), package);
                    }

                    packages.add (package);
                });
            } catch (Error e) {
                critical (e.message);
            }
            

            release_task (packages_task);
            return packages;
        }

        public async Gee.Collection<Pk.Details> get_packages_details (string[] packages, GLib.Cancellable? cancellable = null) {
            Pk.Task details_task = request_task ();
            var details = new Gee.TreeSet<Pk.Details> ();
            try {
                Pk.Results result = yield details_task.get_details_async (packages, cancellable, () => {});
                result.get_details_array ().foreach ((detail) => {
                    details.add (detail);
                });
            } catch (Error e) {
                critical (e.message);
            }

            release_task (details_task);
            return details;
        }

        public Gee.Collection<AppStream.Component> get_component_for_app (string app) {
            var comps = appstream_database.find_components_by_term ("pkg:%s".printf (app), null);
            var components = new Gee.TreeSet<AppStream.Component> ();
            comps.foreach ((component) => {
                components.add (component);
            });

            return components;
        }

        private static GLib.Once<Client> instance;
        public static unowned Client get_default () {
            return instance.once (() => { return new Client (); });
        }
    }
}
