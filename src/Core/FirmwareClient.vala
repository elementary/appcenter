
  
/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
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
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

/*
* This class only exists to provide async methods that aren't present in older
* versions of LibFwupd. It should be removed when LibFwupd is updated.
*/

public class AppCenterCore.FirmwareClient {
    public static async GLib.GenericArray<weak Fwupd.Device> get_devices (Fwupd.Client client) throws GLib.Error {
        SourceFunc callback = get_devices.callback;
        GLib.Error error = null;

        var devices = new GLib.GenericArray<weak Fwupd.Device> ();
        new Thread<void> ("get_devices", () => {
            try {
                devices = client.get_devices ();
            } catch (Error e) {
                error = e;
            }
            Idle.add ((owned) callback);
        });

        yield;

        if (error != null) {
            throw error;
        }

        return devices;
    }

    public static async GLib.GenericArray<weak Fwupd.Release> get_upgrades (Fwupd.Client client, string device_id) throws GLib.Error {
        SourceFunc callback = get_upgrades.callback;
        GLib.Error error = null;

        var releases = new GLib.GenericArray<weak Fwupd.Release> ();
        new Thread<void> ("get_upgrades", () => {
            try {
                releases = client.get_upgrades (device_id);
            } catch (Error e) {
                error = e;
            }
            Idle.add ((owned) callback);
        });

        yield;

        if (error != null) {
            throw error;
        }

        return releases;
    }
}
