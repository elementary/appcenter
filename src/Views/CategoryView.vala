/*-
 * Copyright 2021 elementary, Inc. (https://elementary.io)
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
 */

public class AppCenter.CategoryView : Gtk.Stack {
    public signal void show_app (AppCenterCore.Package package);

    public AppStream.Category category { get; construct; }

    private Gtk.Box box;
    private Gtk.Box free_box;
    private Gtk.Box paid_box;
    private Gtk.Box recently_updated_box;
    private Gtk.Box uncurated_box;
    private Gtk.ScrolledWindow scrolled;
    private SubcategoryFlowbox free_flowbox;
    private SubcategoryFlowbox paid_flowbox;
    private SubcategoryFlowbox recently_updated_flowbox;
    private SubcategoryFlowbox uncurated_flowbox;

    public CategoryView (AppStream.Category category) {
        Object (category: category);
    }

    construct {
        var recently_updated_header = new Granite.HeaderLabel (_("Recently Updated")) {
            margin_start = 12
        };
        recently_updated_header.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        recently_updated_flowbox = new SubcategoryFlowbox ();

        recently_updated_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        recently_updated_box.add (recently_updated_header);
        recently_updated_box.add (recently_updated_flowbox);

        var paid_header = new Granite.HeaderLabel (_("Paid Apps")) {
            margin_start = 12
        };
        paid_header.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        paid_flowbox = new SubcategoryFlowbox ();

        paid_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        paid_box.add (paid_header);
        paid_box.add (paid_flowbox);

        var free_header = new Granite.HeaderLabel (_("Free Apps")) {
            margin_start = 12
        };
        free_header.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        free_flowbox = new SubcategoryFlowbox ();

        free_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        free_box.add (free_header);
        free_box.add (free_flowbox);

        var uncurated_header = new Granite.HeaderLabel (_("Non-Curated Apps")) {
            margin_start = 12
        };
        uncurated_header.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        uncurated_flowbox = new SubcategoryFlowbox ();

#if CURATED
        uncurated_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        uncurated_box.add (uncurated_header);
        uncurated_box.add (uncurated_flowbox);
#endif

        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 48) {
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 24,
            margin_start = 12
        };

        scrolled = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        scrolled.add (box);

        var spinner = new Gtk.Spinner () {
            halign = Gtk.Align.CENTER
        };
        spinner.start ();

        add (spinner);
        add (scrolled);
        show_all ();

        populate ();

        recently_updated_flowbox.child_activated.connect ((child) => {
            var row = (Widgets.ListPackageRowGrid) child.get_child ();
            show_app (row.package);
        });

        paid_flowbox.child_activated.connect ((child) => {
            var row = (Widgets.ListPackageRowGrid) child.get_child ();
            show_app (row.package);
        });

        free_flowbox.child_activated.connect ((child) => {
            var row = (Widgets.ListPackageRowGrid) child.get_child ();
            show_app (row.package);
        });

        uncurated_flowbox.child_activated.connect ((child) => {
            var row = (Widgets.ListPackageRowGrid) child.get_child ();
            show_app (row.package);
        });

        AppCenterCore.Client.get_default ().installed_apps_changed.connect (() => {
            populate ();
        });
    }

    private void populate () {
        get_packages.begin ((obj, res) => {
            foreach (unowned var child in box.get_children ()) {
                box.remove (child);
            }

            foreach (unowned var child in recently_updated_flowbox.get_children ()) {
                child.destroy ();
            }

            foreach (unowned var child in free_flowbox.get_children ()) {
                child.destroy ();
            }

            foreach (unowned var child in paid_flowbox.get_children ()) {
                child.destroy ();
            }

            foreach (unowned var child in uncurated_flowbox.get_children ()) {
                child.destroy ();
            }

            var packages = get_packages.end (res);
            foreach (var package in packages) {
                var package_row = new AppCenter.Widgets.ListPackageRowGrid (package);
#if CURATED
                if (package.is_native) {
                    if (package.get_payments_key () != null && package.get_suggested_amount () != "0") {
                        paid_flowbox.add (package_row);
                    } else {
                        free_flowbox.add (package_row);
                    }
                } else {
                    uncurated_flowbox.add (package_row);
                }
#else
                uncurated_flowbox.add (package_row);
#endif
            }

            var recent_packages_list = new Gee.ArrayList<AppCenterCore.Package> ();
            recent_packages_list.add_all (packages);
            recent_packages_list.sort ((a, b) => {
                if (a.get_newest_release () == null || b.get_newest_release () == null) {
                    if (a.get_newest_release () != null) {
                        return -1;
                    } else if (b.get_newest_release () != null) {
                        return 1;
                    } else {
                        return 0;
                    }
                }

                return b.get_newest_release ().vercmp (a.get_newest_release ());
            });

            var datetime = new GLib.DateTime.now_local ().add_months (-6);
            var recent_count = 0;
            foreach (var recent_package in recent_packages_list) {
                if (recent_count == 4) {
                    break;
                }

                // Don't add packages over 6 months old
                if (recent_package.get_newest_release ().get_timestamp () < datetime.to_unix ()) {
                    continue;
                }

                if (!recent_package.installed) {
                    var package_row = new AppCenter.Widgets.ListPackageRowGrid (recent_package);
                    recently_updated_flowbox.add (package_row);
                    recent_count++;
                }
            }

#if CURATED
            if (recently_updated_flowbox.get_child_at_index (0) != null) {
                box.add (recently_updated_box);
            }

            if (paid_flowbox.get_child_at_index (0) != null) {
                box.add (paid_box);
            }

            if (free_flowbox.get_child_at_index (0) != null) {
                box.add (free_box);
            }

            if (uncurated_flowbox.get_child_at_index (0) != null) {
                box.add (uncurated_box);
            }
#else
            box.add (uncurated_flowbox);
#endif

            show_all ();
            visible_child = scrolled;
        });
    }

    private async Gee.Collection<AppCenterCore.Package> get_packages () {
        SourceFunc callback = get_packages.callback;

        var packages = new Gee.TreeSet <AppCenterCore.Package> ();
        new Thread<void> ("get_packages", () => {
            foreach (var package in AppCenterCore.Client.get_default ().get_applications_for_category (category)) {
                if (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT) {
                    packages.add (package);
                }
            }

            Idle.add ((owned) callback);
        });

        yield;
        return packages;
    }

    private class SubcategoryFlowbox : Gtk.FlowBox {
        private static Gtk.SizeGroup size_group;

        static construct {
            size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        }

        construct {
            column_spacing = 24;
            homogeneous = true;
            max_children_per_line = 4;
            row_spacing = 12;
            valign = Gtk.Align.START;

            set_sort_func ((Gtk.FlowBoxSortFunc) package_row_compare);

            add.connect ((widget) => {
                size_group.add_widget (widget);
            });
        }

        [CCode (instance_pos = -1)]
        protected virtual int package_row_compare (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var row1 = (Widgets.ListPackageRowGrid) child1.get_child ();
            var row2 = (Widgets.ListPackageRowGrid) child2.get_child ();

            return row1.package.get_name ().collate (row2.package.get_name ());
        }
    }
}
