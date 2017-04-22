/*
* Copyright (c) 2016-2017 elementary LLC (https://elementary.io)
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
    public signal void link_requested ();
    public signal void payment_requested (int amount);

    private Gtk.Popover selection;
    private Gtk.Button amount_button;
    private Gtk.SpinButton custom_amount;

    private Gtk.Grid selection_list;
    private Gtk.Separator separator;
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

    public bool can_purchase {
        set {
            if (!value) {
                amount = 0;
            }

            selection_list.visible = value;
            selection_list.no_show_all = !value;

            separator.visible = value;
            separator.no_show_all = !value;
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
        amount_button = new Gtk.Button.with_label (_("Free"));
        amount_button.hexpand = true;

        var one_dollar = get_amount_button (1);
        var five_dollar = get_amount_button (5);
        var ten_dollar = get_amount_button (10);

        var custom_label = new Gtk.Label ("$");
        custom_label.margin_start = 12;

        custom_amount = new Gtk.SpinButton.with_range (0, 100, 1);

        selection_list = new Gtk.Grid ();
        selection_list.column_spacing = 6;
        selection_list.margin = 12;
        selection_list.margin_top = 9;
        selection_list.add (one_dollar);
        selection_list.add (five_dollar);
        selection_list.add (ten_dollar);
        selection_list.add (custom_label);
        selection_list.add (custom_amount);

        separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        var copy_link_label = new Gtk.Label (_("Copy Link"));
        copy_link_label.margin_start = 3;
        copy_link_label.xalign = 0;

        var copy_link_button = new Gtk.Button ();
        copy_link_button.hexpand = true;
        copy_link_button.add (copy_link_label);

        var style_context = copy_link_button.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_MENUITEM);
        style_context.remove_class (Gtk.STYLE_CLASS_BUTTON);

        var selection_grid = new Gtk.Grid ();
        selection_grid.margin_bottom = 3;
        selection_grid.margin_top = 3;
        selection_grid.row_spacing = 3;
        selection_grid.orientation = Gtk.Orientation.VERTICAL;
        selection_grid.add (selection_list);
        selection_grid.add (separator);
        selection_grid.add (copy_link_button);

        arrow_button = new Gtk.ToggleButton ();
        arrow_button.image = new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.MENU);

        selection = new Gtk.Popover (arrow_button);
        selection.width_request = 160;
        selection.position = Gtk.PositionType.BOTTOM;
        selection.add (selection_grid);

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

        copy_link_button.clicked.connect (() => {
            link_requested ();
            selection.hide ();
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

