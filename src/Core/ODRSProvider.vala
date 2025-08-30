/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ODRSProvider : Object {
    private const string REVIEW_SERVER = "https://odrs.gnome.org/1.0/reviews/api";

    public static async void fetch_reviews_for_app (string app_id) {
        string user_hash;
        try {
            user_hash = get_user_hash ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var distro = Environment.get_os_info ("NAME");

        var builder = new Json.Builder ();
        builder.begin_object ();

        builder.set_member_name ("user_hash");
        builder.add_string_value (user_hash);

        builder.set_member_name ("app_id");
        builder.add_string_value (app_id);

        builder.set_member_name ("locale");
        builder.add_string_value (Intl.setlocale (LocaleCategory.MESSAGES, null));

        builder.set_member_name ("distro");
        builder.add_string_value (distro);

        builder.set_member_name ("version");
        builder.add_string_value ("unknown");

        builder.set_member_name ("limit");
        builder.add_int_value (0);

        builder.end_object ();

        var generator = new Json.Generator () {
            root = builder.get_root ()
        };

        var request_body = generator.to_data (null);

        var message = new Soup.Message ("POST", REVIEW_SERVER + "/fetch");
        message.request_headers.append ("Content-Type", "application/json; charset=utf-8");
        message.request_headers.append ("User-Agent", "AppCenter/1.0");
        message.set_request_body_from_bytes (null, new Bytes (request_body.data));

        var session = new Soup.Session ();

        Bytes bytes;
        try {
            bytes = yield session.send_and_read_async (message, GLib.Priority.DEFAULT, null);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var output = (string) bytes.get_data ();
        if (output == null) {
            critical ("no output");
            return;
        }

        critical (output);

        var parser = new Json.Parser ();
        try {
            parser.load_from_data (output);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var root = parser.get_root ();
        if (root == null) {
            critical ("no root");
            return;
        }

        if (root.get_node_type () != ARRAY) {
            critical ("no array");
            return;
        }

        var reviews = root.get_array ();
        for (int i = 0; i < reviews.get_length (); i++) {
            var element = reviews.get_element (i);

            var rating = element.get_object ().get_int_member ("rating");
            var score = element.get_object ().get_int_member ("score");

            // from http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
            var karma_up = element.get_object ().get_int_member ("karma_up");
            var karma_down = element.get_object ().get_int_member ("karma_down");
            double priority = 0;
            if (karma_up > 0 || karma_down > 0) {
                priority = (
                    (karma_up + 1.9208) / (karma_up + karma_down) - 1.96 * Math.sqrt (
                        (karma_up * karma_down) / (karma_up + karma_down) + 0.9604
                    ) / (karma_up + karma_down)
                ) / (1 + 3.8416 / (karma_up + karma_down));
                priority *= 100;
            }
            critical (app_id);
            critical (rating.to_string ());
            critical (score.to_string ());
            critical (priority.to_string ());
        }
    }

   /*
    * This SHA1 hash is composed of the contents of machine-id and your
    * username and is also salted with a hardcoded value.
    *
    * This provides an identifier that can be used to identify a specific
    * user on a machine, allowing them to cast only one vote or perform
    * one review on each app.
    *
    * There is no known way to calculate the machine ID or username from
    * the machine hash and there should be no privacy issue.
    *
    * Based on https://gitlab.gnome.org/GNOME/gnome-software/-/blob/main/lib/gs-utils.c#L248
    */
    private static string get_user_hash () throws Error {
        string contents;
        size_t length;

        if (!(FileUtils.get_contents ("/etc/machine-id", out contents, out length))) {
            return null;
        }

        var salted = "%s[%s:%s]".printf (
            Application.get_default ().application_id,
            Environment.get_user_name (),
            contents
        );

        return Checksum.compute_for_string (SHA1, salted);
    }
}
