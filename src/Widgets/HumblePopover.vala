/*
* Copyright (c) 2018 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class AppCenter.Widgets.HumblePopover : Gtk.Popover {
    public signal void download_requested ();
    public signal void payment_requested (int amount);
    public signal void amount_changed (int new_amount);

    public Gtk.SpinButton custom_amount;
    private Gtk.Grid selection_list;

    public bool _allow_free = true;
    public bool allow_free {
        get {
            return _allow_free;
        }
        set {
            if (value != _allow_free) {
                _allow_free = value;
                custom_amount.set_range (_allow_free ? 0 : 1, 100);
            }
        }
    }

    public HumblePopover (Gtk.Widget relative_to, bool allow_free = true) {
        Object (allow_free: allow_free);

        this.relative_to = relative_to;
    }

    construct {
        var one_dollar = get_amount_button (1);
        var five_dollar = get_amount_button (5);
        var ten_dollar = get_amount_button (10);

        var custom_label = new Gtk.Label ("$");
        custom_label.margin_start = 12;

        custom_amount = new Gtk.SpinButton.with_range (allow_free ? 0 : 1, 100, 1);

        selection_list = new Gtk.Grid ();
        selection_list.column_spacing = 6;
        selection_list.margin = 12;
        selection_list.add (one_dollar);
        selection_list.add (five_dollar);
        selection_list.add (ten_dollar);
        selection_list.add (custom_label);
        selection_list.add (custom_amount);

        custom_amount.value_changed.connect (() => {
            amount_changed ((int)custom_amount.value);
        });

        custom_amount.activate.connect (() => {
            hide ();

            var amount = (int)custom_amount.value;
            if (amount != 0) {
                payment_requested (amount);
            } else {
                download_requested ();
            }
        });

        selection_list.show_all ();
        add (selection_list);
    }

    private Gtk.Button get_amount_button (int amount) {
        var button = new Gtk.Button.with_label (HumbleButton.get_amount_formatted (amount, false));

        button.clicked.connect (() => {
            amount_changed (amount);
            hide ();

            payment_requested (amount);
        });

        return button;
    }
}
