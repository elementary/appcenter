/*
 * In the event that the package manager is in an incomplete configuration state,
 * attempt to resolve it.
 */
public async int dpkg_configure_check () {
    var result = 0;
    var requires_configure = yield dpkg_requires_configure ();
    if (requires_configure) {
        result = yield dpkg_configure ();
    }

    return result;
}

/*
 * Sometimes the package manager can be in an incomplete state. This is detected
 * by checking the output of `dpkg -l` to see if a package's line begins with
 * the `iF` flag. This indicates that it was installed, but not configured.
 */
private async bool dpkg_requires_configure () {
    SourceFunc callback = dpkg_requires_configure.callback;
    bool result = false;

    new Thread<bool> ("dpkg_requires_configure", () => {
        try {
            var child = new Subprocess.newv ({"dpkg", "-l"}, GLib.Subprocess.STDOUT_PIPE);
            var stdout = child.get_stdout_pipe ();
            var buffer = new uint8[8192];
            ssize_t read = 1;
            uint8 state = 0;
            while (read != 0) {
                read = stdout.read (buffer, null);
                foreach (uint8 x in buffer[0:read]) {
                    if (0 == state && '\n' == x) {
                        state = 1;
                    } else if (1 == state) {
                        state = 'i' == x ? 2 : 0;
                    } else if (2 == state) {
                        state = 0;
                        if ('F' == x) {
                            result = true;
                            break;
                        }
                    }
                }
            }

            child.wait ();
        } catch (Error e) {
            stderr.printf ("dpkg -l errored: %s\n", e.message);
        }

        Idle.add ((owned)callback);
        return true;
    });

    yield;
    return result;
}

/*
 * If `dpkg_requires_configure` return `true`, this should be called to fix it.
 */
private async int dpkg_configure () {
    SourceFunc callback = dpkg_configure.callback;
    int status = 0;

    new Thread<bool> ("dpkg_configure", () => {
        try {
            string[] args = {"pkexec", "dpkg", "--configure", "-a"};
            var child = new Subprocess.newv (args, GLib.Subprocess.NONE);
            child.wait ();
            status = child.get_status ();
        } catch (GLib.Error e) {
            stderr.printf ("`dpkg --configure -a` errored: %s\n", e.message);
        }

        Idle.add ((owned)callback);
        return true;
    });

    yield;
    return status;
}
