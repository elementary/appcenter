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
        public bool using_flatpak { get; protected set; default = false; }

        construct {
            margin = 12;
            column_spacing = 12;
        }

        protected void store_data (uint _update_numbers, uint64 _update_real_size, bool _is_updating, bool _using_flatpak) {
            update_numbers = _update_numbers;
            update_real_size = _update_real_size;
            is_updating = _is_updating;
            using_flatpak = _using_flatpak;
        }

        public abstract void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating, bool _using_flatpak);
    }

    /** Header to show at top of list if there are updates available **/
    public class UpdatesGrid : AbstractHeaderGrid {
        private SizeLabel size_label;
        private Gtk.Label updates_label;

        construct {
            margin_top = 18;

            updates_label = new Gtk.Label (null);
            ((Gtk.Misc) updates_label).xalign = 0;
            updates_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            updates_label.hexpand = true;

            size_label = new SizeLabel ();
            size_label.halign = Gtk.Align.END;
            size_label.valign = Gtk.Align.CENTER;

            add (updates_label);
            add (size_label);
        }

        public override void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating, bool _using_flatpak) {
            store_data (_update_numbers, _update_real_size, _is_updating, _using_flatpak);

            if (!is_updating) {
                updates_label.label = ngettext ("%u Update Available", "%u Updates Available", update_numbers).printf (update_numbers);
                size_label.update (update_real_size, using_flatpak);

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

        public override void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating, bool _using_flatpak) {
            store_data (_update_numbers, _update_real_size, _is_updating, _using_flatpak);

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

        public override void update (uint _update_numbers, uint64 _update_real_size, bool _is_updating, bool _using_flatpak) {

        }
    }
}
