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

const string FEATURED_STYLE_CSS = """
    .featured {
        background: linear-gradient(to right, rgba(255, 255, 255, 0), rgba(255, 255, 255, 0.3));
        border: 1px solid alpha (#000, 0.35);
        border-radius: 3px;

        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.45),
                    inset 0 -1px 0 0 alpha (#fff, 0.15),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
    }
    .featured:dir(rtl) {
        background: linear-gradient(to right,rgba(255, 255, 255, 0.3), rgba(255, 255, 255, 0));
    }
    """;

public class AppCenter.Widgets.FeaturedButton : Gtk.EventBox {
    public signal void clicked ();

    Gdk.RGBA background_color;
    Gdk.RGBA text_color;
    string title;
    string subtitle;
    Gdk.Pixbuf icon;

    Pango.Layout title_layout;
    Pango.Layout subtitle_layout;

    const int MARGIN = 6;

    public FeaturedButton (Gdk.RGBA background_color, Gdk.RGBA text_color, string title, string subtitle, Gdk.Pixbuf icon) {
        this.background_color = background_color;
        this.text_color = text_color;
        this.title = title;
        this.subtitle = subtitle;
        this.icon = icon;
    }

    construct {
        add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
        var provider = new Gtk.CssProvider();
        try {
            provider.load_from_data (FEATURED_STYLE_CSS, FEATURED_STYLE_CSS.length);
            var context = get_style_context ();
            context.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("featured");
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = 2*MARGIN + icon.width + 50;
        if (minimum_width > 350) {
            natural_width = minimum_width;
        } else {
            natural_width = 350;
        }
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        if (title_layout == null || subtitle_layout == null) {
            minimum_height = 100;
        } else {
            var icon_height = 2*MARGIN + icon.height;
            var text_height = 4*MARGIN + (title_layout.get_height () + subtitle_layout.get_height ())  * Pango.SCALE;
            minimum_height = int.max (icon_height, text_height);
        }

        if (minimum_height > 100) {
            natural_height = minimum_height;
        } else {
            natural_height = 100;
        }
    }

    public override bool button_release_event (Gdk.EventButton event) {
        clicked ();
        return false;
    }

    public override bool draw (Cairo.Context cr) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();

        cr.save ();
        cr.set_source_rgba (background_color.red, background_color.green, background_color.blue, background_color.alpha);
        int x = 0;
        int y = 0;
        double radius = 3;
        cr.move_to (x + radius, y);
        cr.arc (x + width - radius, y + radius, radius, Math.PI * 1.5, Math.PI * 2);
        cr.arc (x + width - radius, y + height - radius, radius, 0, Math.PI_2);
        cr.arc (x + radius, y + height - radius, radius, Math.PI_2, Math.PI);
        cr.arc (x + radius, y + radius, radius, Math.PI, Math.PI * 1.5);
        cr.close_path ();
        cr.fill_preserve ();
        cr.restore ();
        y += (height - icon.height) / 2;
        var style_context = get_style_context ();
        if (style_context.direction == Gtk.TextDirection.RTL) {
            x += width - MARGIN - icon.width;
        } else {
            x += MARGIN;
        }

        style_context.render_background (cr, 0, 0, width, height);
        style_context.render_frame (cr, 0, 0, width, height);
        style_context.render_icon (cr, icon, x, y);

        if (style_context.direction == Gtk.TextDirection.RTL) {
            x -= 2*MARGIN;
        } else {
            x+= icon.width + 2*MARGIN;
        }

        cr.save ();
        style_context.save ();
        style_context.add_class ("h2");
        title_layout = Pango.cairo_create_layout (cr);
        title_layout.set_text (title, title.length);
        title_layout.set_font_description (style_context.get_font (style_context.get_state ()));
        int title_width;
        int title_height;
        title_layout.get_pixel_size (out title_width, out title_height);
        if (style_context.direction == Gtk.TextDirection.RTL) {
            title_layout.set_alignment (Pango.Alignment.RIGHT);
            x -= title_width;
        }
        style_context.restore ();

        cr.set_source_rgba (text_color.red, text_color.green, text_color.blue, text_color.alpha);
        cr.move_to (x, y);
        Pango.cairo_update_layout (cr, title_layout);
        Pango.cairo_show_layout (cr, title_layout);
        y += title_height + MARGIN;

        style_context.save ();
        style_context.add_class ("h3");
        subtitle_layout = Pango.cairo_create_layout (cr);
        subtitle_layout.set_text (subtitle, subtitle.length);
        subtitle_layout.set_font_description (style_context.get_font (style_context.get_state ()));
        int subtitle_width;
        int subtitle_height;
        subtitle_layout.get_pixel_size (out subtitle_width, out subtitle_height);
        if (style_context.direction == Gtk.TextDirection.RTL) {
            x += title_width;
            subtitle_layout.set_width ((x - MARGIN) * Pango.SCALE);
            subtitle_layout.set_ellipsize (Pango.EllipsizeMode.START);
            subtitle_layout.set_alignment (Pango.Alignment.RIGHT);
            x = MARGIN;
        } else {
            subtitle_layout.set_width ((width - x - MARGIN) * Pango.SCALE);
        }
        subtitle_layout.set_ellipsize (Pango.EllipsizeMode.END);
        style_context.restore ();
        cr.move_to (x, y);
        Pango.cairo_update_layout (cr, subtitle_layout);
        Pango.cairo_show_layout (cr, subtitle_layout);
        cr.restore ();

        return false;
    }
}
