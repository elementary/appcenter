// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC. (https://elementary.io)
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
 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace AppCenter.Widgets {
    /** Base class for Grids in Header Rows **/
    public abstract class AbstractHeaderGrid : Gtk.Grid {
        public uint update_numbers { get; protected set; default = 0; }
        public uint64 update_real_size { get; protected set; default = 0; }
        public bool is_updating { get; protected set; default = false; }

        construct {
            margin = 12;
            column_spacing = 12;
        }

        protected void store_data (uint _update_numbers, uint64 _update_real_size, bool _is_updating) {
            update_numbers = _update_numbers;
            update_real_size = _update_real_size;
            is_updating = _is_updating;
        }

        public void add_widget (Gtk.Widget widget) {
            add (widget);
        }

        public abstract void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating);
    }

    /** Header to show at top of list if there are updates available **/
    public class UpdatesGrid : AbstractHeaderGrid {
        private Gtk.Label update_size_label;
        private Gtk.Label updates_label;

        construct {
            margin_top = 18;
            updates_label = new Gtk.Label (null);
            ((Gtk.Misc) updates_label).xalign = 0;
            updates_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            updates_label.hexpand = true;

            update_size_label = new Gtk.Label (null);

            add (updates_label);
            add (update_size_label);
        }

        public override void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating) {
            store_data (_update_numbers,  _update_real_size, _is_updating);

            if (!is_updating) {
                updates_label.label = ngettext ("%u Update Available", "%u Updates Available", update_numbers).printf (update_numbers);
                update_size_label.label = _("Size: %s").printf (GLib.format_size (update_real_size));
                if (update_numbers > 0) {
                    show_all ();
                } else {
                    hide ();
                }
            } else {
                hide (); /* Updated header shows updating spinner and message */
            }
        }
    }

    /** Header to show above first package that is up to date, or if the cache is updating **/
    public class UpdatedGrid : AbstractHeaderGrid {
        private Gtk.Label label;
        private Gtk.Spinner spinner;

        construct {
            label = new Gtk.Label (""); /* Should not be displayed before being updated */
            label.hexpand = true;
            ((Gtk.Misc)label).xalign = 0;

            spinner = new Gtk.Spinner ();

            add (label);
            add (spinner);
        }

        public override void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating) {
            store_data (_update_numbers,  _update_real_size, _is_updating);

            if (is_updating) {
                halign = Gtk.Align.CENTER;
                spinner.start ();
                spinner.no_show_all = false;
                spinner.show ();
                label.label = _("Searching for updates…");
                label.get_style_context ().remove_class (Granite.STYLE_CLASS_H4_LABEL);
            } else {
                halign = Gtk.Align.FILL;
                spinner.stop ();
                spinner.no_show_all = true;
                spinner.hide ();
                label.label = _("Up to Date");
                label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            }
        }
    }

    public class DriverGrid : AbstractHeaderGrid {
        construct {
            var label = new Gtk.Label (_("Drivers"));
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            label.hexpand = true;
            ((Gtk.Misc)label).xalign = 0;

            add (label);
        }

        public override void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating) {

        }
    }
}

