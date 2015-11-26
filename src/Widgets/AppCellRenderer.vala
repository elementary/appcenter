// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

using AppCenterCore;

public class AppCenter.Widgets.AppCellRenderer : Gtk.CellRenderer {

    /* icon property set by the tree column */
    public AppCenterCore.Package package { get; set; }
    public Gdk.Pixbuf icon { get; set; }

    private Gdk.Pixbuf update_icon;
    private const int MARGIN = 6;
    private const int ICON_SIZE = 48;
    private const int ACTION_ICON_SIZE = 24;
    private Gtk.Label title_label;
    private Gtk.Label summary_label;

    public AppCellRenderer () {
        
    }

    construct {
        title_label = new Gtk.Label (null);
        title_label.get_style_context ().add_class ("h3");
        summary_label = new Gtk.Label (null);
        try {
            update_icon = Gtk.IconTheme.get_default ().load_icon ("software-update-available-symbolic", ACTION_ICON_SIZE, Gtk.IconLookupFlags.GENERIC_FALLBACK);
        } catch (Error e) {
            critical (e.message);
        }
    }

    public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset, out int y_offset, out int width, out int height) {
        x_offset = 0;
        y_offset = 0;
        width = 50;
        height = ICON_SIZE + 2 * MARGIN;
    }

    /* render method */
    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
        var title = package.get_name ();
        var summary = package.get_summary ();

        int x = background_area.x;
        int y = background_area.y + MARGIN;
        var style_context = widget.get_style_context ();
        if (style_context.direction == Gtk.TextDirection.RTL) {
            x += background_area.width - MARGIN - ICON_SIZE;
        } else {
            x += MARGIN;
        }

        draw_icon (cr, widget, x, y, icon, ICON_SIZE);

        var label_width = background_area.width - 3 * MARGIN - ICON_SIZE;
        if (package.update_available) {
            label_width -= MARGIN + ACTION_ICON_SIZE;
        }

        if (style_context.direction == Gtk.TextDirection.RTL) {
            x -= MARGIN + label_width;
        } else {
            x += ICON_SIZE + MARGIN;
        }

        int title_height;
        draw_label (cr, widget, title_label, x, y, title, label_width, out title_height);

        y += title_height + MARGIN;

        int summary_height;
        draw_label (cr, widget, summary_label, x, y, summary, label_width, out summary_height);

        if (package.update_available) {
            y = background_area.y + (background_area.height - ACTION_ICON_SIZE)/2;
            if (style_context.direction == Gtk.TextDirection.RTL) {
                x = background_area.x + MARGIN;
            } else {
                x = background_area.x + background_area.width - ACTION_ICON_SIZE - MARGIN;
            }

            draw_icon (cr, widget, x, y, update_icon, ACTION_ICON_SIZE);
        }
    }

    private void draw_label (Cairo.Context cr, Gtk.Widget widget, Gtk.Label label, int x, int y, string title, int width, out int height) {
        cr.save ();
        var style_context = widget.get_style_context ();
        var label_style_context = label.get_style_context ();
        label_style_context.parent = style_context.parent;
        label_style_context.set_state (style_context.get_state ());

        var label_layout = label.create_pango_layout (title);
        label_layout.set_width (width * Pango.SCALE);
        if (style_context.direction == Gtk.TextDirection.RTL) {
            label_layout.set_ellipsize (Pango.EllipsizeMode.START);
            label_layout.set_alignment (Pango.Alignment.RIGHT);
        } else {
            label_layout.set_ellipsize (Pango.EllipsizeMode.END);
            label_layout.set_alignment (Pango.Alignment.LEFT);
        }

        int label_width;
        label_layout.get_pixel_size (out label_width, out height);
        label_style_context.render_layout (cr, x, y, label_layout);
        cr.restore ();
    }

    private void draw_icon (Cairo.Context cr, Gtk.Widget widget, int x, int y, Gdk.Pixbuf pixbuf, int size) {
        widget.get_style_context ().render_icon (cr, pixbuf, x, y);
        cr.fill ();
    }
}
