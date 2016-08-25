// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
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
 */

using AppCenterCore;

public class AppCenter.Views.AppListView : Gtk.ScrolledWindow {
    public signal void show_app (AppCenterCore.Package package);

    private bool _updating_cache = true;
    public bool updating_cache {
        get {
            return _updating_cache;
        }
        set {
            if (!updates_on_top) {
                warning ("updating_cache is useless if updates_on_top is false");
            }

            _updating_cache = value;
            list_box.invalidate_headers ();
        }
    }

    private bool updates_on_top;
    private Gtk.ListBox list_box;
    private Gtk.SizeGroup update_button_group;
    private Gtk.Button update_all_button;
    private bool updating_all_apps;
    private SuspendControl sc;

    public AppListView (bool updates_on_top = false) {
        this.updates_on_top = updates_on_top;
        if (updates_on_top) {
            list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) package_row_update_header);
        }
    }

    construct {
        hscrollbar_policy = Gtk.PolicyType.NEVER;
        var alert_view = new Granite.Widgets.AlertView (_("No Results"), _("No apps could be found. Try changing search terms."), "edit-find-symbolic");
        alert_view.show_all ();
        list_box = new Gtk.ListBox ();
        list_box.expand = true;
        list_box.activate_on_single_click = true;
        list_box.set_placeholder (alert_view);
        list_box.set_sort_func ((Gtk.ListBoxSortFunc) package_row_compare);
        list_box.row_activated.connect ((row) => {
            var packagerow = row as Widgets.PackageRow;
            if (packagerow != null) {
                show_app (packagerow.get_package ());
            }
        });
        add (list_box);

        sc = new SuspendControl ();
        update_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        updating_all_apps = false;
    }

    public void add_package (AppCenterCore.Package package) {
        var row = new Widgets.PackageRow (package, update_button_group, !updates_on_top);
        row.show_all ();
        list_box.add (row);
    }

    public void remove_package (AppCenterCore.Package package) {
        var pkg_rows = list_box.get_children ();
        foreach (var row in pkg_rows) {
            if (((Widgets.PackageRow) row).get_package () == package) {
                row.destroy ();
                break;
            }
        }
    }

    public Gee.Collection<AppCenterCore.Package> get_packages () {
        var tree_set = new Gee.TreeSet<AppCenterCore.Package> ();
        list_box.get_children ().foreach ((child) => {
            tree_set.add (((Widgets.PackageRow) child).get_package ());
        });

        return tree_set;
    }

    public void clear () {
        list_box.get_children ().foreach ((child) => {
            child.destroy ();
        });
    }

    [CCode (instance_pos = -1)]
    private int package_row_compare (Widgets.PackageRow row1, Widgets.PackageRow row2) {
        /* "update_available" also true while package is updating */
        bool a_update = row1.get_update_available ();
        bool b_update = row2.get_update_available ();

        bool a_is_os = row1.get_is_os_updates ();
        bool b_is_os = row2.get_is_os_updates ();

        if (updates_on_top) {
            if (a_is_os) {
                return -1;
            } else if (b_is_os) {
                return 1;
            }

            if (a_update && !b_update) {
                return -1;
            } else if (!a_update && b_update) {
                return 1;
            }
        }

        return row1.get_name_label ().collate (row2.get_name_label ());
    }

    [CCode (instance_pos = -1)]
    private void package_row_update_header (Widgets.PackageRow row, Widgets.PackageRow? before) {
        if (!row.get_is_updating () && (before == null || !before.get_is_updating ())) {
            bool update_available = row.get_update_available ();
            if (before == null && update_available) {
                var updates_grid = get_updates_grid ();
                row.set_header (updates_grid);
            } else if ((before == null && !update_available) || update_available != before.get_update_available ()) {
                var updated_grid = get_updated_grid ();
                row.set_header (updated_grid);
            } else {
                row.set_header (null);
            }
        }
    }

    private Gtk.Grid get_updated_grid () {
        var updated_grid = new Gtk.Grid ();
        updated_grid.orientation = Gtk.Orientation.HORIZONTAL;
        updated_grid.column_spacing = 12;
        if (updating_cache) {
            updated_grid.halign = Gtk.Align.CENTER;
            var updating_label = new Gtk.Label (_("Searching for updates…"));
            var spinner = new Gtk.Spinner ();
            spinner.start ();
            updated_grid.add (spinner);
            updated_grid.add (updating_label);
        } else {
            var updated_label = new Gtk.Label (_("Up to Date"));
            updated_label.hexpand = true;
            ((Gtk.Misc) updated_label).xalign = 0;
            updated_label.get_style_context ().add_class ("h4");
            updated_grid.add (updated_label);
        }

        updated_grid.show_all ();
        return updated_grid;
    }

    private Gtk.Grid get_updates_grid () {
        var applications = get_packages ();
        uint update_numbers = 0U;
        uint64 update_real_size = 0ULL;
        foreach (var package in applications) {
            if (package.update_available) {
                update_numbers++;
                update_real_size += package.change_information.get_size ();
            }
        }
        var updates_label = new Gtk.Label (null);
        updates_label.label = ngettext ("%u Update Available", "%u Updates Available", update_numbers).printf (update_numbers);
        ((Gtk.Misc) updates_label).xalign = 0;
        updates_label.get_style_context ().add_class ("h4");
        updates_label.hexpand = true;

        var update_size = new Gtk.Label (null);
        update_size.label = _("Size: %s").printf (GLib.format_size (update_real_size));

        update_all_button = new Gtk.Button.with_label (_("Update All"));
        update_all_button.margin_end = 6;
        update_all_button.valign = Gtk.Align.CENTER;
        update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        update_all_button.clicked.connect (() => update_all_clicked.begin ());

        update_button_group.add_widget (update_all_button);

        uint current_update_number = update_numbers;
        list_box.get_children ().foreach ((child) => {
            var package = ((Widgets.PackageRow) child).get_package ();
            if (package != null && package.update_available) {
                package.notify["changing"].connect (() => {
                    if (package.changing) {
                        current_update_number--;
                    } else {
                        if (package.update_available) {
                            current_update_number++;
                        }
                    }

                    if (!updating_all_apps) {
                        update_all_button.sensitive = current_update_number != 0;
                    }
                });
            }
        });

        var updates_grid = new Gtk.Grid ();
        updates_grid.margin = 6;
        updates_grid.orientation = Gtk.Orientation.HORIZONTAL;
        updates_grid.column_spacing = 12;
        updates_grid.add (updates_label);
        updates_grid.add (update_size);
        updates_grid.add (update_all_button);
        updates_grid.show_all ();
        return updates_grid;
    }

    private async void update_all_clicked () {
        var applications = get_packages ();
        var apps_to_update = new Gee.LinkedList<AppCenterCore.Package> ();
        var apps_done = 0; // Cancelled or updated apps
        var apps_remaining_started = false;
        ulong signal_id = -1;

        // Collect all ready to update apps
        foreach (var package in applications) {
            if (package.update_available) {
                apps_to_update.add (package);
            }
        }

        // Update all updateable apps
        if (apps_to_update.size > 0) {
            // Prevent computer from sleeping while updating apps
            sc.inhibit ();

            updating_all_apps = true;
            Idle.add (() => {
                update_all_button.sensitive = false;
                return GLib.Source.REMOVE;
            });

            var first_package = apps_to_update[0];
            first_package.update.begin ();
            signal_id = first_package.change_information.status_changed.connect (() => {
                if (first_package.change_information.status == Pk.Status.RUNNING && !apps_remaining_started) {
                    // Update remaining apps. User has already granted superuser permissions
                    for (int i = 1; i < apps_to_update.size; i++) {
                        apps_to_update[i].update.begin (() => {
                            apps_done++;

                            if (apps_done >= apps_to_update.size) {
                                finish_updating_all_apps (first_package, signal_id);
                            }
                        });
                    }

                    apps_remaining_started = true;
                } else if (first_package.change_information.status == Pk.Status.FINISHED) {
                    // First app was updated or cancelled
                    apps_done++;

                    if (apps_done >= apps_to_update.size) {
                        finish_updating_all_apps (first_package, signal_id);
                    }
                }
            });
        }
    }

    private void finish_updating_all_apps (AppCenterCore.Package first_package, ulong signal_id) {
        updating_all_apps = false;
        Idle.add (() => {
            update_all_button.sensitive = true;
            return GLib.Source.REMOVE;
        });

        sc.uninhibit ();

        if (signal_id != -1) {
            first_package.change_information.disconnect (signal_id);
        }
    }
}
