/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.UpdateInformation : Object {
    public Gee.ArrayList<string> updatable_packages { get; private set; }
    public uint64 size { get; set; }

    construct {
        updatable_packages = new Gee.ArrayList<string> ();
        size = 0;
    }
}
