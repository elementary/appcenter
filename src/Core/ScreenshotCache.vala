public class AppCenterCore.ScreenshotCache {
    private const int MAX_CACHE_SIZE = 100000000;

    public string screenshot_path;

    // Atomic integer for keeping track of the current screenshot usage.
    private int screenshot_usage;

    public ScreenshotCache () {
        screenshot_path = GLib.Environment.get_user_cache_dir () + "/appcenter/screenshots";
        if (GLib.DirUtils.create_with_parents (screenshot_path, 0755) == -1) {
            critical (
                "Error creating the temporary folder: GFileError #%d",
                GLib.FileUtils.error_from_errno (GLib.errno)
            );
        }

        new Thread<bool> ("screenshot_cache", () => {
            cache_removal_event_loop ();
            return true;
        });
    }

    // When `screenshot_usage` exceeds `MAX_CACHE_SIZE`, the oldest files (based on ctime) will be deleted.
    private void cache_removal_event_loop () {
        screenshot_usage = summarize_screenshot_usage ();
        while (true) {
            if (AtomicInt.get (ref screenshot_usage) > MAX_CACHE_SIZE) {
                delete_oldest_files ();
            }

            Thread.usleep (1000000);
        }
    }

    // Delete the oldest files in the screenshot cache until the cache is less than the max size.
    private void delete_oldest_files () {
        Dir dir = Dir.open (screenshot_path, 0);
        string? name = null;

        while (AtomicInt.get (ref screenshot_usage) > MAX_CACHE_SIZE) {
            string? oldest_path = null;
            time_t oldest_time = 0;
            while ((name = dir.read_name ()) != null) {
                string entry = Path.build_filename (screenshot_path, name);
                Stat fstat = Stat (entry);
                if (oldest_time == 0 || fstat.st_mtime < oldest_time) {
                    oldest_time = fstat.st_mtime;
                    oldest_path = entry;
                }
            }

            if (null != oldest_path) {
                var file = File.new_for_path (oldest_path);
                try {
                    FileInfo info = file.query_info ("standard::*", FileQueryInfoFlags.NONE);
                    var size = (int) info.get_size ();
                    file.delete ();
                    AtomicInt.set (ref screenshot_usage, AtomicInt.get (ref screenshot_usage) - size);
                } catch (Error e) {
                    stderr.printf ("failed to delete %s: %s\n", oldest_path, e.message);
                }
            }
        }
    }

    // Get the combined size of the screenshot cache.
    private int summarize_screenshot_usage () {
        Dir dir = Dir.open (screenshot_path, 0);
        string? name = null;
        int size = 0;

        while ((name = dir.read_name ()) != null) {
            string entry = Path.build_filename (screenshot_path, name);
            File file = File.new_for_path (entry);
            FileInfo info = file.query_info ("standard::*", FileQueryInfoFlags.NONE);
            size += (int) info.get_size ();
        }

        return size;
    }

    /*
     * Fetches a screenshot in a background thread.
     * 
     * A result indicating the success (0) will be returned as the result upon completion.
     */
    public async int fetch (string url, out File out_file) {
        SourceFunc callback = fetch.callback;
        int ext_pos = url.last_index_of (".");
        string extension = url.slice ((long) ext_pos, (long) url.length);
        string file_name = "%02x".printf (url.hash ());

        string path = screenshot_path + "/" + file_name + extension;
        int result = 0;

        var file = File.new_for_path (path);

        new Thread<bool> ("fetching_screenshot", () => {
            FileIOStream stream;
            var session = new Soup.Session ();
            bool download = true;
            time_t mtime = 0;

            try {
                if (file.query_exists ()) {
                    stream = file.open_readwrite ();
                    var msg = new Soup.Message ("HEAD", url);
                    session.send_message (msg);

                    // Compare the mtimes of the header and the existing file.
                    // If they're the same, we do not need to download it again.
                    var modified = msg.response_headers.get_one ("Last-Modified");
                    if (null != modified) {
                        var time = new Soup.Date.from_string (modified).to_time_t ();
                        if (Stat (path).st_mtime != time) {
                            mtime = time;
                        } else {
                            download = false;
                        }
                    }
                } else {
                    stream = file.create_readwrite (FileCreateFlags.NONE);
                }
            } catch (Error e) {
                debug (e.message);
                result = -1;
                return true;
            }

            if (download) {
                stderr.printf ("downloading %s to %s\n", url, path);

                try {
                    FileInfo info = file.query_info ("standard::*", FileQueryInfoFlags.NONE);
                    AtomicInt.set (ref screenshot_usage, AtomicInt.get (ref screenshot_usage) - (int) info.get_size ());
                } catch (Error e) {
                    stderr.printf ("unable to get file info of %s\n before downloading: %s\n", path, e.message);
                }

                var msg = new Soup.Message ("GET", url);
                session.send_message (msg);
                var data = msg.response_body.data;

                // Ensure that what was downloaded is an image, before writing it.
                var content = msg.response_headers.get_one ("Content-Type");
                if (null != content && content.has_prefix ("image/")) {
                    var output = stream.output_stream;
                    try {
                        size_t written;
                        output.write_all (data, out written);
                        AtomicInt.add (ref screenshot_usage, (int) written);
                        output.close ();
                    } catch (IOError e) {
                        try {
                            file.delete ();
                        } catch (Error e) {
                            stderr.printf ("failed to delete %s: %s\n", path, e.message);
                        }

                        debug (e.message);
                        result = -1;
                        return true;
                    }

                    var modified = msg.response_headers.get_one ("Last-Modified");
                    if (null != modified) {
                        mtime = new Soup.Date.from_string (modified).to_time_t ();
                    }
                }
            }

            if (0 != mtime) {
                set_mtime (path, mtime);
            }

            Idle.add ((owned)callback);
            return true;
        });

        yield;
        out_file = file;
        return result;
    }

    // Used for setting the `Last-Modified` header's value to the screenshot that was downloaded.
    private void set_mtime (string path, time_t mtime) {
        Stat fstat = Stat (path);

        var utimbuf = UTimBuf () {
            actime = fstat.st_atime,
            modtime = mtime
        };

        FileUtils.utime (path, utimbuf);
    }
}
