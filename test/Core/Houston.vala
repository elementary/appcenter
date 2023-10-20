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

void add_houston_tests () {
    Test.add_func ("/houston/payment_request_builder", () => {
        var builder = new AppCenterCore.Houston.PaymentRequestBuilder ()
            .amount (100)
            .stripe_key ("pk_test_123456")
            .token ("tok_1NxAA7HS9fmgRLTdMytLPrAi")
            .app_id ("com.github.elementary.houston")
            .email ("houston@example.com");

        Error? caught_error = null;
        AppCenterCore.Houston.PaymentRequest? request = null;
        try {
            request = builder.build ();
        } catch (AppCenterCore.HoustonError e) {
            caught_error = e;
        }

        assert (request != null);
        assert (caught_error == null);
        assert (request.amount == 100);
        assert (request.token == "tok_1NxAA7HS9fmgRLTdMytLPrAi");
        assert (request.app_id == "com.github.elementary.houston");
        assert (request.stripe_key == "pk_test_123456");
        assert (request.email == "houston@example.com");
    });

    Test.add_func ("/houston/payment_request_builder/invalid", () => {
        var builder = new AppCenterCore.Houston.PaymentRequestBuilder ();

        Error? caught_error = null;
        try {
            builder
                .amount (100)
                .token ("pk_test_123456")
                .app_id ("com.github.elementary.houston")
                .build ();
        } catch (AppCenterCore.HoustonError e) {
            caught_error = e;
        }

        assert (caught_error != null);
        assert (caught_error is AppCenterCore.HoustonError.MISSING_PARAMETERS);
    });

    Test.add_func ("/houston/payment_request/build_payload", () => {
        var request = new AppCenterCore.Houston.PaymentRequest (
            "com.github.elementary.houston",
            "pk_test_123456",
            "tok_1NxAA7HS9fmgRLTdMytLPrAi",
            "houston@example.com",
            100
        );

        var payload = request._build_payload ();

        var parser = new Json.Parser ();
        Json.Node? root = null;

        try {
            parser.load_from_data (payload);
            root = parser.get_root ();
        } catch (Error e) {
            assert (false);
        }

        assert (root != null);
        assert (root.get_object ().get_size () == 1);

        var data = root.get_object ().get_object_member ("data");
        assert (data.get_size () == 5);
        assert (data.has_member ("key"));
        assert (data.has_member ("amount"));
        assert (data.has_member ("currency"));
        assert (data.has_member ("email"));
        assert (data.has_member ("token"));

        assert (data.get_member ("key").get_string () == "pk_test_123456");
        assert (data.get_member ("amount").get_int () == 100);
        assert (data.get_member ("currency").get_string () == "USD");
        assert (data.get_member ("email").get_string () == "houston@example.com");
        assert (data.get_member ("token").get_string () == "tok_1NxAA7HS9fmgRLTdMytLPrAi");
    });

    Test.add_func ("/houston/payment_request/send", () => {
        var request = new AppCenterCore.Houston.PaymentRequest (
            "com.github.elementary.houston",
            "pk_test_123456",
            "tok_1NxAA7HS9fmgRLTdMytLPrAi",
            "houston@example.com",
            100
        );

        var http_client = new MockHttpClient ("{}");

        var loop = new MainLoop ();
        request.send.begin (http_client, (obj, res) => {
            try {
                request.send.end (res);
            } catch (Error e) {
                assert (false);
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (http_client.request_uri == "https://developer.elementary.io/api/payment/com.github.elementary.houston");
        assert (http_client.headers["Content-Type"] == "application/vnd.api+json");
        assert (http_client.headers["Accepts"] == "application/vnd.api+json");

        var parser = new Json.Parser ();
        Json.Node? root = null;

        try {
            parser.load_from_data (http_client.data);
            root = parser.get_root ();
        } catch (Error e) {
            assert (false);
        }

        assert (root != null);
        assert (root.get_object ().get_size () == 1);

        var data = root.get_object ().get_object_member ("data");
        assert (data.get_size () == 5);
        assert (data.has_member ("key"));
        assert (data.has_member ("amount"));
        assert (data.has_member ("currency"));
        assert (data.has_member ("email"));
        assert (data.has_member ("token"));

        assert (data.get_member ("key").get_string () == "pk_test_123456");
        assert (data.get_member ("amount").get_int () == 100);
        assert (data.get_member ("currency").get_string () == "USD");
        assert (data.get_member ("email").get_string () == "houston@example.com");
        assert (data.get_member ("token").get_string () == "tok_1NxAA7HS9fmgRLTdMytLPrAi");
    });

    Test.add_func ("/houston/payment_request/send/error", () => {
        var request = new AppCenterCore.Houston.PaymentRequest (
            "com.github.elementary.houston",
            "pk_test_123456",
            "tok_1NxAA7HS9fmgRLTdMytLPrAi",
            "houston@example.com",
            100
        );

        var http_client = new MockHttpClient ("{}", true);

        var loop = new MainLoop ();
        Error? caught_error = null;
        request.send.begin (http_client, (obj, res) => {
            try {
                request.send.end (res);
            } catch (Error e) {
                caught_error = e;
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (caught_error != null);
        assert (caught_error is AppCenterCore.HoustonError.NETWORK_ERROR);
    });

    Test.add_func ("/houston/payment_request/send/error/invalid_response", () => {
        var request = new AppCenterCore.Houston.PaymentRequest (
            "com.github.elementary.houston",
            "pk_test_123456",
            "tok_1NxAA7HS9fmgRLTdMytLPrAi",
            "houston@example.com",
            100
        );

        var http_client = new MockHttpClient (
            """
            {"errors":[{"code":"StripeCardError","title":"Error","detail":"Your card was declined."}]}
            """
        );

        var loop = new MainLoop ();
        Error? caught_error = null;
        request.send.begin (http_client, (obj, res) => {
            try {
                request.send.end (res);
            } catch (Error e) {
                caught_error = e;
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (caught_error != null);
        assert (caught_error is AppCenterCore.HoustonError.SERVER_ERROR);
    });
}
