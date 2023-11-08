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

 public class MockHttpClient : Object, AppCenterCore.HttpClient {
    private string response;
    private int response_code;
    private bool throws_error;

    public string? request_uri { get; private set; }
    public string? data { get; private set; }
    public GLib.HashTable<string, string>? headers { get; private set; }

    /*
     * Create a new MockHttpClient.
     *
     * @param response The response to return when request methods are called.
     * @param throws_error If true, the request methods will throw an IOError.
     * @param response_code The response code to return when request methods are called.
     */
    public MockHttpClient (string response = "", bool throws_error = false, int response_code = 200) {
        this.response = response;
        this.throws_error = throws_error;
        this.response_code = response_code;
    }

    /*
     * Perform a mock POST request and return the response.
     *
     * The url, data and headers will be stored as properties so they can be
     * inspected after the request is made.
     *
     * @param url The URL to request.
     * @param data The data to send in the request body.
     * @param headers The headers to send with the request.
     * @return The response.
     * @throws IOError If throws_error is true.
     */
    public async AppCenterCore.HttpClient.Response post (string url, string data, GLib.HashTable<string, string>? headers = null) throws IOError {
        if (this.throws_error) {
            throw new IOError.HOST_UNREACHABLE ("Network is unreachable");
        }

        this.request_uri = url;
        this.data = data;
        this.headers = headers;

        return new AppCenterCore.HttpClient.Response () {
            status_code = this.response_code,
            body = this.response
        };
    }

    public void reset () {
        this.request_uri = null;
        this.data = null;
        this.headers = null;
    }
}
