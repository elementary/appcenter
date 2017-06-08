/* Copyright 2017 elementary LLC. (https://elementary.io)
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
*
* Authored by: Blake Kostner <blake@elementary.io>
*/

public class AppCenterCore.Houston : Object {
    public signal void refreshed ();

    private const string HOUSTON_API_URL = "https://developer.elementary.io/api";
    private const string NEWEST_CATEGORY = "Newest";
    private const string UPDATED_CATEGORY = "Updated";
    private const string APPS_KEY = "apps";

    private Soup.Session session;
    private GLib.KeyFile cache_file = null;

    construct {
        session = new Soup.Session ();
    }

    public string[] get_newest () {
        if (cache_file == null) {
            init_keyfile ();
        }

        try {
            return cache_file.get_string_list (NEWEST_CATEGORY, APPS_KEY);
        } catch (Error e) {
            critical (e.message);
            return {};
        }
    }

    public string[] get_updated () {
        if (cache_file == null) {
            init_keyfile ();
        }

        try {
            return cache_file.get_string_list (UPDATED_CATEGORY, APPS_KEY);
        } catch (Error e) {
            critical (e.message);
            return {};
        }
    }

    private void init_keyfile () {
        cache_file = new GLib.KeyFile ();
        try {
            var path = get_cache_file_path ();
            var file = GLib.File.new_for_path (path);
            bool need_refresh = true;
            var parent = file.get_parent ();
            if (parent != null && !parent.query_exists ()) {
                parent.make_directory_with_parents ();
            }

            if (!file.query_exists ()) {
                file.create (GLib.FileCreateFlags.PRIVATE);
                cache_file.set_string_list (NEWEST_CATEGORY, APPS_KEY, {});
                cache_file.set_string_list (UPDATED_CATEGORY, APPS_KEY, {});
                cache_file.save_to_file (path);
            } else {
                var info = file.query_info (GLib.FileAttribute.TIME_MODIFIED, GLib.FileQueryInfoFlags.NONE);
                var modification_time = info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
                var modification_date = new GLib.DateTime.from_unix_local ((int64)modification_time);
                var now = new GLib.DateTime.now_local ();
                var difference = now.difference (modification_date);
                if (difference < GLib.TimeSpan.DAY) {
                    need_refresh = false;
                    uint timeout = (uint)((GLib.TimeSpan.DAY - difference)/GLib.TimeSpan.MILLISECOND);
                    GLib.Timeout.add (timeout, () => {
                        refresh.begin ();
                        return GLib.Source.REMOVE;
                    });
                }
            }

            cache_file.load_from_file (path, GLib.KeyFileFlags.KEEP_COMMENTS);
            if (need_refresh) {
                refresh.begin ();
            }
        } catch (Error e) {
            critical (e.message);
        }
    }

    private async void process_apps (string uri, string category) throws Error {
        var message = new Soup.Message ("GET", uri);
        try {
            var parser = new Json.Parser ();
            var stream = yield session.send_async (message);
            yield parser.load_from_stream_async (stream);
            var root_node = parser.get_root ();
            if (root_node.get_node_type () != Json.NodeType.OBJECT) {
                return;
            }

            unowned Json.Object root = root_node.get_object ();
            if (root.has_member ("errors") && root.get_array_member ("errors").get_length () > 0) {
                unowned string err = root.get_array_member ("errors").get_object_element (0).get_string_member ("title");
                throw new GLib.IOError.FAILED (err ?? "Error while talking to Houston");
            }

            if (root.has_member ("data")) {
                var data = root.get_array_member ("data");
                string[] app_ids = {};
                data.get_elements ().foreach ((id) => {
                    app_ids += id.get_string ();
                });

                cache_file.set_string_list (category, APPS_KEY, app_ids);
            }

        } catch (Error e) {
            throw e;
        }
    }

    private async void refresh () {
        var uri = HOUSTON_API_URL + "/newest/project";
        debug ("Requesting newest applications from %s", uri);
        try {
            yield process_apps (uri, NEWEST_CATEGORY);
        } catch (Error e) {
            critical (e.message);
        }

        uri = HOUSTON_API_URL + "/newest/release";
        debug ("Requesting recently updated applications from %s", uri);
        try {
            yield process_apps (uri, UPDATED_CATEGORY);
        } catch (Error e) {
            critical (e.message);
        }

        lock (cache_file) {
            try {
                cache_file.save_to_file (get_cache_file_path ());
            } catch (Error e) {
                critical (e.message);
            }
        }

        refreshed ();
        uint timeout = (uint)(GLib.TimeSpan.DAY/GLib.TimeSpan.MILLISECOND);
        GLib.Timeout.add (timeout, () => {
            refresh.begin ();
            return GLib.Source.REMOVE;
        });
    }

    private static string get_cache_file_path () {
        return GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), "io.elementary.appcenter", "houston.conf");
    }

    private static GLib.Once<Houston> instance;
    public static unowned Houston get_default () {
        return instance.once (() => { return new Houston (); });
    }
}
