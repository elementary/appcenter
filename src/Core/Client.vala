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

        public Gee.ArrayList<Summary> update_list { public get; private set; }

        public bool connected { public get; private set; }
        public bool operation_running { public get; private set; default = false; }

        private Gee.LinkedList<Pk.Task> task_list;
        private Pk.Control control;

        private Client () {
            task_list = new Gee.LinkedList<Pk.Task> ();
            update_list = new Gee.ArrayList<Summary> ();

            control = new Pk.Control ();
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
                result.get_package_array ().foreach ((package) => {
                    update_list.add (new Summary (package.package_id));
                });
            } catch (Error e) {
                critical (e.message);
            }

            operation_changed (Operation.UPDATE_REFRESH, false);
            release_task (update_task);
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

        public async Gee.Collection<Pk.Package> get_applications () {
            Pk.Task packages_task = request_task ();
            var packages = new Gee.TreeSet<Pk.Package> ();

            try {
                Pk.Results result = yield packages_task.get_packages_async (Pk.Filter.NOT_DEVELOPMENT, null,
                        (prog, type) => {});
                result.get_package_array ().foreach ((package) => {
                    packages.add (package);
                });
            } catch (Error e) {
                critical (e.message);
            }
            

            release_task (packages_task);
            return packages;
        }

        private static GLib.Once<Client> instance;
        public static unowned Client get_default () {
            return instance.once (() => { return new Client (); });
        }
    }
}
