/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.ComponentStore : Object {
    private static ComponentStore? instance;
    public static ComponentStore get_default () {
        if (instance == null) {
            instance = new ComponentStore (FlatpakBackend.get_default ().components);
        }
        return instance;
    }

    public ListModel components { get; construct; }

    public ComponentStore (ListModel components) {
        Object (components: components);
    }

    public ListModel get_components_for_same_author (Package package) {
        return new Gtk.FilterListModel (components, new AuthorFilter (package));
    }
}
