
/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

void add_soup_client_tests () {
    // Test post
    Test.add_func ("/SoupClient/post", () => {
        var client = new AppCenterCore.SoupClient ();

        var loop = new MainLoop ();
        AppCenterCore.HttpClient.Response? response = null;
        client.post.begin ("https://httpbin.org/post", "foobar", null, (obj, res) => {
            try {
                response = client.post.end (res);
            } catch (Error e) {
                assert (false);
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (response != null);
        assert (response.status_code == 200);

        try {
            var json = new Json.Parser ();
            json.load_from_data (response.body, -1);

            assert (json.get_root ().get_object ().get_string_member ("data") == "foobar");
            assert (json.get_root ().get_object ().get_object_member ("headers").get_string_member ("User-Agent") == "AppCenterCore.SoupClient/1.0");
        } catch (Error e) {
            assert (false);
        }
    });

    // Test post with headers
    Test.add_func ("/SoupClient/post_with_headers", () => {
        var client = new AppCenterCore.SoupClient ();

        var loop = new MainLoop ();
        AppCenterCore.HttpClient.Response? response = null;
        var headers = new GLib.HashTable<string, string> (str_hash, str_equal);
        headers.insert ("X-Foo", "Bar");
        client.post.begin ("https://httpbin.org/post", "foobar", headers, (obj, res) => {
            try {
                response = client.post.end (res);
            } catch (Error e) {
                assert (false);
            } finally {
                loop.quit ();
            }
        });
        loop.run ();

        assert (response != null);
        assert (response.status_code == 200);

        try {
            var json = new Json.Parser ();
            json.load_from_data (response.body, -1);

            assert (json.get_root ().get_object ().get_string_member ("data") == "foobar");
            assert (json.get_root ().get_object ().get_object_member ("headers").get_string_member ("X-Foo") == "Bar");
        } catch (Error e) {
            assert (false);
        }
    });
}
