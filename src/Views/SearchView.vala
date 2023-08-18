/*-
* Copyright 2014-2022 elementary, Inc. (https://elementary.io)
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

    private Gtk.ListBox list_box;
    private uint current_visible_index = 0U;
    private GLib.ListStore list_store;

    construct {
        var flathub_link = "<a href='https://flathub.org'>%s</a>".printf (_("Flathub"));
        var alert_view = new Granite.Placeholder (_("No Apps Found")) {
            description = _("Try changing search terms. You can also sideload Flatpak apps e.g. from %s").printf (flathub_link),
            icon = new ThemedIcon ("edit-find-symbolic")
        };

        list_store = new GLib.ListStore (typeof (AppCenterCore.Package));

        list_box = new Gtk.ListBox () {
            activate_on_single_click = true,
            hexpand = true,
            vexpand = true
        };
        list_box.set_placeholder (alert_view);
        list_box.set_sort_func ((Gtk.ListBoxSortFunc) package_row_compare);

        var scrolled = new Gtk.ScrolledWindow () {
            child = list_box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        append (scrolled);

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

        scrolled.edge_reached.connect ((position) => {
            if (position == Gtk.PositionType.BOTTOM) {
                show_more_apps ();
            }
        });
    }

    public void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
        foreach (var package in packages) {
            add_row_for_package (package);
        }

        if (current_visible_index < 20) {
            show_more_apps ();
        }
    }

    private void add_row_for_package (AppCenterCore.Package package) {
        // Don't show plugins or fonts in search and category views
        if (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT) {
            GLib.CompareDataFunc<AppCenterCore.Package> sort_fn = (a, b) => {
                return compare_packages (a, b);
            };

            list_store.insert_sorted (package, sort_fn);
        }
    }

    public void clear () {
        while (list_box.get_first_child () != null) {
            list_box.remove (list_box.get_first_child ());
        }

        list_store.remove_all ();
        list_box.invalidate_sort ();

        current_search_term = null;
        current_visible_index = 0U;
    }

    // Show 20 more apps on the listbox
    private void show_more_apps () {
        uint old_index = current_visible_index;
        while (current_visible_index < list_store.get_n_items ()) {
            var package = (AppCenterCore.Package?) list_store.get_object (current_visible_index);

            var row = new Widgets.PackageRow.list (package);
            list_box.append (row);

            current_visible_index++;
            if (old_index + 20 < current_visible_index) {
                break;
            }
        }

        list_box.invalidate_sort ();
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

    [CCode (instance_pos = -1)]
    private int package_row_compare (Widgets.PackageRow row1, Widgets.PackageRow row2) {
        return compare_packages (row1.get_package (), row2.get_package ());
    }
}
