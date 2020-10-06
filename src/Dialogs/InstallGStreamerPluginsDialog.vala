/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class InstallGStreamerPluginsDialog : Granite.MessageDialog {
    public string[] resources { get; construct; }

    private Gtk.Spinner spinner;
    private Cancellable cancellable;

    public InstallGStreamerPluginsDialog (string[] resources) {
        Object (
            title: "",
            primary_text: _("Additional plugins required"),
            secondary_text: _("Searching for plugins to install…"),
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-error"),
            window_position: Gtk.WindowPosition.CENTER,
            resources: resources
        );
    }

    construct {
        cancellable = new Cancellable ();

        var install_button = add_button (_("Install Plugins"), Gtk.ResponseType.ACCEPT);
        install_button.sensitive = false;
        install_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        spinner = new Gtk.Spinner () {
            active = true
        };
        custom_bin.add (spinner);

        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.ACCEPT:
                    // install stuff
                    break;
                default:
                    cancellable.cancel ();
                    destroy ();
                    break;
            }
        });
    }

    public async void offer_installation () {
        show_all ();
        present ();

        Pk.Results codecs;
        try {
            codecs = yield AppCenterCore.PackageKitBackend.get_default ().lookup_codecs (resources, cancellable);
        } catch (Error e) {
            if (!(e is GLib.IOError.CANCELLED)) {
                warning ("Error while looking up codecs: %s", e.message);
            }

            return;
        }

        spinner.active = false;
        var packages = codecs.get_package_array ();
        for (int i = 0; i < packages.length; i++) {
            warning (packages[i].get_name ());
        }
    }
}
