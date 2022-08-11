/*-
 * Copyright 2022 elementary, Inc. (https://elementary.io)
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
 * Authored by: Ian Santopietro <ian@system76.com>
 */
 public class AppCenter.Screenshot : Gtk.DrawingArea {
    public string file_path { get; construct; }

    private Gdk.Pixbuf? pixbuf;
    private int pixbuf_width {
        get {
            return pixbuf != null ? pixbuf.width : 1;
        }
    }

    private int pixbuf_height {
        get {
            return pixbuf != null ? pixbuf.height : 1;
        }
    }

    public Screenshot (string path) {
        Object (file_path: path);
    }

    construct {
        try {
            pixbuf = new Gdk.Pixbuf.from_file (file_path);
        } catch (Error e) {
            critical ("Couldn't load pixbuf: %s", e.message);
            pixbuf = null;
        }
    }

    protected override bool draw (Cairo.Context cr) {
        if (pixbuf == null) {
            return Gdk.EVENT_PROPAGATE;
        }

        int height = get_allocated_height ();
        int width = get_allocated_width ();

        double scale = double.min ((double) height / pixbuf_height, (double) width / pixbuf_width);
        cr.scale (scale, scale);
        Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
        cr.paint ();
        return Gdk.EVENT_PROPAGATE;
    }

    protected override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    protected override void get_preferred_width (out int min, out int nat) {
        min = 0;
        nat = pixbuf_width;
    }

    protected override void get_preferred_height (out int min, out int nat) {
        min = 0;
        nat = pixbuf_height;
    }

    protected override void get_preferred_height_for_width (int width, out int min, out int nat) {
        min = width * pixbuf_height / pixbuf_width;
        nat = min;
    }

    protected override void get_preferred_width_for_height (int height, out int min, out int nat) {
        min = height * pixbuf_width / pixbuf_height;
        nat = min;
    }
}
