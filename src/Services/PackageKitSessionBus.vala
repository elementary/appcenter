/*
 * Copyright 2020 elementary, Inc. (https://elementary.io)
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

[DBus (name="org.freedesktop.PackageKit.Modify2")]
public class PackageKitSessionBus : Object {
    [DBus (name="InstallGStreamerResources")]
    public async void install_gstreamer_resources (
        string[] resources,
        string interaction,
        string desktop_id,
        GLib.HashTable<string, Variant> platform_data
    ) throws GLib.Error {
        var notification = new Notification (_("Additional Multimedia Codecs Required"));
        notification.set_body (_("Videos is requesting additional codecs"));
        notification.set_default_action_and_target_value ("app.install-codecs", resources);
        Application.get_default ().send_notification ("install-resources", notification);
    }
}
