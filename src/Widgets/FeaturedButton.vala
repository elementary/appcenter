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
        border: 1px solid alpha (#000, 0.15);
        border-radius: 3px;

        box-shadow: inset 0 0 0 1px alpha (#fff, 0.05),
                    inset 0 1px 0 0 alpha (#fff, 0.45),
                    inset 0 -1px 0 0 alpha (#fff, 0.15),
                    0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
        text-shadow: 0 1px 3px alpha (#000, 0.12),
                    0 1px 2px alpha (#000, 0.24);
    }
    .featured:dir(rtl) {
        background: linear-gradient(to right,rgba(255, 255, 255, 0.3), rgba(255, 255, 255, 0));
    }
    """;

const string COLORED_STYLE_CSS = """
    .colored {
        color: %s;
    }
    """;

public class AppCenter.Widgets.FeaturedButton : Gtk.Grid {
    public signal void clicked ();
    Gdk.RGBA background_color;

    Gtk.Label title_label;
    Gtk.Label summary_label;
    Gtk.Image icon_image;
    const int MARGIN = 6;

    public FeaturedButton (Gdk.RGBA background_color, Gdk.RGBA text_color, string title, string summary, GLib.Icon icon) {
        this.background_color = background_color;
        title_label.label = title;
        summary_label.label = summary;
        icon_image.gicon = icon;

        var provider = new Gtk.CssProvider ();
        try {
            var colored_css = COLORED_STYLE_CSS.printf (text_color.to_string ());
            provider.load_from_data (colored_css, colored_css.length);
            var context = title_label.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");
            context = summary_label.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }

    construct {
        add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
        valign = Gtk.Align.CENTER;
        vexpand = false;
        column_spacing = 12;

        icon_image = new Gtk.Image ();
        icon_image.pixel_size = 64;
        icon_image.vexpand = true;
        icon_image.margin_start = 6;

        title_label = new Gtk.Label (null);
        title_label.get_style_context ().add_class ("h2");
        title_label.margin_end = 6;
        title_label.valign = Gtk.Align.END;
        ((Gtk.Misc) title_label).xalign = 0;

        summary_label = new Gtk.Label (null);
        summary_label.get_style_context ().add_class ("h3");
        summary_label.margin_end = 6;
        summary_label.set_ellipsize (Pango.EllipsizeMode.END);
        summary_label.hexpand = true;
        summary_label.valign = Gtk.Align.START;
        ((Gtk.Misc) summary_label).xalign = 0;

        attach (icon_image, 0, 0, 1, 2);
        attach (title_label, 1, 0, 1, 1);
        attach (summary_label, 1, 1, 1, 1);

        var context = get_style_context ();
        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (FEATURED_STYLE_CSS, FEATURED_STYLE_CSS.length);
            context.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);
            context.add_class ("featured");
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        base.get_preferred_height (out minimum_height, out natural_height);
        minimum_height += 2*MARGIN;
        natural_height += 2*MARGIN;
        if (natural_height < 100) {
            natural_height = 100;
        }
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);
        minimum_width += 2*MARGIN;
        natural_width += 2*MARGIN;
        if (natural_width < 350) {
            natural_width = 350;
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

        return base.draw (cr);
    }
}
