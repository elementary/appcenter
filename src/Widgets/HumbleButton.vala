/*
* Copyright (c) 2016–2018 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.HumbleButton : Gtk.Grid {
    public signal void download_requested ();
    public signal void payment_requested (int amount);

    private HumblePopover selection;
    private Gtk.Button amount_button;

    private Gtk.ToggleButton arrow_button;

    private int _amount = 1;
    public int amount {
        get {
            return _amount;
        }
        set {
            _amount = value;
            amount_button.label = get_amount_formatted (value, true);
            selection.custom_amount.value = value;

            if (_amount != 0) {
                amount_button.label = get_amount_formatted (_amount, true);
            } else {
                amount_button.label = free_string;
            }
        }
    }

    private string free_string;
    public string label {
        set {
            free_string = value;

            if (amount == 0) {
               amount_button.label = free_string;
            }
        }
    }

    public bool _allow_free = true;
    public bool allow_free {
        get {
            return _allow_free;
        }
        set {
            if (value != _allow_free) {
                _allow_free = value;
                selection.custom_amount.set_range (_allow_free ? 0 : 1, 100);
            }
        }
    }

    public bool can_purchase {
        set {
            if (!value) {
                amount = 0;
            }

            arrow_button.visible = value;
            arrow_button.no_show_all = !value;
#if PAYMENTS
            // Nothing special, show everything as normal
#else
            // If it's paid, disable it and add a tooltip explaining why
            if (value) {
                sensitive = false;
                tooltip_text = _("Requires payments, which are not enabled");
            }
#endif
        }
    }

    public bool suggested_action {
        set {
            if (value) {
                amount_button.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
                amount_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                arrow_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            }
        }
    }

    construct {
        amount_button = new Gtk.Button ();
        amount_button.hexpand = true;

#if PAYMENTS
        amount_button.label = _("Free");
#else
        amount_button.label = _("Install");
#endif

        arrow_button = new Gtk.ToggleButton ();
        arrow_button.image = new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.MENU);

        selection = new HumblePopover (arrow_button);
        selection.position = Gtk.PositionType.BOTTOM;
        selection.download_requested.connect (() => download_requested);
        selection.payment_requested.connect ((amount) => payment_requested (amount));
        selection.amount_changed.connect ((new_amount) => { amount = new_amount; });
        selection.closed.connect (() => {
            arrow_button.active = false;
        });

        amount_button.clicked.connect (() => {
            if (this.amount != 0) {
                payment_requested (this.amount);
            } else {
                download_requested ();
            }
        });

        arrow_button.toggled.connect (() => selection.show_all ());

        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        add (amount_button);
        add (arrow_button);
    }

    public static string get_amount_formatted (int _amount, bool with_short_part = true) {
        if (with_short_part) {
            /// This amount will be US Dollars. Some languages might need a "$%dUSD"
            return _("$%d.00").printf (_amount);
        } else {
            /// This amount will be US Dollars. Some languages might need a "$%dUSD"
            return _("$%d").printf (_amount);
        }
    }
}

