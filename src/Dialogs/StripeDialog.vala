/*
* Copyright 2016-2022 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.StripeDialog : Granite.Dialog {
    public signal void download_requested ();

    private const string HOUSTON_URI = "https://developer.elementary.io/api/payment/%s";
    private const string HOUSTON_PAYLOAD = "{ "
                                + "\"data\": {"
                                    + "\"key\": \"%s\","
                                    + "\"token\": \"%s\","
                                    + "\"email\": \"%s\","
                                    + "\"amount\": %s,"
                                    + "\"currency\": \"USD\""
                                + "}}";
    private const string USER_AGENT = "elementary AppCenter";
    private const string STRIPE_URI = "https://api.stripe.com/v1/tokens";
    private const string STRIPE_AUTH = "Bearer %s";
    private const string STRIPE_REQUEST = "email=%s"
                            + "&payment_user_agent=%s&amount=%s&card[number]=%s"
                            + "&card[cvc]=%s&card[exp_month]=%s&card[exp_year]=%s"
                            + "&key=%s"
                            + "&currency=USD";

    private const string INTERNAL_ERROR_MESSAGE = N_("An error occurred while processing the card. Please try again later. We apologize for any inconvenience caused.");
    private const string DEFAULT_ERROR_MESSAGE = N_("Please review your payment info and try again.");

    private Gtk.Grid card_layout;
    private Gtk.Box? processing_layout = null;
    private Gtk.Box? error_layout = null;
    private Gtk.Stack layouts;

    private AppCenter.Widgets.CardNumberEntry card_number_entry;
    private Granite.ValidatedEntry card_cvc_entry;
    private Granite.ValidatedEntry card_expiration_entry;
    private Granite.ValidatedEntry email_entry;
    private Gtk.Button pay_button;
    private Gtk.Button cancel_button;

    private Gtk.Label secondary_error_label;

    public int amount { get; construct set; }
    public string app_name { get; construct set; }
    public string app_id { get; construct set; }
    public string stripe_key { get; construct set; }

    private bool card_valid = false;

    public StripeDialog (int _amount, string _app_name, string _app_id, string _stripe_key) {
        Object (
            amount: _amount,
            app_name: _app_name,
            app_id: _app_id,
            resizable: false,
            stripe_key: _stripe_key,
            title: _("Payment")
        );
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("payment-card", Gtk.IconSize.DIALOG) {
            pixel_size = 48,
            valign = Gtk.Align.START
        };

        var overlay_image = new Gtk.Image.from_icon_name (Build.PROJECT_NAME, Gtk.IconSize.LARGE_TOOLBAR) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END,
            pixel_size = 24
        };

        var overlay = new Gtk.Overlay () {
            child = image,
            valign = Gtk.Align.START
        };
        overlay.add_overlay (overlay_image);

        /* TRANSLATORS: The %d is an integer amount of dollars and the %s is the name of the app
           being purchased. The order can be changed with "%2$s %1$d". For example:
           "Buy %2$s for $%1$d", this would result in a string like "Buy GreatApp for $3" */
        var primary_label = new Gtk.Label (_("Pay $%d for %s").printf (amount, app_name)) {
            xalign = 0
        };
        primary_label.get_style_context ().add_class ("primary");

        var secondary_label = new Gtk.Label (
            _("This is a one time payment suggested by the developer. You can also choose your own price.")
        ) {
            margin_bottom = 12,
            margin_top = 6,
            max_width_chars = 50,
            use_markup = true,
            wrap = true,
            xalign = 0
        };

        var one_dollar = new Gtk.Button.with_label (HumbleButton.get_amount_formatted (1, false));

        var five_dollar = new Gtk.Button.with_label (HumbleButton.get_amount_formatted (5, false));

        var ten_dollar = new Gtk.Button.with_label (HumbleButton.get_amount_formatted (10, false));

        var dollar_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        dollar_button_group.add_widget (one_dollar);
        dollar_button_group.add_widget (five_dollar);
        dollar_button_group.add_widget (ten_dollar);

        var or_label = new Gtk.Label (_("or")) {
            margin_start = 3,
            margin_end = 3
        };

        var custom_amount = new Gtk.SpinButton.with_range (0, 100, 1) {
            activates_default = true,
            hexpand = true,
            primary_icon_name = "currency-dollar-symbolic",
            value = amount
        };

        var selection_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        selection_box.add (custom_amount);
        selection_box.add (or_label);
        selection_box.add (one_dollar);
        selection_box.add (five_dollar);
        selection_box.add (ten_dollar);

        Regex? email_regex = null;
        Regex? expiration_regex = null;
        Regex? cvc_regex = null;
        try {
            email_regex = new Regex ("""^[^\s]+@[^\s]+\.[^\s]+$""");
            expiration_regex = new Regex ("""^[0-9]{2}\/?[0-9]{2}$""");
            cvc_regex = new Regex ("""[0-9]{3,4}""");
        } catch (Error e) {
            critical (e.message);
        }

        email_entry = new Granite.ValidatedEntry.from_regex (email_regex) {
            activates_default = true,
            hexpand = true,
            input_purpose = Gtk.InputPurpose.EMAIL,
            input_hints = LOWERCASE,
            margin_bottom = 6,
            placeholder_text = _("Email"),
            primary_icon_name = "internet-mail-symbolic"
        };

        var email_label = new Gtk.Label (
            _("Only used to send you a receipt. You will not be subscribed to any mailing list.") +
            " <a href=\"https://stripe.com/privacy\">%s</a>".printf (_("Privacy Policy"))
        ) {
            hexpand = true,
            margin_bottom = 12,
            max_width_chars = 1,
            use_markup = true,
            wrap = true,
            xalign = 0
        };
        email_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        card_number_entry = new AppCenter.Widgets.CardNumberEntry () {
            activates_default = true,
            hexpand = true,
            margin_bottom = 6
        };

        card_expiration_entry = new Granite.ValidatedEntry.from_regex (expiration_regex) {
            activates_default = true,
            hexpand = true,
            max_length = 5,
            primary_icon_name = "office-calendar-symbolic",
            /// TRANSLATORS: Don't change the order, only transliterate
            placeholder_text = _("MM / YY")
        };

        card_cvc_entry = new Granite.ValidatedEntry.from_regex (cvc_regex) {
            activates_default = true,
            hexpand = true,
            input_purpose = Gtk.InputPurpose.DIGITS,
            max_length = 4,
            placeholder_text = _("CVC"),
            primary_icon_name = "channel-secure-symbolic"
        };
        card_cvc_entry.bind_property ("has-focus", card_cvc_entry, "visibility");

        var card_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            column_spacing = 6,
            margin_top = 24
        };
        card_grid.attach (email_entry, 0, 0, 2);
        card_grid.attach (email_label, 0, 1, 2);
        card_grid.attach (card_number_entry, 0, 2, 2);
        card_grid.attach (card_expiration_entry, 0, 3);
        card_grid.attach (card_cvc_entry, 1, 3);

        var card_grid_revealer = new Gtk.Revealer () {
            child = card_grid
        };

        card_layout = new Gtk.Grid () {
            column_spacing = 12
        };
        card_layout.get_style_context ().add_class ("login");
        card_layout.attach (overlay, 0, 0, 1, 2);
        card_layout.attach (primary_label, 1, 0);
        card_layout.attach (secondary_label, 1, 1);
        card_layout.attach (selection_box, 1, 2);
        card_layout.attach (card_grid_revealer, 1, 3);

        layouts = new Gtk.Stack () {
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12,
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
            vhomogeneous = false
        };
        layouts.add_named (card_layout, "card");
        layouts.set_visible_child_name ("card");

        var content_area = get_content_area ();
        content_area.add (layouts);
        content_area.show_all ();

        custom_amount.grab_focus ();

        cancel_button = (Gtk.Button) add_button (_("Cancel"), Gtk.ResponseType.CLOSE);

        pay_button = (Gtk.Button) add_button (_("Pay $%d.00").printf (amount), Gtk.ResponseType.APPLY);
        pay_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        pay_button.sensitive = false;

        set_default (pay_button);

        response.connect (on_response);

        bind_property ("amount", custom_amount, "value", BindingFlags.BIDIRECTIONAL);

        notify["amount"].connect (() => {
            if (amount == 0) {
                pay_button.label = _("Try for Free");
            } else {
                pay_button.label = _("Pay $%d.00").printf (amount);
            }
            primary_label.label = _("Pay $%d for %s").printf (amount, app_name);
            is_payment_sensitive ();

            card_grid_revealer.reveal_child = amount != 0;
        });

        one_dollar.clicked.connect (() => {
            amount = 1;
        });

        five_dollar.clicked.connect (() => {
            amount = 5;
        });

        ten_dollar.clicked.connect (() => {
            amount = 10;
        });

        email_entry.changed.connect (() => {
            if (" " in email_entry.text) {
                email_entry.text = email_entry.text.replace (" ", "");
            }

            is_payment_sensitive ();
        });

        card_number_entry.changed.connect (() => {
            card_valid = AppCenterCore.CardUtils.is_card_valid (card_number_entry.card_number);
            is_payment_sensitive ();
        });

        card_number_entry.bind_property ("has-focus", card_number_entry, "visibility");

        card_expiration_entry.changed.connect (() => {
            if (" " in card_expiration_entry.text) {
                card_expiration_entry.text = card_expiration_entry.text.replace (" ", "");
            }

            if (card_expiration_entry.text.length < 4) {
                card_expiration_entry.is_valid = false;
            }

            is_payment_sensitive ();
        });

        card_expiration_entry.focus_out_event.connect (() => {
            var expiration_text = card_expiration_entry.text;
            if (!("/" in expiration_text) && expiration_text.char_count () > 2) {
                int position = 2;
                card_expiration_entry.insert_text ("/", 1, ref position);
            }
        });

        card_cvc_entry.changed.connect (() => {
            if (" " in card_cvc_entry.text) {
                card_cvc_entry.text = card_cvc_entry.text.replace (" ", "");
            }

            is_payment_sensitive ();
        });
    }

    private void show_spinner_view () {
        if (processing_layout == null) {
            var spinner = new Gtk.Spinner () {
                height_request = 48,
                width_request = 48
            };
            spinner.start ();

            var label = new Gtk.Label (_("Processing")) {
                hexpand = true
            };
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                valign = Gtk.Align.CENTER,
                vexpand = true
            };

            box.add (spinner);
            box.add (label);

            processing_layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            processing_layout.add (box);

            layouts.add_named (processing_layout, "processing");
            layouts.show_all ();
        }

        layouts.set_visible_child_name ("processing");
        cancel_button.sensitive = false;
        pay_button.sensitive = false;
    }

    private void show_error_view (string error_reason) {
        if (error_layout == null) {
            var primary_label = new Gtk.Label (_("There Was a Problem Processing Your Payment")) {
                max_width_chars = 35,
                wrap = true,
                xalign = 0
            };
            primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

            secondary_error_label = new Gtk.Label (error_reason) {
                max_width_chars = 35,
                wrap = true,
                xalign = 0
            };

            var icon = new Gtk.Image.from_icon_name (Build.PROJECT_NAME, Gtk.IconSize.DIALOG) {
                pixel_size = 48
            };

            var overlay_icon = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.LARGE_TOOLBAR) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END,
                pixel_size = 24
            };

            var overlay = new Gtk.Overlay () {
                child = icon,
                valign = Gtk.Align.START
            };
            overlay.add_overlay (overlay_icon);

            var grid = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 6
            };
            grid.attach (overlay, 0, 0, 1, 2);
            grid.attach (primary_label, 1, 0);
            grid.attach (secondary_error_label, 1, 1);

            error_layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            error_layout.add (grid);

            layouts.add_named (error_layout, "error");
            layouts.show_all ();
        } else {
            secondary_error_label.label = error_reason;
        }

        layouts.set_visible_child_name ("error");
        cancel_button.label = _("Pay Later");
        pay_button.label = _("Retry");

        cancel_button.sensitive = true;
        pay_button.sensitive = true;
    }

    private void show_card_view () {
        pay_button.label = _("Pay $%d.00").printf (amount);
        cancel_button.label = _("Cancel");

        layouts.set_visible_child_name ("card");
        is_payment_sensitive ();
    }

    private void is_payment_sensitive () {
        if (amount == 0 || (email_entry.is_valid && card_valid && card_expiration_entry.is_valid && card_cvc_entry.is_valid)) {
            pay_button.sensitive = true;
        } else {
            pay_button.sensitive = false;
        }
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                if (layouts.visible_child_name == "card") {
                    if (amount != 0) {
                        show_spinner_view ();
                        on_pay_clicked ();
                    } else {
                        download_requested ();
                        destroy ();
                    }
                } else {
                    show_card_view ();
                }
                break;
            case Gtk.ResponseType.CLOSE:
                if (layouts.visible_child_name == "error") {
                    download_requested ();
                }

                destroy ();
                break;
        }
    }

    private void on_pay_clicked () {
        new Thread<void*> (null, () => {
            string expiration_dateyear = card_expiration_entry.text.replace ("/", "");
            var year = (int.parse (expiration_dateyear[2:4]) + 2000).to_string ();

            email_entry.text = email_entry.text.down ();

            var data = get_stripe_data (stripe_key, email_entry.text, (amount * 100).to_string (), card_number_entry.text, expiration_dateyear[0:2], year, card_cvc_entry.text);
            debug ("Stripe data:%s", data);
            string? error = null;
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (data);
                var root_object = parser.get_root ().get_object ();
                if (root_object != null && root_object.has_member ("id")) {
                    var token_id = root_object.get_string_member ("id");
                    string? houston_data = post_to_houston (stripe_key, app_id, token_id, email_entry.text, (amount * 100).to_string ());
                    if (houston_data != null) {
                        debug ("Houston data:%s", houston_data);
                        parser.load_from_data (houston_data);
                        root_object = parser.get_root ().get_object ();
                        if (root_object.has_member ("errors")) {
                            error = _(DEFAULT_ERROR_MESSAGE);
                        }
                    } else {
                        error = _(DEFAULT_ERROR_MESSAGE);
                    }
                } else if (root_object != null && root_object.has_member ("error")) {
                    error = get_stripe_error (root_object.get_object_member ("error"));
                } else {
                    error = _(DEFAULT_ERROR_MESSAGE);
                }
            } catch (Error e) {
                error = _(DEFAULT_ERROR_MESSAGE);
                debug (e.message);
            }

            Idle.add (() => {
                if (error != null) {
                    show_error_view (error);
                } else {
                    download_requested ();
                    destroy ();
                }

                return GLib.Source.REMOVE;
            });

            return null;
        });
    }

    private string get_stripe_data (string _key, string _email, string _amount, string _cc_num, string _cc_exp_month, string _cc_exp_year, string _cc_cvc) {
        var session = new Soup.Session ();
        var message = new Soup.Message ("POST", STRIPE_URI);

        var request = STRIPE_REQUEST.printf (
            Soup.URI.encode (_email, null),
            Soup.URI.encode (USER_AGENT, null),
            Soup.URI.encode (_amount, null),
            Soup.URI.encode (_cc_num, null),
            Soup.URI.encode (_cc_cvc, null),
            Soup.URI.encode (_cc_exp_month, null),
            Soup.URI.encode (_cc_exp_year, null)
        );

        message.request_headers.append ("Authorization", STRIPE_AUTH.printf (_key));
        message.request_headers.append ("Content-Type", "application/x-www-form-urlencoded");
        message.request_body.append_take (request.data);

        session.send_message (message);

        var data = new StringBuilder ();
        foreach (var c in message.response_body.data) {
            data.append ("%c".printf (c));
        }

        return data.str;
    }

    private string post_to_houston (string _app_key, string _app_id, string _purchase_token, string _email, string _amount) {
        var session = new Soup.Session ();
        var message = new Soup.Message ("POST", HOUSTON_URI.printf (_app_id));

        message.request_headers.append ("Accepts", "application/vnd.api+json");
        message.request_headers.append ("Content-Type", "application/vnd.api+json");

        var payload = HOUSTON_PAYLOAD.printf (_app_key, _purchase_token, _email, _amount);
        message.request_body.append_take (payload.data);

        session.send_message (message);

        var data = new StringBuilder ();
        foreach (var c in message.response_body.data) {
            data.append ("%c".printf (c));
        }

        return data.str;
    }

    private static unowned string get_stripe_error (Json.Object error_object) {
        if (error_object.has_member ("type")) {
            unowned string error_type = error_object.get_string_member ("type");
            debug ("Stripe error type: %s", error_type);
            switch (error_type) {
                case "card_error":
                    if (error_object.has_member ("code")) {
                        unowned string error_code = error_object.get_string_member ("code");
                        debug ("Stripe error code: %s", error_code);
                        switch (error_code) {
                            case "incorrect_number":
                            case "invalid_number":
                                return _("The card number is incorrect. Please try again using the correct card number.");
                            case "invalid_expiry_month":
                                return _("The expiration month is invalid. Please try again using the correct expiration date.");
                            case "invalid_expiry_year":
                                return _("The expiration year is invalid. Please try again using the correct expiration date.");
                            case "incorrect_cvc":
                            case "invalid_cvc":
                                return _("The CVC number is incorrect. Please try again using the correct CVC.");
                            case "expired_card":
                                return _("The card has expired. Please try again with a different card.");
                            case "processing_error":
                                return _(INTERNAL_ERROR_MESSAGE);
                            case "card_declined":
                                if (error_object.has_member ("decline_code")) {
                                    unowned string decline_code = error_object.get_string_member ("decline_code");
                                    debug ("Stripe decline error code: %s", decline_code);
                                    return get_stripe_decline_reason (decline_code);
                                } else {
                                    return _(DEFAULT_ERROR_MESSAGE);
                                }
                            default:
                                return _(DEFAULT_ERROR_MESSAGE);
                        }
                    } else {
                        return _(DEFAULT_ERROR_MESSAGE);
                    }
                case "validation_error":
                    return _(DEFAULT_ERROR_MESSAGE);
                case "rate_limit_error":
                    return _("There are too many payment requests at the moment, please retry later.");
                case "api_connection_error":
                case "api_error":
                case "authentication_error":
                case "invalid_request_error":
                default:
                    return _(INTERNAL_ERROR_MESSAGE);
            }
        } else {
            return _(DEFAULT_ERROR_MESSAGE);
        }
    }

    private static unowned string get_stripe_decline_reason (string decline_code) {
        switch (decline_code) {
            case "card_not_supported":
                return _("This card does not support this kind of transaction. Please try again with a different card.");
            case "currency_not_supported":
                return _("The currency is not supported by this card. Please try again with a different card.");
            case "duplicate_transaction":
                return _("The transaction has already been processed.");
            case "expired_card":
                return _("The card has expired. Please try again with a different card.");
            case "incorrect_zip":
                return _("The ZIP/Postal code is incorrect. Please try again using the correct ZIP/postal code.");
            case "insufficient_funds":
                return _("You don't have enough funds. Please use an alternative payment method.");
            case "invalid_amount":
                return _("The amount is incorrect. Please try again using a valid amount.");
            case "incorrect_cvc":
            case "invalid_cvc":
                return _("The CVC number is incorrect. Please try again using the correct CVC.");
            case "invalid_expiry_year":
                return _("The expiration year is invalid. Please try again using the correct expiration date.");
            case "incorrect_number":
            case "invalid_number":
                return _("The card number is incorrect. Please try again using the correct card number.");
            case "incorrect_pin":
            case "invalid_pin":
                return _("The PIN number is incorrect. Please try again using the correct PIN.");
            case "pin_try_exceeded":
                return _("There has been too many PIN attempts. Please try again with a different card.");
            case "call_issuer":
            case "do_not_honor":
            case "do_not_try_again":
            case "fraudulent":
            case "generic_decline":
            case "invalid_account":
            case "lost_card":
            case "new_account_information_available":
            case "no_action_taken":
            case "not_permitted":
            case "pickup_card":
            case "restricted_card":
            case "revocation_of_all_authorizations":
            case "revocation_of_authorization":
            case "security_violation":
            case "service_not_allowed":
            case "stolen_card":
            case "stop_payment_order":
            case "transaction_not_allowed":
                return _("Unable to complete the transaction. Please contact your bank for further information.");
            case "card_velocity_exceeded":
            case "withdrawal_count_limit_exceeded":
                return _("The balance or credit limit on the card has been reached.");
            case "live_mode_test_card":
            case "testmode_decline":
                return _("The given card is a test card. Please use a real card to proceed.");
            case "approve_with_id":
            case "issuer_not_available":
            case "processing_error":
            case "reenter_transaction":
            case "try_again_later":
                return _(INTERNAL_ERROR_MESSAGE);
            default:
                return _(DEFAULT_ERROR_MESSAGE);
        }
    }
}
