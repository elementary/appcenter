/*
 * Copyright (c) 2016 elementary LLC (https://launchpad.net/granite)
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
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

public class AppCenter.Widgets.HumbleButton : Gtk.Grid {
    public signal void download_requested ();
    public signal void payment_requested (int amount);

    private Gtk.Popover selection;
    private Gtk.Button amount_button;
    private Gtk.SpinButton custom_amount;

    private Gtk.ToggleButton arrow_button;

    private int _amount;
    public int amount {
        get {
            return _amount;
        }
        set {
            _amount = value;
            amount_button.label = get_amount_formatted (value, true);
            custom_amount.value = value;

            if (_amount != 0) {
                amount_button.label = get_amount_formatted (_amount, true);
            } else {
                amount_button.label = _("Free");
            }
        }
    }

    public string label {
        set {
            amount_button.label = value;
        }
    }

    public bool can_purchase {
        set {
            if (!value) {
                amount = 0;
            }

            arrow_button.visible = value;
            arrow_button.no_show_all = !value;
        }
    }

    public bool suggested_action {
        set {
            if (value) {
                amount_button.get_style_context ().add_class ("h3");
                amount_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                arrow_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            }
        }
    }

    public HumbleButton () {
        Object (amount: 1);
    }

    construct {
        amount_button = new Gtk.Button ();
        amount_button.hexpand = true;

        var one_dollar = get_amount_button (1);
        var five_dollar = get_amount_button (5);
        var ten_dollar = get_amount_button (10);

        var custom_label = new Gtk.Label ("$");
        custom_label.margin_start = 12;

        custom_amount = new Gtk.SpinButton.with_range (0, 100, 1);

        var selection_list = new Gtk.Grid ();
        selection_list.column_spacing = 6;
        selection_list.margin = 12;
        selection_list.add (one_dollar);
        selection_list.add (five_dollar);
        selection_list.add (ten_dollar);
        selection_list.add (custom_label);
        selection_list.add (custom_amount);

        arrow_button = new Gtk.ToggleButton ();
        arrow_button.image = new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.MENU);

        selection = new Gtk.Popover (arrow_button);
        selection.position = Gtk.PositionType.BOTTOM;
        selection.add (selection_list);

        amount_button.clicked.connect (() => {
            if (this.amount != 0) {
                payment_requested (this.amount);
            } else {
                download_requested ();
            }
        });

        arrow_button.toggled.connect (() => {
            selection.show_all ();
        });

        custom_amount.value_changed.connect (() => {
            amount = (int) custom_amount.value;
        });

        custom_amount.activate.connect (() => {
            selection.hide ();

            if (this.amount != 0) {
                payment_requested (this.amount);
            } else {
                download_requested ();
            }
        });

        selection.closed.connect (() => {
            arrow_button.active = false;
        });

        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        add (amount_button);
        add (arrow_button);
    }

    private string get_amount_formatted (int _amount, bool with_short_part = true) {
        if (with_short_part) {
            /// This amount will be US Dollars. Some languages might need a "$%dUSD"
            return _("$%d.00").printf (_amount);
        } else {
            /// This amount will be US Dollars. Some languages might need a "$%dUSD"
            return _("$%d").printf (_amount);
        }
    }

    private Gtk.Button get_amount_button (int amount) {
        var button = new Gtk.Button.with_label (get_amount_formatted (amount, false));

        button.clicked.connect (() => {
            this.amount = amount;
            selection.hide ();
            payment_requested (this.amount);
        });

        return button;
    }
}

