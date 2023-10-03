/*-
 * Copyright (c) 2023 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

void add_stripe_tests () {
    Test.add_func ("/stripe/token_request_builder", () => {
        var builder = new AppCenterCore.Stripe.TokenRequestBuilder ()
            .card_number ("4242424242424242")
            .expiration_month (12)
            .expiration_year (2023)
            .cvc ("123")
            .stripe_key ("pk_test_123456");

        Error? caught_error = null;
        AppCenterCore.Stripe.TokenRequest? request = null;
        try {
            request = builder.build ();
        } catch (AppCenterCore.StripeError e) {
            caught_error = e;
        }

        assert (request != null);
        assert (caught_error == null);
        assert (request.card_number == "4242424242424242");
        assert (request.card_exp_month == 12);
        assert (request.card_exp_year == 2023);
        assert (request.card_cvc == "123");
        assert (request.stripe_key == "pk_test_123456");
    });

    Test.add_func ("/stripe/token_request_builder/invalid", () => {
        var builder = new AppCenterCore.Stripe.TokenRequestBuilder ()
            .card_number ("4242424242424242")
            .expiration_month (12)
            .expiration_year (2023)
            .cvc ("123");

        Error? caught_error = null;
        AppCenterCore.Stripe.TokenRequest? request = null;
        try {
            request = builder.build ();
        } catch (AppCenterCore.StripeError e) {
            caught_error = e;
        }

        assert (request == null);
        assert (caught_error != null);
        assert (caught_error is AppCenterCore.StripeError.MISSING_PARAMETERS);
    });

    Test.add_func ("/stripe/token_request/build_payload", () => {
        var request = new AppCenterCore.Stripe.TokenRequest ("4242424242424242", "123", 12, 2023, "pk_test_123456");
        var payload = request._build_payload ();

        GLib.HashTable<string, string>? parsed = null;
        Error? caught_error = null;
        try {
            parsed = Uri.parse_params (payload);
        } catch (GLib.Error e) {
            caught_error = e;
        }

        assert (caught_error == null);
        assert (parsed.length == 4);
        assert (parsed["card[number]"] == "4242424242424242");
        assert (parsed["card[exp_month]"] == "12");
        assert (parsed["card[exp_year]"] == "2023");
        assert (parsed["card[cvc]"] == "123");
    });

    Test.add_func ("/stripe/token_request/success", () => {
        var request = new AppCenterCore.Stripe.TokenRequest ("4242424242424242", "123", 12, 2023, "pk_test_123456");

        var http_client = new MockHttpClient (
            """
            {
            "id": "tok_1NuMf52eZvKYlo2ChWEONofg",
            "object": "token",
            "card": {
                "id": "card_1NuMf52eZvKYlo2CtQImWMwH",
                "object": "card",
                "address_city": null,
                "address_country": null,
                "address_line1": null,
                "address_line1_check": null,
                "address_line2": null,
                "address_state": null,
                "address_zip": null,
                "address_zip_check": null,
                "brand": "Visa",
                "country": "US",
                "cvc_check": "pass",
                "dynamic_last4": null,
                "exp_month": 8,
                "exp_year": 2024,
                "fingerprint": "Xt5EWLLDS7FJjR1c",
                "funding": "credit",
                "last4": "4242",
                "metadata": {},
                "name": null,
                "redaction": null,
                "tokenization_method": null,
                "wallet": null
            },
            "client_ip": null,
            "created": 1695678591,
            "livemode": false,
            "redaction": null,
            "type": "card",
            "used": false
            }
            """
        );

        var loop = new MainLoop ();
        Error? caught_error = null;
        AppCenterCore.Stripe.Response<AppCenterCore.Stripe.Token>? token = null;

        request.send.begin (http_client, (obj, res) => {
            try {
                token = request.send.end (res);
            } catch (Error e) {
                caught_error = e;
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (http_client.request_uri == "https://api.stripe.com/v1/tokens");
        assert (http_client.headers["Stripe-Version"] == "2023-08-16");
        assert (http_client.headers["Authorization"] == "Bearer pk_test_123456");

        assert (caught_error == null);
        assert (token != null);
        assert (token.error == null);
        assert (token.data != null);
        assert (token.data.id == "tok_1NuMf52eZvKYlo2ChWEONofg");
        assert (token.data.object == "token");
        assert (token.data.livemode == false);
        assert (token.data.used == false);
    });

    Test.add_func ("/stripe/token_request/error", () => {
        var request = new AppCenterCore.Stripe.TokenRequest ("4242424242424242", "123", 12, 2023, "pk_test_123456");

        var http_client = new MockHttpClient (
            """
            {
                "error": {
                  "message": "Request validation error: validator 0xc0011ceb10 failed: object property 'card' validation failed: could not validate against any of the constraints",
                  "type": "invalid_request_error"
                }
            }
            """,
            false,
            400
        );

        var loop = new MainLoop ();
        Error? caught_error = null;
        AppCenterCore.Stripe.Response<AppCenterCore.Stripe.Token>? token = null;

        request.send.begin (http_client, (obj, res) => {
            try {
                token = request.send.end (res);
            } catch (Error e) {
                caught_error = e;
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (http_client.request_uri == "https://api.stripe.com/v1/tokens");
        assert (http_client.headers["Stripe-Version"] == "2023-08-16");
        assert (http_client.headers["Authorization"] == "Bearer pk_test_123456");

        assert (caught_error == null);
        assert (token.error != null);
        assert (token.error.message == "Request validation error: validator 0xc0011ceb10 failed: object property 'card' validation failed: could not validate against any of the constraints");
        assert (token.error.error_type == "invalid_request_error");
    });
}
