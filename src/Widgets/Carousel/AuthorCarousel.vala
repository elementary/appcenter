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

public class AppCenter.Widgets.AuthorCarousel : Carousel {
    private const int AUTHOR_OTHER_APPS_MAX = 10;

    public AppCenterCore.Package target { get; construct; }

    construct {
        hexpand = true;
        var author_packages = AppCenterCore.Client.get_default ().get_packages_by_author (target.author, AUTHOR_OTHER_APPS_MAX);
        foreach (var author_package in author_packages) {
            if (author_package.component.get_id () == target.component.get_id ()) {
                continue;
            }

            add_package (author_package);
        }
    }

    public AuthorCarousel (AppCenterCore.Package target) {
        Object (target: target);
    }
}
