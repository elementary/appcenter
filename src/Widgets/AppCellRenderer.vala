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
    public Pk.Package package { get; set; }
    private Gdk.Pixbuf icon;

    private const int MARGIN = 6;
    private const int ICON_SIZE = 48;
    private Gtk.Label title_label;
    private Gtk.Label description_label;

    public AppCellRenderer () {
        title_label = new Gtk.Label (null);
        title_label.get_style_context ().add_class ("h3");
        description_label = new Gtk.Label (null);
        icon = Gtk.IconTheme.get_default ().load_icon ("application-default-icon", ICON_SIZE, Gtk.IconLookupFlags.GENERIC_FALLBACK);
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
        var description = package.get_summary ();

        double x = background_area.x;
        double y = background_area.y + MARGIN;
        var style_context = widget.get_style_context ();
        if (style_context.direction == Gtk.TextDirection.RTL) {
            x += background_area.width - MARGIN - ICON_SIZE;
        } else {
            x += MARGIN;
        }

        style_context.render_icon (cr, icon, x, y);
        cr.fill ();

        cr.save ();
        var title_layout = title_label.create_pango_layout (title);
        int title_width;
        int title_height;
        title_layout.get_pixel_size (out title_width, out title_height);
        if (style_context.direction == Gtk.TextDirection.RTL) {
            x -= MARGIN + title_width;
        } else {
            x += ICON_SIZE + MARGIN;
        }

        var title_style_context = title_label.get_style_context ();
        title_style_context.parent = style_context.parent;
        title_style_context.set_state (style_context.get_state ());
        title_style_context.render_layout (cr, x, y, title_layout);
        cr.restore ();

        y += title_height + MARGIN;
        cr.save ();
        var description_layout = description_label.create_pango_layout (description);
        int description_width;
        int description_height;
        description_layout.get_pixel_size (out description_width, out description_height);
        if (style_context.direction == Gtk.TextDirection.RTL) {
            x += title_width - description_width;
        }

        var description_style_context = description_label.get_style_context ();
        description_style_context.parent = style_context.parent;
        description_style_context.set_state (style_context.get_state ());
        description_style_context.render_layout (cr, x, y, description_layout);
        cr.restore ();
    }
}
