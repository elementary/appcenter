/*-
 * Copyright 2016-2022 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.UpdateHeaderRow : Gtk.Box {
    public string label_text { get; construct; }

    private Gtk.Label label;

    construct {
        margin_top = 12;
        margin_end = 12;
        margin_bottom = 12;
        margin_start = 12;
        spacing = 12;

        label = new Gtk.Label (label_text) {
            halign = Gtk.Align.START,
            hexpand = true
        };
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        add (label);
    }

    public UpdateHeaderRow.updatable (uint num_updates, uint64 update_size, bool using_flatpak) {
        Object (
            label_text: ngettext ("%u Update Available", "%u Updates Available", num_updates).printf (num_updates)
        );

        var size_label = new SizeLabel () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER
        };
        size_label.update (update_size, using_flatpak);

        add (size_label);
    }

    public UpdateHeaderRow.drivers () {
        Object (label_text: _("Drivers"));
    }

    public UpdateHeaderRow.up_to_date () {
        Object (label_text: _("Up to Date"));
    }
}
