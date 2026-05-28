/*
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.Component : Object, ListModel {
    public string component_id { get; construct; }

    private Gee.List<Package> packages = new Gee.ArrayList<Package> ();

    public Component (string component_id) {
        Object (component_id: component_id);
    }

    public void add_package (Package package) {
        if (package in packages) {
            return;
        }

        packages.add (package);
        items_changed (packages.size - 1, 0, 1);
    }

    public void remove_package (Package package) {
        if (!(package in packages)) {
            return;
        }

        var index = packages.index_of (package);

        packages.remove_at (index);

        items_changed ((uint) index, 1, 0);
    }

    public Type get_item_type () {
        return typeof (Package);
    }

    public uint get_n_items () {
        return (uint) packages.size;
    }

    public Object? get_item (uint position) {
        return packages.get ((int) position);
    }
}
