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

public errordomain AppCenterCore.HoustonError {
    MISSING_PARAMETERS,
    NETWORK_ERROR,
    SERVER_ERROR,
}

public class AppCenterCore.Houston {
    public const string HOUSTON_URI = "https://developer.elementary.io/api/payment/%s";

    public class PaymentRequest : Object {
        public string app_id { get; construct; }
        public string stripe_key { get; construct; }
        public string token { get; construct; }
        public string email { get; construct; }
        public int amount { get; construct; }

        public PaymentRequest (string app_id, string stripe_key, string token, string email, int amount) {
            Object (
                app_id: app_id,
                stripe_key: stripe_key,
                token: token,
                email: email,
                amount: amount
            );
        }

        /*
         * Build the JSON payload in the following format:
         * {
         *   "data": {
         *     "key": "stripe_key",
         *     "token": "stripe_token",
         *     "email": "user_email",
         *     "amount": 100,
         *     "currency": "USD"
         *   }
         * }
         */
        public string _build_payload () {
            var builder = new Json.Builder ()
                .begin_object ()
                .set_member_name ("data")
                .begin_object ()
                .set_member_name ("key")
                .add_string_value (stripe_key)
                .set_member_name ("token")
                .add_string_value (token)
                .set_member_name ("email")
                .add_string_value (email)
                .set_member_name ("amount")
                .add_int_value (amount)
                .set_member_name ("currency")
                .add_string_value ("USD")
                .end_object ()
                .end_object ();

            Json.Generator generator = new Json.Generator ();
            Json.Node root = builder.get_root ();
            generator.set_root (root);

            return generator.to_data (null);
        }

        public async void send (HttpClient client) throws HoustonError {
            string uri = HOUSTON_URI.printf (app_id);

            var payload = _build_payload ();
            var headers = new GLib.HashTable<string, string> (str_hash, str_equal);

            headers.insert ("Accepts", "application/vnd.api+json");
            headers.insert ("Content-Type", "application/vnd.api+json");

            AppCenterCore.HttpClient.Response? response = null;
            try {
                response = yield client.post (uri, payload, headers);
            } catch (Error e) {
                throw new HoustonError.NETWORK_ERROR ("Unable to complete payment, please try again later. Error detail: %s".printf (e.message));
            }

            var parser = new Json.Parser ();
            Json.Node? root = null;

            debug ("Response from Houston: %s".printf (response.body));

            try {
                parser.load_from_data (response.body);
                root = parser.get_root ();
            } catch (Error e) {
                throw new HoustonError.SERVER_ERROR ("Unable to complete payment, please try again later. Error detail: %s".printf (e.message));
            }

            if (root == null) {
                throw new HoustonError.SERVER_ERROR ("Unable to complete payment, please try again later.");
            }

            if (root.get_object ().has_member ("errors")) {
                throw new HoustonError.SERVER_ERROR ("Unable to complete payment, please try again later.");
            }
        }
    }

    public class PaymentRequestBuilder {
        private string? _app_id = null;
        private string? _stripe_key = null;
        private string? _token = null;
        private string? _email = null;
        private int? _amount = null;

        /**
         * @param app_id AppCenter application ID
         */
        public PaymentRequestBuilder app_id (string app_id) {
            this._app_id = app_id;
            return this;
        }

        /**
         * @param token Stripe bearer token
         */
         public PaymentRequestBuilder stripe_key (string stripe_key) {
            this._stripe_key = stripe_key;
            return this;
        }

        /**
         * @param token Stripe card token
         */
        public PaymentRequestBuilder token (string token) {
            this._token = token;
            return this;
        }

        /**
         * @param email Email address of the user
         */
        public PaymentRequestBuilder email (string email) {
            this._email = email;
            return this;
        }

        /**
         * @param amount Amount in cents
         */
        public PaymentRequestBuilder amount (int amount) {
            this._amount = amount;
            return this;
        }

        /**
         * Build the PaymentRequest object
         *
         * @return PaymentRequest object
         * @throws HoustonError.MISSING_PARAMETERS if any of the required parameters are missing
         */
        public PaymentRequest build () throws HoustonError {
            if (_app_id == null || _stripe_key == null || _token == null || _email == null || _amount == null) {
                throw new HoustonError.MISSING_PARAMETERS ("Missing required parameters");
            }

            return new PaymentRequest (_app_id, _stripe_key, _token, _email, _amount);
        }
    }
}
