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
    public const string STRIPE_VERSION = "2023-08-16";

    private const string STRIPE_URI = "https://api.stripe.com/v1/tokens";
    private const string STRIPE_AUTH = "Bearer %s";
    private const string STRIPE_REQUEST = "card[number]=%s"
                            + "&card[cvc]=%s&card[exp_month]=%s&card[exp_year]=%s";

    public class ErrorResponse : GLib.Object {
        public string message { get; construct; }
        public string code { get; construct; }
        public string param { get; construct; }
        public string decline_code { get; construct; }
        public string charge { get; construct; }
    }
    
    public class Response<T> : GLib.Object {
        public ErrorResponse? error { get; set; }
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

        public TokenRequest(string card_number, string card_cvc, int card_exp_month, int card_exp_year, string stripe_key) {
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

        public async Response<Token> send (HttpClient client) {
            var headers = new Gee.HashMap<string, string> ();

            var payload = _build_payload ();

            headers.set ("Stripe-Version", STRIPE_VERSION);
            headers.set ("Authorization", STRIPE_AUTH.printf (this.stripe_key));

            AppCenterCore.HttpClient.Response? response = null;
            try {
                response = yield client.post (STRIPE_URI, payload, headers);
            } catch (StripeError e) {
                throw new StripeError.NETWORK_ERROR ("Unable to complete payment, please try again later. Error detail: %s".printf (e.message));
            }

            if (response == null) {
                throw new StripeError.NETWORK_ERROR ("Unable to complete payment, please try again later.");
            }

            if (response.status_code != 200) {
                ErrorResponse? error = null;
                try {
                    error = Json.gobject_from_data (typeof (ErrorResponse), response.body) as ErrorResponse;
                } catch (Error e) {
                    throw new StripeError.SERVER_ERROR ("Unable to complete payment, please try again later.");
                }

                return new Response<Token> () { error = error };
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

        public TokenRequestBuilder exp_month (int card_exp_month) {
            this._card_exp_month = card_exp_month;
            return this;
        }

        public TokenRequestBuilder exp_year (int card_exp_year) {
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