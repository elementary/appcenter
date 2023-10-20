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

public interface AppCenterCore.HttpClient : Object {
    public class Response : GLib.Object {
        public string? body { get; set; }
        public GLib.HashTable<string, string>? headers { get; set; }
        public uint status_code { get; set; }
    }

    /*
     * Perform a HTTP POST request
     *
     * @param url The URL to post to
     * @param data The data to post
     * @param headers The headers to send
     * @return The response body
     * @throws IOError
    */
    public abstract async Response post (string url, string data, GLib.HashTable<string, string>? headers = null) throws Error;
}
