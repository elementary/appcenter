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
    private Soup.Session session;

    private static GLib.Settings caches_store;

    static construct {
        caches_store = new GLib.Settings ("io.elementary.appcenter.caches");
    }

    construct {
        session = new Soup.Session ();
        session.timeout = 15;
    }

    private Json.Object process_response (string? res) throws Error {
        if (res == null) {
            throw new IOError.FAILED ("Error while talking to Houston");
        }

        var parser = new Json.Parser ();
        parser.load_from_data (res, -1);

        var root = parser.get_root ().get_object ();

        if (root.has_member ("errors") && root.get_array_member ("errors").get_length () > 0) {
            var err = root.get_array_member ("errors").get_object_element (0).get_string_member ("title");

            if (err != null) {
                throw new IOError.FAILED (err);
            } else {
                throw new IOError.FAILED ("Error while talking to Houston");
            }
        }

        return root;
    }

    public async string[] get_app_ids (string endpoint) {
        var uri = Build.HOUSTON_API_URL + endpoint;
        string[] app_ids = {};

        debug ("Requesting newest applications from %s", uri);

        var message = new Soup.Message ("GET", uri);
        session.queue_message (message, (sess, mess) => {
            try {
                var res = process_response ((string) mess.response_body.data);
                if (res.has_member ("data")) {
                    var data = res.get_array_member ("data");

                    var arr_builder = new VariantBuilder (GLib.VariantType.STRING_ARRAY);
                    foreach (unowned Json.Node id in data.get_elements ()) {
                        unowned string? val = id.get_string ();
                        if (val == null) {
                            continue;
                        }

                        arr_builder.add ("s", val);
                        app_ids += val;
                    }

                    var caches = caches_store.get_value ("api-caches");

                    var dict_builder = new VariantBuilder (new VariantType ("a{sas}"));

                    // Iterate over the caches already in the GSetting
                    var iter = caches.iterator ();
                    Variant? existing_item = iter.next_value ();
                    while (existing_item != null) {
                        string? key = null;

                        // Get the dict key of this existing item
                        existing_item.@get ("{sas}", out key, null);

                        // Copy existing items to new dict, unless this is the item we're updating
                        if (key != endpoint) {
                            dict_builder.add_value (existing_item);
                        }

                        existing_item = iter.next_value ();
                    }

                    // Add the new list of apps to the cache dict
                    dict_builder.add ("{sas}", endpoint, arr_builder);

                    caches_store.set_value ("api-caches", dict_builder.end ());
                }
            } catch (Error e) {
                warning ("Houston: %s", e.message);

                var caches = caches_store.get_value ("api-caches");
                // Get the array of app IDs corresponding to this API endpoint from the dictionary
                var cached_ids = caches.lookup_value (endpoint, GLib.VariantType.STRING_ARRAY);

                if (cached_ids != null) {
                    app_ids = cached_ids.get_strv ();
                }
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
