/*-
 * Copyright 2020 elementary, Inc. (https://elementary.io)
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
 */

public class AppCenterCore.ScreenshotCache : GLib.Object {
    private const int MAX_CACHE_SIZE = 100000000;

    private Soup.Session session;

    private GLib.File screenshot_folder;

    construct {
        session = new Soup.Session ();
        session.timeout = 5;

        var screenshot_path = Path.build_filename (
            GLib.Environment.get_user_cache_dir (),
            Build.PROJECT_NAME,
            "screenshots"
        );

        debug ("screenshot path is at %s", screenshot_path);

        screenshot_folder = GLib.File.new_for_path (screenshot_path);

        if (!screenshot_folder.query_exists ()) {
            try {
                if (!screenshot_folder.make_directory_with_parents ()) {
                    return;
                }
            } catch (Error e) {
                warning ("Error creating screenshot cache folder: %s", e.message);
                return;
            }
        }

        maintain.begin ();
    }

    // Prune the cache directory if it exceeds the `MAX_CACHE_SIZE`.
    private async void maintain () {
        uint64 screenshot_usage = 0, dirs = 0, files = 0;
        try {
            if (!yield screenshot_folder.measure_disk_usage_async (FileMeasureFlags.NONE, GLib.Priority.DEFAULT, null, null, out screenshot_usage, out dirs, out files)) {
                return;
            }
        } catch (Error e) {
            warning ("Error measuring size of screenshot cache: %s", e.message);
        }

        debug ("Screenshot folder size is %s", GLib.format_size (screenshot_usage));

        if (screenshot_usage > MAX_CACHE_SIZE) {
            yield delete_oldest_files (screenshot_usage);
        }
    }

    // Delete the oldest files in the screenshot cache until the cache is less than the max size.
    private async void delete_oldest_files (uint64 screenshot_usage) {
        var file_list = new Gee.ArrayList<GLib.FileInfo> ();

        FileEnumerator enumerator;
        try {
            enumerator = yield screenshot_folder.enumerate_children_async (
                GLib.FileAttribute.STANDARD_NAME + "," +
                GLib.FileAttribute.STANDARD_TYPE + "," +
                GLib.FileAttribute.STANDARD_SIZE + "," +
                GLib.FileAttribute.TIME_CHANGED,
                FileQueryInfoFlags.NONE
            );
        } catch (Error e) {
            warning ("Unable to create enumerator to delete cached screenshots: %s", e.message);
            return;
        }

        FileInfo? info;

        // Get a list of the files in the screenshot cache folder
        try {
            while ((info = enumerator.next_file (null)) != null) {
                if (info.get_file_type () == FileType.REGULAR) {
                    file_list.add (info);
                }
            }
        } catch (Error e) {
            warning ("Error while enumerating screenshot cache dir: %s", e.message);
        }

        // Sort the files by ctime (when file metadata was changed, not content)
        file_list.sort ((a, b) => {
            uint64 a_time = a.get_attribute_uint64 (GLib.FileAttribute.TIME_CHANGED);
            uint64 b_time = b.get_attribute_uint64 (GLib.FileAttribute.TIME_CHANGED);

            if (a_time < b_time) {
                return -1;
            } else if (a_time == b_time) {
                return 0;
            } else {
                return 1;
            }
        });

        // Start deleting files by oldest ctime until we get below the limit
        uint64 current_usage = screenshot_usage;
        foreach (var file_info in file_list) {
            if (current_usage > MAX_CACHE_SIZE) {
                var file = screenshot_folder.resolve_relative_path (file_info.get_name ());
                if (file == null) {
                    continue;
                }

                debug ("deleting screenshot at %s to free cache", file.get_path ());
                try {
                    yield file.delete_async (GLib.Priority.DEFAULT);
                    current_usage -= file_info.get_size ();
                } catch (Error e) {
                    warning ("Unable to delete cached screenshot file '%s': %s", file.get_path (), e.message);
                }
            } else {
                break;
            }
        }
    }

    // Generate a screenshot path based on the URL to be fetched.
    private string generate_screenshot_path (string url) {
        int ext_pos = url.last_index_of (".");
        string extension = url.slice ((long) ext_pos, (long) url.length);
        if (extension.contains ("/")) {
            extension = "";
        }

        return Path.build_filename (
            screenshot_folder.get_path (),
            "%02x".printf (url.hash ()) + extension
        );
    }

    // Returns true if theres a screenshot to load in the out parameter @path
    public async bool fetch (string url, out string path) {
        path = generate_screenshot_path (url);

        var file = File.new_for_path (path);

        var msg = new Soup.Message ("HEAD", url);

        try {
            yield session.send_async (msg);
        } catch (Error e) {
            warning ("HEAD request of %s failed: %s", url, e.message);

            // Use the cached file if it exists
            return file.query_exists ();
        }

        var modified = msg.response_headers.get_one ("Last-Modified");

        if (msg.status_code != Soup.Status.OK || modified == null) {
            warning ("HEAD request to get modified time of %s failed: %s", url, msg.reason_phrase);

            // Use the cached file if it exists
            return file.query_exists ();
        }

        GLib.DateTime? modified_time = null;
        // Parse the HTTP date format using Soup
        var http_date = new Soup.Date.from_string (modified);
        if (http_date != null) {
            // Convert it to ISO8601
            string? iso8601_string = http_date.to_string (Soup.DateFormat.ISO8601);
            if (iso8601_string != null) {
                // Now to a GLib.DateTime
                modified_time = new GLib.DateTime.from_iso8601 (iso8601_string, null);
            }
        }

        if (modified_time == null) {
            warning ("Converting Last-Modified header (%s) of HEAD request to GLib.DateTime failed", modified);

            // Use the cached file if it exists
            return file.query_exists ();
        }

        if (file.query_exists ()) {
            GLib.DateTime? file_time = null;
            try {
                var file_info = yield file.query_info_async (GLib.FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                file_time = file_info.get_modification_date_time ();
            } catch (Error e) {
                warning ("Error getting modification time of cached screenshot file: %s", e.message);
            }

            // Local file is up to date
            if (file_time != null && file_time.equal (modified_time)) {
                return true;
            }
        }

        var remote_file = File.new_for_uri (url);
        try {
            // We don't need to set the mtime on the downloaded file, GLib does this for us
            yield remote_file.copy_async (file, FileCopyFlags.OVERWRITE | FileCopyFlags.TARGET_DEFAULT_PERMS);
        } catch (Error e) {
            warning ("Unable to download screenshot from %s: %s", url, e.message);
            return false;
        }

        return true;
    }
}
