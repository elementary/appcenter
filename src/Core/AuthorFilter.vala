/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.AuthorFilter : Gtk.Filter {
    public Package package { get; construct; }

    public AuthorFilter (Package package) {
        Object (package: package);
    }

    public override bool match (Object? obj) {
        if (!(obj is Component)) {
            return false;
        }

        var component = (Component) obj;

        if (component.component_id == package.normalized_component_id) {
            return false;
        }

        var other_package = component.get_package_from_same_origin (package);

        if (other_package == null) {
            return false;
        }

        if (package.author_id != null && package.author_id != other_package.author_id ||
            package.author != null && package.author == other_package.author
        ) {
            return true;
        }

        return false;
    }
}
