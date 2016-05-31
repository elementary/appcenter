//
//  Copyright (C) 2014 Corentin Noël
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace AppCenterDaemon {
    const OptionEntry[] options =  {
        { "debug", 'd', 0, OptionArg.NONE, out has_debug,
        "Display debug statements on stdout", null},
        { "version", 0, 0, OptionArg.NONE, out has_version,
        "Display version number", null},
        { null }
    };

    private static bool has_debug;
    private static bool has_version;
    private static Application app;
    private static GLib.DateTime last_cache_update;
    private static uint updates_number;

    private static void on_exit (int signum) {
        debug ("Exiting");
        app.release ();
    }

    public static int main (string[] args) {
        Process.signal (ProcessSignal.INT, on_exit);
        Process.signal (ProcessSignal.TERM, on_exit);

        app = new Application ("org.pantheon.appcenter-daemon", GLib.ApplicationFlags.IS_SERVICE);
        app.add_main_option_entries (options);

        Granite.Services.Logger.initialize (_("App Center"));
        Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.WARN;

        if (has_debug) {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
        }

        if (has_version) {
            message ("%s (Daemon)", _("App Center"));
            message ("%s", Build.VERSION);
            return 0;
        }

        app.hold ();
        var notification_action = new SimpleAction ("open-application", null);
        notification_action.activate.connect (() => {
            try {
                string[] spawn_args = {"appcenter", "--show-updates"};
                string[] spawn_env = Environ.get ();
                Pid child_pid;

                Process.spawn_async ("/usr/bin", spawn_args, spawn_env,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out child_pid);
            } catch (SpawnError e) {
                critical (e.message);
            }
        });

        app.add_action (notification_action);
        app.set_default ();
        try {
            app.register ();
        } catch (Error e) {
            critical (e.message);
        }

        updates_number = 0U;

        var control = new Pk.Control ();
        try {
            control.get_properties ();
        } catch (Error e) {
            critical (e.message);
        }

        control.updates_changed.connect (() => {
            updates_changed ();
        });

        control.notify["connected"].connect (() => {
            if (control.connected) {
                update_cache ();
            }
        });

        Bus.own_name (BusType.SESSION, "org.pantheon.AppCenter", BusNameOwnerFlags.NONE, on_bus_aquired,
                  () => {},
                  () => critical ("Could not aquire name"));

        update_installed_cache ();
        update_cache ();

        return app.run (args);
    }

    public static void update_installed_cache () {
        var packages_task = new AppCenter.Task ();
        var filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED, Pk.Filter.NEWEST);
        try {
            var keyfile = new KeyFile ();
            var db_path = get_db ();
            keyfile.load_from_file (db_path, GLib.KeyFileFlags.NONE);
            Pk.Results result = packages_task.get_packages_sync (filter, null, (prog, type) => {});
            result.get_package_array ().foreach ((pk_package) => {
                db_add_installed (keyfile, pk_package.get_id ());
            });
            keyfile.save_to_file (db_path);
        } catch (Error e) {
            critical (e.message);
        }
    }

    public static void updates_changed () {
        var update_task = new AppCenter.Task ();
        try {
            Pk.Results result = update_task.get_updates_sync (0, null, (t, p) => { });
            bool was_empty = updates_number == 0U;
            updates_number = get_package_count (result.get_package_array ());
            if (was_empty && updates_number != 0U) {
                string title = ngettext ("Update Available", "Updates Available", updates_number);
                var notification = new Notification (title);
                notification.set_body (ngettext ("%u update is available for your system", "%u updates are available for your system", updates_number).printf (updates_number));
                notification.set_icon (new ThemedIcon ("software-update-available"));
                notification.set_default_action ("app.open-application");
                Application.get_default ().send_notification ("updates", notification);
            } else {
                Application.get_default ().withdraw_notification ("updates");
            }

#if HAVE_UNITY
            var launcher_entry = Unity.LauncherEntry.get_for_desktop_file ("appcenter.desktop");
            launcher_entry.count = updates_number;
            launcher_entry.count_visible = updates_number != 0U;
#endif
        } catch (Error e) {
            critical (e.message);
        }
    }

    public static uint get_package_count (GLib.GenericArray<weak Pk.Package> package_array) {
        var appstream_database = new AppStream.Database ();
        appstream_database.open ();
        var comp_map = new Gee.HashMap<string, AppStream.Component> ();
        appstream_database.get_all_components ().foreach ((comp) => {
            foreach (var pkg_name in comp.get_pkgnames ()) {
                comp_map.set (pkg_name, comp);
            }
        });

        bool os_update_found = false;
        var result_comp = new Gee.TreeSet<AppStream.Component> ();
        package_array.foreach ((pk_package) => {
            var comp = comp_map.get (pk_package.get_name ());
            if (comp != null) {
                result_comp.add (comp);
            } else {
                os_update_found = true;
            }
        });

        uint size = result_comp.size;
        if (os_update_found) {
            size++;
        }

        return size;
    }

    public static void update_cache (bool force = false) {
        // One cache update a day, keeps the doctor away!
        if (last_cache_update == null || (new DateTime.now_local ()).difference (last_cache_update) >= GLib.TimeSpan.DAY || force) {
            var refresh_task = new AppCenter.Task ();
                refresh_task.refresh_cache_async.begin (false, null, (t, p) => { }, (obj, res) => {
                    try {
                        refresh_task.refresh_cache_async.end (res);
                        last_cache_update = new DateTime.now_local ();
                    } catch (Error e) {
                        critical (e.message);
                    }

                    updates_changed ();
                });
        }

        GLib.Timeout.add_seconds (60*60*24, () => {
            update_cache ();
            return GLib.Source.REMOVE;
        });
    }

    [DBus (name = "org.pantheon.AppCenter")]
    public class UpdateSignals : Object {
        public void refresh_cache (bool force) {
            update_cache (force);
        }

        public void refresh_updates () {
            updates_changed ();
        }

        public string[] get_installed_packages () {
            return db_get_installed ();
        }
    }

    public static void on_bus_aquired (DBusConnection conn) {
        try {
            conn.register_object ("/org/pantheon/appcenter", new UpdateSignals ());
        } catch (IOError e) {
            critical ("Could not register service");
        }
    }

    /*
     * basic savedstate management.
     * Everything is refreshed at session start.
     */

    public static void db_add_installed (KeyFile keyfile, string pkg_name) {
        try {
            var strings = keyfile.get_string_list ("SavedState", "installed");
            if (pkg_name in strings) {
                return;
            } else {
                strings += pkg_name;
                keyfile.set_string_list ("SavedState", "installed", strings);
            }
        } catch (Error e) {
            try {
                keyfile.set_string_list ("SavedState", "installed", {pkg_name});
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    public static string[] db_get_installed () {
        var keyfile = new KeyFile ();
        try {
            keyfile.load_from_file (get_db (), GLib.KeyFileFlags.NONE);
            return keyfile.get_string_list ("SavedState", "installed");
        } catch (Error e) {
            critical (e.message);
            return {};
        }
    }

    public static string db_file;
    public static string get_db () {
        if (db_file != null) {
            return db_file;
        }

        var ret = GLib.DirUtils.create_with_parents (GLib.Environment.get_tmp_dir () + Path.DIR_SEPARATOR_S + ".appcenter", 0755);
        if (ret == -1) {
            error ("Error creating the temporary folder: GFileError #%d", GLib.FileUtils.error_from_errno (GLib.errno));
        }

        db_file = Path.build_path (Path.DIR_SEPARATOR_S, GLib.Environment.get_tmp_dir (), ".appcenter", "db-XXXXXX");
        var fd = GLib.FileUtils.mkstemp (db_file);
        if (fd != -1) {
            GLib.FileUtils.close (fd);
        } else {
            db_file = null;
            error ("Error create the temporary file: GFileError #%d", GLib.FileUtils.error_from_errno (GLib.errno));
        }

        return db_file;
    }
}

public class AppCenter.Task : Pk.Task {
    public Task () {
        
    }

    public override void untrusted_question (uint request, Pk.Results results) {
        user_accepted (request);
    }
}
