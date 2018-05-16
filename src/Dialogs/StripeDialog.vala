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

public class AppCenter.Widgets.StripeDialog : Gtk.Dialog {
    public signal void download_requested ();

    private const string HOUSTON_URI =  "https://developer.elementary.io/api/payment/%s";
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
    private Gtk.Grid? processing_layout = null;
    private Gtk.Grid? error_layout = null;
    private Gtk.Stack layouts;

    private Gtk.Entry email_entry;
    private AppCenter.Widgets.CardNumberEntry card_number_entry;
    private Gtk.Entry card_expiration_entry;
    private Gtk.Entry card_cvc_entry;
    private Gtk.Button pay_button;
    private Gtk.Button cancel_button;

    private Gtk.Label secondary_error_label;

    public int amount { get; construct set; }
    public string app_name { get; construct set; }
    public string app_id { get; construct set; }
    public string stripe_key { get; construct set; }

    private bool email_valid = false;
    private bool card_valid = false;
    private bool expiration_valid = false;
    private bool cvc_valid = false;

    public StripeDialog (int _amount, string _app_name, string _app_id, string _stripe_key) {
        Object (amount: _amount,
                app_name: _app_name,
                app_id: _app_id,
                deletable: false,
                resizable: false,
                stripe_key: _stripe_key);
    }

    construct {
        var primary_label = new Gtk.Label (_("Pay $%d for %s").printf (amount, app_name));
        primary_label.get_style_context ().add_class ("primary");
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("This is a one time payment. Your email address is only used to send you a receipt."));
        secondary_label.max_width_chars = 50;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;


        email_entry = new Gtk.Entry ();
        email_entry.hexpand = true;
        email_entry.input_purpose = Gtk.InputPurpose.EMAIL;
        email_entry.placeholder_text = _("Email");
        email_entry.primary_icon_name = "internet-mail-symbolic";
        email_entry.tooltip_text = _("Your email address is used to send a receipt. It is never stored and you will not be subscribed to a mailing list.");

        email_entry.changed.connect (() => {
           email_entry.text = email_entry.text.replace (" ", "").down ();
           validate (0, email_entry.text);
        });

        card_number_entry = new AppCenter.Widgets.CardNumberEntry ();
        card_number_entry.hexpand = true;
        card_number_entry.changed.connect (() => {
            validate (1, card_number_entry.card_number);
        });

        card_number_entry.bind_property ("has-focus", card_number_entry, "visibility");

        card_expiration_entry = new Gtk.Entry ();
        card_expiration_entry.hexpand = true;
        card_expiration_entry.max_length = 5;
        /// TRANSLATORS: Don't change the order, only transliterate
        card_expiration_entry.placeholder_text = _("MM / YY");
        card_expiration_entry.primary_icon_name = "office-calendar-symbolic";

        card_expiration_entry.changed.connect (() => {
            card_expiration_entry.text = card_expiration_entry.text.replace (" ", "");
            validate (2, card_expiration_entry.text);
        });

        card_expiration_entry.focus_out_event.connect (() => {
            var expiration_text = card_expiration_entry.text;
            if (!("/" in expiration_text) && expiration_text.char_count () > 2) {
                int position = 2;
                card_expiration_entry.insert_text ("/", 1, ref position);
            }
        });

        card_cvc_entry = new Gtk.Entry ();
        card_cvc_entry.hexpand = true;
        card_cvc_entry.input_purpose = Gtk.InputPurpose.DIGITS;
        card_cvc_entry.max_length = 4;
        card_cvc_entry.placeholder_text = _("CVC");
        card_cvc_entry.primary_icon_name = "channel-secure-symbolic";

        card_cvc_entry.changed.connect (() => {
            card_cvc_entry.text = card_cvc_entry.text.replace (" ", "");
            validate (3, card_cvc_entry.text);
        });

        card_cvc_entry.bind_property ("has-focus", card_cvc_entry, "visibility");

        var card_grid_bottom = new Gtk.Grid ();
        card_grid_bottom.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid_bottom.add (card_expiration_entry);
        card_grid_bottom.add (card_cvc_entry);

        var card_grid = new Gtk.Grid ();
        card_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid.orientation = Gtk.Orientation.VERTICAL;
        card_grid.add (card_number_entry);
        card_grid.add (card_grid_bottom);

        card_layout = new Gtk.Grid ();
        card_layout.get_style_context ().add_class ("login");
        card_layout.row_spacing = 12;
        card_layout.orientation = Gtk.Orientation.VERTICAL;
        card_layout.add (primary_label);
        card_layout.add (secondary_label);
        card_layout.add (email_entry);
        card_layout.add (card_grid);

