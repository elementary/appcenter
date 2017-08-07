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
        var releases = package.component.get_releases ();
        int length = releases.length;
        if (length < MIN_RELEASES) {
            return false;
        }

        releases.sort_with_data ((a, b) => {
            return b.vercmp (a);
        });

        string installed_version = package.get_version ();
        
        int start_index = 0;
        int end_index = MIN_RELEASES;

        if (package.installed) {
            for (int i = 0; i < length; i++) {
                unowned string release_version = releases.@get (i).get_version ();
                if (release_version == null) {
                    continue;
                }

                if (AppStream.utils_compare_versions (release_version, installed_version) == 0) {
                    end_index = i.clamp (MIN_RELEASES, MAX_RELEASES);
                    break;
                }
            }
        }

        for (int j = start_index; j < end_index; j++) {
            var release = releases.get (j);
            var row = new Widgets.ReleaseRow (release);
            add (row);
        }

        return true;
    }
}