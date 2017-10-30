/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class AppCenter.Widgets.ReleaseListBox : Gtk.ListBox {
    private const int MIN_RELEASES = 1;
    private const int MAX_RELEASES = 5;

    public AppCenterCore.Package package { get; construct; }

    public ReleaseListBox (AppCenterCore.Package package) {
        Object (package: package, selection_mode: Gtk.SelectionMode.NONE);
    }

    public bool populate () {
        var releases = package.get_newest_releases (MIN_RELEASES, MAX_RELEASES);
        foreach (var release in releases) {
            var row = new ReleaseRow (release);
            add (row);
        }

        return releases.size > 0;
    }
}
