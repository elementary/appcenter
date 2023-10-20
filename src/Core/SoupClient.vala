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

public class AppCenterCore.SoupClient : Object, AppCenterCore.HttpClient {
    private Soup.Session session;

    construct {
        session = new Soup.Session ();
    }

    public async AppCenterCore.HttpClient.Response post (string url, string data, GLib.HashTable<string, string>? headers = null) throws Error {
        var message = new Soup.Message ("POST", url);

        if (headers != null) {
            headers.foreach ((key, value) => {
                message.request_headers.append (key, value);
            });
        }

        message.request_headers.append ("User-Agent", "AppCenterCore.SoupClient/1.0");
        message.set_request_body_from_bytes (null, new Bytes (data.data));

        var response = yield session.send_async (message, GLib.Priority.DEFAULT, null);
        var result = new StringBuilder ();
        var buffer = new uint8[1024];
        while (true) {
            var read = yield response.read_async (buffer);
            if (read == 0) {
                break;
            }

            result.append_len ((string)buffer, read);
        }

        var response_headers = new GLib.HashTable<string, string> (str_hash, str_equal);
        message.response_headers.foreach ((name, value) => {
            response_headers.set (name, value);
        });

        return new AppCenterCore.HttpClient.Response () {
            status_code = message.status_code,
            headers = response_headers,
            body = result.str
        };
    }
}
