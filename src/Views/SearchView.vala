/*-
* Copyright 2014-2023 elementary, Inc. (https://elementary.io)
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
* Authored by: Corentin Noël <corentin@elementary.io>
*              Jeremy Wootten <jeremy@elementaryos.org>
*              Atheesh Thirumalairajan <candiedoperation@icloud.com>
*/

public class AppCenter.SearchView : Gtk.Box {
    public signal void show_app (AppCenterCore.Package package);

    public string? current_search_term { get; set; default = null; }

    private GLib.ListStore list_store;

    construct {
        var flathub_link = "<a href='https://flathub.org'>%s</a>".printf (_("Flathub"));
        var alert_view = new Granite.Widgets.AlertView (
            _("No Apps Found"),
            _("Try changing search terms. You can also sideload Flatpak apps e.g. from %s").printf (flathub_link),
            "edit-find-symbolic"
        );
        alert_view.show_all ();

        list_store = new GLib.ListStore (typeof (AppCenterCore.Package));

        var list_box = new Gtk.ListBox () {
            activate_on_single_click = true,
            hexpand = true,
            vexpand = true
        };
        list_box.bind_model (list_store, create_row_from_package);
        list_box.set_placeholder (alert_view);

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            child = list_box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        add (scrolled);

        list_store.items_changed.connect (() => {
            list_box.show_all ();
        });

        notify["current-search-term"].connect (() => {
            if (current_search_term == null) {
                return;
            }

            if (current_search_term.length < MainWindow.VALID_QUERY_LENGTH) {
                alert_view.description = _("The search term must be at least 3 characters long.");
            } else {
                var dyn_flathub_link = "<a href='https://flathub.org/apps/search/%s'>%s</a>".printf (current_search_term, _("Flathub"));
                alert_view.description = _("Try changing search terms. You can also sideload Flatpak apps e.g. from %s").printf (dyn_flathub_link);
            }
        });

        list_box.row_activated.connect ((row) => {
            if (row is Widgets.PackageRow) {
                show_app (((Widgets.PackageRow) row).get_package ());
            }
        });
    }

    public void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
        foreach (var package in packages) {
            // Don't show plugins or fonts in search and category views
            if (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT) {
                GLib.CompareDataFunc<AppCenterCore.Package> sort_fn = (a, b) => {
                    return compare_packages (a, b);
                };

                list_store.insert_sorted (package, sort_fn);
            }
        }
    }

    private Gtk.Widget create_row_from_package (Object object) {
        unowned var package = (AppCenterCore.Package) object;
        return new Widgets.PackageRow.list (package);
    }

    public void clear () {
        list_store.remove_all ();
        current_search_term = null;
    }

    private int search_priority (string name) {
        if (name != null && current_search_term != null) {
            var name_lower = name.down ();
            var term_lower = current_search_term.down ();

            var term_position = name_lower.index_of (term_lower);

            // App name starts with our search term, highest priority
            if (term_position == 0) {
                return 2;
            // App name contains our search term, high priority
            } else if (term_position != -1) {
                return 1;
            }
        }

        // Otherwise, normal appstream search ranking order
        return 0;
    }

    private int compare_packages (AppCenterCore.Package p1, AppCenterCore.Package p2) {
        if ((p1.kind == AppStream.ComponentKind.ADDON) != (p2.kind == AppStream.ComponentKind.ADDON)) {
            return p1.kind == AppStream.ComponentKind.ADDON ? 1 : -1;
        }

        int sp1 = search_priority (p1.get_name ());
        int sp2 = search_priority (p2.get_name ());
        if (sp1 != sp2) {
            return sp2 - sp1;
        }

        return p1.get_name ().collate (p2.get_name ());
    }
}
