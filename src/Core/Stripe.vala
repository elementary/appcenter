/*
* Copyright 2023 elementary, Inc. (https://elementary.io)
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

public errordomain AppCenterCore.StripeError {
    MISSING_PARAMETERS,
    NETWORK_ERROR,
    SERVER_ERROR,
}

public class AppCenterCore.Stripe {
    public const string INTERNAL_ERROR_MESSAGE = N_("An error occurred while processing the card. Please try again later. We apologize for any inconvenience caused.");
    public const string DEFAULT_ERROR_MESSAGE = N_("Please review your payment info and try again.");

    public const string STRIPE_VERSION = "2023-08-16";

    private const string STRIPE_URI = "https://api.stripe.com/v1/tokens";
    private const string STRIPE_AUTH = "Bearer %s";
    private const string STRIPE_REQUEST = "card[number]=%s"
                            + "&card[cvc]=%s&card[exp_month]=%s&card[exp_year]=%s";

    public class ErrorResponse : Json.Serializable, GLib.Object {
        public string error_type { get; set; }
        public string message { get; construct; }
        public string? code { get; construct; }
        public string? param { get; construct; }
        public string? decline_code { get; construct; }
        public string? charge { get; construct; }

        public override unowned ParamSpec? find_property (string name) {
            // Map the "type" field from JSON to "error_type" property
            if (name == "type") {
                return get_class ().find_property ("error_type");
            }

            return get_class ().find_property (name);
        }

        public unowned string to_friendly_string () {
            switch (error_type) {
                case "card_error":
                    if (code == null) {
                        return _(INTERNAL_ERROR_MESSAGE);
                    }

                    switch (code) {
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
                            if (decline_code != null) {
                                debug ("Stripe decline error code: %s", decline_code);
                                return get_decline_reason ();
                            } else {
                                return _(DEFAULT_ERROR_MESSAGE);
                            }
                        default:
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
        }

        private unowned string get_decline_reason () {
            if (decline_code == null) {
                return _(DEFAULT_ERROR_MESSAGE);
            }

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

    public class Response<T> : GLib.Object {
        public ErrorResponse? error { get; set; default = null; }
        public T? data { get; set; }
    }

    public class Token : GLib.Object {
        public string id { get; construct; }
        public string object { get; construct; }
        public bool livemode { get; construct; }
        public bool used { get; construct; }
    }

    public class TokenRequest : Object {
        public string card_number { get; construct; }
        public string card_cvc { get; construct; }
        public int card_exp_month { get; construct; }
        public int card_exp_year { get; construct; }
        public string stripe_key { get; construct; }

        public TokenRequest (string card_number, string card_cvc, int card_exp_month, int card_exp_year, string stripe_key) {
            Object (
                card_number: card_number,
                card_cvc: card_cvc,
                card_exp_month: card_exp_month,
                card_exp_year: card_exp_year,
                stripe_key: stripe_key
            );
        }

        public string _build_payload () {
            return STRIPE_REQUEST.printf (
                Uri.escape_string (this.card_number),
                Uri.escape_string (this.card_cvc),
                Uri.escape_string (this.card_exp_month.to_string ()),
                Uri.escape_string (this.card_exp_year.to_string ())
            );
        }

        public async Response<Token> send (HttpClient client) throws StripeError {
            var headers = new GLib.HashTable<string, string> (str_hash, str_equal);

            var payload = _build_payload ();

            headers.insert ("Stripe-Version", STRIPE_VERSION);
            headers.insert ("Authorization", STRIPE_AUTH.printf (this.stripe_key));

            AppCenterCore.HttpClient.Response? response = null;
            try {
                response = yield client.post (STRIPE_URI, payload, headers);
            } catch (Error e) {
                throw new StripeError.NETWORK_ERROR ("Unable to complete payment, please try again later. Error detail: %s".printf (e.message));
            }

            if (response == null) {
                throw new StripeError.NETWORK_ERROR ("Unable to complete payment, please try again later.");
            }

            debug ("Stripe response: %s".printf (response.body));

            if (response.status_code != 200) {
                try {
                    var res = Json.gobject_from_data (typeof (Response), response.body) as Response;
                    return res;
                } catch (Error e) {
                    throw new StripeError.SERVER_ERROR ("Unable to complete payment, please try again later.");
                }
            }

            Token? token = null;
            try {
                token = Json.gobject_from_data (typeof (Token), response.body) as Token;
            } catch (Error e) {
                throw new StripeError.SERVER_ERROR ("Unable to complete payment, please try again later.");
            }

            return new Response<Token> () { data = token };
        }
    }

    public class TokenRequestBuilder : Object {
        private string _card_number;
        private string _card_cvc;
        private int _card_exp_month = -1;
        private int _card_exp_year = -1;
        private string _stripe_key;

        public TokenRequestBuilder card_number (string card_number) {
            this._card_number = card_number;
            return this;
        }

        public TokenRequestBuilder cvc (string card_cvc) {
            this._card_cvc = card_cvc;
            return this;
        }

        public TokenRequestBuilder expiration_month (int card_exp_month) {
            this._card_exp_month = card_exp_month;
            return this;
        }

        public TokenRequestBuilder expiration_year (int card_exp_year) {
            this._card_exp_year = card_exp_year;
            return this;
        }

        public TokenRequestBuilder stripe_key (string stripe_key) {
            this._stripe_key = stripe_key;
            return this;
        }

        public TokenRequest build () throws StripeError {
            if (this._card_number == null || this._card_cvc == null || this._card_exp_month < 0 || this._card_exp_year < 0 || this._stripe_key == null) {
                throw new StripeError.MISSING_PARAMETERS ("Missing parameters for Stripe payment");
            }

            return new TokenRequest (_card_number, _card_cvc, _card_exp_month, _card_exp_year, _stripe_key);
        }
    }
}