        layouts = new Gtk.Stack ();
        layouts.vhomogeneous = false;
        layouts.margin_start = layouts.margin_end = 12;
        layouts.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        layouts.add_named (card_layout, "card");
        layouts.set_visible_child_name ("card");

        var content_area = get_content_area ();
        content_area.add (layouts);
        content_area.show_all ();

        var privacy_policy_link = new Gtk.LinkButton.with_label ("https://stripe.com/privacy", _("Privacy Policy"));
        privacy_policy_link.show ();

        var action_area = (Gtk.ButtonBox) get_action_area ();
        action_area.margin = 5;
        action_area.margin_top = 14;
        action_area.add (privacy_policy_link);
        action_area.set_child_secondary (privacy_policy_link, true);

        cancel_button = (Gtk.Button) add_button (_("Cancel"), Gtk.ResponseType.CLOSE);

        pay_button = (Gtk.Button) add_button (_("Pay $%d.00").printf (amount), Gtk.ResponseType.APPLY);
        pay_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        pay_button.has_default = true;
        pay_button.sensitive = false;

        response.connect (on_response);

        email_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        card_number_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        card_expiration_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        card_cvc_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });
    }

    private void show_spinner_view () {
        if (processing_layout == null) {
            processing_layout = new Gtk.Grid ();
            processing_layout.orientation = Gtk.Orientation.VERTICAL;
            processing_layout.column_spacing = 12;

            var spinner = new Gtk.Spinner ();
            spinner.width_request = 48;
            spinner.height_request = 48;
            spinner.start ();

            var label = new Gtk.Label (_("Processing"));
            label.hexpand = true;
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.valign = Gtk.Align.CENTER;
            box.vexpand = true;

            box.add (spinner);
            box.add (label);
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
            error_layout = new Gtk.Grid ();

            var primary_label = new Gtk.Label (_("There Was a Problem Processing Your Payment"));
            primary_label.get_style_context ().add_class ("primary");
            primary_label.max_width_chars = 35;
            primary_label.wrap = true;
            primary_label.xalign = 0;

            secondary_error_label = new Gtk.Label (error_reason);
            secondary_error_label.max_width_chars = 35;
            secondary_error_label.wrap = true;
            secondary_error_label.xalign = 0;

            var icon = new Gtk.Image.from_icon_name ("system-software-install", Gtk.IconSize.DIALOG);

            var overlay_icon = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.LARGE_TOOLBAR);
            overlay_icon.halign = Gtk.Align.END;
            overlay_icon.valign = Gtk.Align.END;

            var overlay = new Gtk.Overlay ();
            overlay.valign = Gtk.Align.START;
            overlay.add (icon);
            overlay.add_overlay (overlay_icon);

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            grid.attach (overlay, 0, 0, 1, 2);
            grid.attach (primary_label, 1, 0, 1, 1);
            grid.attach (secondary_error_label, 1, 1, 1, 1);

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

    private void validate (int entry, string new_text) {
        try {
            switch (entry) {
                case 0:
                    var regex = new Regex ("""[a-z|0-9]+@[a-z|0-9]+\.[a-z]+""");
                    email_valid = regex.match (new_text);
                    break;
                case 1:
                    card_valid = is_card_valid (new_text);
                    break;
                case 2:
                    if (new_text.length < 4) {
                        expiration_valid = false;
                    } else {
                        var regex = new Regex ("""^[0-9]{2}\/?[0-9]{2}$""");
                        expiration_valid = regex.match (new_text);
                    }
                    break;
                case 3:
                    var regex = new Regex ("""[0-9]{3,4}""");
                    cvc_valid = regex.match (new_text);
                    break;
            }
        } catch (Error e) {
            warning (e.message);
        }

        is_payment_sensitive ();
    }

    private void is_payment_sensitive () {
        if (email_valid && card_valid && expiration_valid && cvc_valid) {
            pay_button.sensitive = true;
        } else {
            pay_button.sensitive = false;
        }
    }

    private bool is_card_valid (string numbers) {
        var char_count = numbers.char_count ();

        if (char_count < 14) return false;

        int hash = int.parse (numbers[char_count-1:char_count]);

        int j = 1;
        int sum = 0;
        for (int i = char_count -1; i > 0; i--) {
            var number = int.parse (numbers[i-1:i]);
            if (j++ % 2 == 1) {
                number = number * 2;
                if (number > 9) {
                    number = number - 9;
                }
            }

            sum += number;
        }

        return (10 - (sum % 10)) % 10 == hash;
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                if (layouts.visible_child_name == "card") {
                    show_spinner_view ();
                    on_pay_clicked ();
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
            string expiration_dateyear = card_expiration_entry.text.replace("/", "");
            var year = (int.parse (expiration_dateyear[2:4]) + 2000).to_string ();

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
