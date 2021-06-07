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
    private const int HTTP_HEAD_TIMEOUT = 3000;
    private const int HTTP_DOWNLOAD_TIMEOUT = 5000;

    private const int MAX_CACHE_SIZE = 100000000;

    private GLib.File screenshot_folder;

    construct {
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
            if (!yield screenshot_folder.measure_disk_usage_async (
                FileMeasureFlags.NONE,
                GLib.Priority.DEFAULT,
                null,
                null,
                out screenshot_usage,
                out dirs,
                out files
            )) {
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

        // GVFS handles HTTP URIs for us
        var remote_file = File.new_for_uri (url);
        var local_file = File.new_for_path (path);

        GLib.DateTime? remote_mtime = null;
        try {
            // Setup our own timeout for GVFS, as the HTTP backend has no timeout
            var cancellable = new GLib.Cancellable ();
            uint cancel_source = 0;
            cancel_source = Timeout.add (HTTP_HEAD_TIMEOUT, () => {
                cancel_source = 0;
                cancellable.cancel ();
                return GLib.Source.REMOVE;
            });

            // GVFS uses libsoup to get the mtime via a HEAD request
            var file_info = yield remote_file.query_info_async (
                GLib.FileAttribute.TIME_MODIFIED,
                FileQueryInfoFlags.NONE,
                GLib.Priority.DEFAULT,
                cancellable
            );

            if (cancel_source != 0) {
                GLib.Source.remove (cancel_source);
            }

            remote_mtime = get_modification_time (file_info);
        } catch (Error e) {
            warning ("Error getting modification time of remote screenshot file: %s", e.message);
        }

        if (local_file.query_exists ()) {
            GLib.DateTime? file_time = null;
            try {
                var file_info = yield local_file.query_info_async (GLib.FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                file_time = get_modification_time (file_info);
            } catch (Error e) {
                warning ("Error getting modification time of cached screenshot file: %s", e.message);
            }

            // Local file is up to date
            if (file_time != null && remote_mtime != null && file_time.equal (remote_mtime)) {
                return true;
            }
        }

        // We don't have the local copy, or it's not up to date, download it
        try {
            var cancellable = new GLib.Cancellable ();
            uint cancel_source = 0;
            cancel_source = Timeout.add (HTTP_DOWNLOAD_TIMEOUT, () => {
                cancel_source = 0;
                cancellable.cancel ();
                return GLib.Source.REMOVE;
            });

            yield remote_file.copy_async (
                local_file,
                FileCopyFlags.OVERWRITE | FileCopyFlags.TARGET_DEFAULT_PERMS,
                GLib.Priority.DEFAULT,
                cancellable
            );

            if (cancel_source != 0) {
                GLib.Source.remove (cancel_source);
            }
        } catch (Error e) {
            warning ("Unable to download screenshot from %s: %s", url, e.message);
            return false;
        }

        return true;
    }

    private static GLib.DateTime? get_modification_time (GLib.FileInfo info) {
        GLib.DateTime? datetime = null;

#if GLIB_2_62
        datetime = info.get_modification_date_time ();
#else
        var mtime = info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
        if (mtime != 0) {
            datetime = new DateTime.from_unix_utc ((int64)mtime);

            var usec = info.get_attribute_uint32 (GLib.FileAttribute.TIME_MODIFIED_USEC);
            if (usec != 0) {
                datetime = datetime.add (usec);
            }
        }
#endif

        return datetime;
    }
}
