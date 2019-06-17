/* Copyright 2017 elementary LLC. (https://elementary.io)
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*
* Authored by: Blake Kostner <blake@elementary.io>
*/

public class AppCenterCore.Houston : Object {
#if POP_OS
    private const string HOUSTON_API_URL = "https://api.pop-os.org/shop/v1";
#else
    private const string HOUSTON_API_URL = "https://developer.elementary.io/api";
#endif

    private Soup.Session session;

    construct {
        session = new Soup.Session ();
    }

    private Json.Object process_response (string res) throws Error {
        var parser = new Json.Parser ();
        parser.load_from_data (res, -1);

        var root = parser.get_root ().get_object ();

        if (root.has_member ("errors") && root.get_array_member ("errors").get_length () > 0) {
            var err = root.get_array_member ("errors").get_object_element (0).get_string_member ("title");

            if (err != null) {
                throw new Error (0, 0, err);
            } else {
                throw new Error (0, 0, "Error while talking to Houston");
            }
        }

        return root;
    }

    public async string[] get_app_ids (string endpoint) {
        var uri = HOUSTON_API_URL + endpoint;
        string[] app_ids = {};

        debug ("Requesting newest applications from %s", uri);

        var message = new Soup.Message ("GET", uri);
        session.queue_message (message, (sess, mess) => {
            try {
                var res = process_response ((string) mess.response_body.data);
                if (res.has_member ("data")) {
                    var data = res.get_array_member ("data");

                    foreach (var id in data.get_elements ()) {
                        app_ids += ((string) id.get_value ());
                    }
                }
            } catch (Error e) {
                warning ("Houston: %s", e.message);
            }

            Idle.add (get_app_ids.callback);
        });

        yield;
        return app_ids;
    }

    private static GLib.Once<Houston> instance;
    public static unowned Houston get_default () {
        return instance.once (() => { return new Houston (); });
    }
}
