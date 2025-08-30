/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class AppCenterCore.AddonFilter : Gtk.Filter {
    public FlatpakPackage package { get; construct; }

    public AddonFilter (FlatpakPackage package) {
        Object (package: package);
    }

    public override bool match (Object? obj) {
        if (!(obj is FlatpakPackage)) {
            return false;
        }

        var flatpak_package = (FlatpakPackage) obj;
        if (flatpak_package.installation != package.installation) {
            return false;
        }

        if (flatpak_package.component.get_origin () != package.component.get_origin ()) {
            return false;
        }

        foreach (var extends in flatpak_package.component.get_extends ()) {
            if (extends == package.component.id) {
                return true;
            }
        }

        return false;
    }
}
