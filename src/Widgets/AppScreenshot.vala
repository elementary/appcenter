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
 * Authored by: Ian Santopietro <ian@system76.com>
 */
public class AppCenter.Widgets.AppScreenshot : Gtk.DrawingArea {
    private string file_path;
    private double aspect_ratio;
    private Gdk.Pixbuf? pixbuf;
    private int pixbuf_height;
    
    construct {
        hexpand = true;
        halign = Gtk.Align.FILL;
    }
    
    public void set_path (string path_text) {
        int width, height;
        file_path = path_text;
        Gdk.Pixbuf.get_file_info (file_path, out width, out height);
        aspect_ratio = (double) width / height;
        try {
            pixbuf = new Gdk.Pixbuf.from_file (file_path);
            pixbuf_height = height;
        }
        catch (Error e) {
            critical ("Couldn't load pixbuf: %s", e.message);
            pixbuf = null;
        }
    }
    
    protected override bool draw (Cairo.Context cr) {
        if (pixbuf == null)
            return Gdk.EVENT_PROPAGATE;
        int height = get_allocated_height ();
        double scale = (double) height / pixbuf_height;
        cr.scale (scale, scale);
        Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
        cr.paint ();
        return Gdk.EVENT_PROPAGATE;
    }
    
    protected override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }
    
    protected override void get_preferred_height (out int min, out int nat) {
        get_preferred_height_for_width (
            get_allocated_width (),
            out min,
            out nat
        );
    }
    
    protected override void get_preferred_height_for_width (int width, out int min, out int nat) {
        double val = width / aspect_ratio;
        min = nat = (int) val;
    }
}