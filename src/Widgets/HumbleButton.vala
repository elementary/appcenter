/*
* Copyright 2016–2022 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.HumbleButton : Gtk.Button {
    public signal void download_requested ();

    public AppCenterCore.Package package { get; set; }

    private int _amount = 1;
    public int amount {
        get {
            return _amount;
        }
        set {
            _amount = value;

            if (value != 0) {
                label = get_amount_formatted (value, true);
            } else {
                label = free_string;
            }
        }
    }

    public string free_string;

    public bool _allow_free = true;
    public bool allow_free {
        get {
            return _allow_free;
        }
        set {
            if (value != _allow_free) {
                _allow_free = value;
            }
        }
    }

    public bool can_purchase {
        set {
            if (!value) {
                amount = 0;
            }
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

    construct {
        hexpand = true;

#if PAYMENTS
        free_string = _("Free");
#else
        free_string = _("Install");
#endif

        clicked.connect (() => {
            if (amount != 0) {
                show_stripe_dialog ();
            } else {
                download_requested ();
            }
        });
    }

    private void show_stripe_dialog () {
        var stripe_dialog = new Widgets.StripeDialog (
            amount,
            package.get_name (),
            package.normalized_component_id,
            package.get_payments_key ()
        ) {
            transient_for = ((Gtk.Application) Application.get_default ()).active_window
        };

        stripe_dialog.download_requested.connect (() => {
            download_requested ();

            if (stripe_dialog.amount != 0) {
                App.add_paid_app (package.component.get_id ());
            }
        });

        stripe_dialog.show ();
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
