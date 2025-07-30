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

public class AppCenter.CategoryView : Adw.NavigationPage {
    public signal void show_app (AppCenterCore.Package package);

    public AppStream.Category category { get; construct; }

    private Gtk.Stack stack;
    private Gtk.ScrolledWindow scrolled;
    private Gtk.Box box;
    private SubcategoryFlowbox free_flowbox;
    private SubcategoryFlowbox paid_flowbox;
    private SubcategoryFlowbox recently_updated_flowbox;

    public CategoryView (AppStream.Category category) {
        Object (category: category);
    }

    construct {
        recently_updated_flowbox = new SubcategoryFlowbox (_("Recently Updated"));

        paid_flowbox = new SubcategoryFlowbox (_("Paid Apps"));

        free_flowbox = new SubcategoryFlowbox (_("Free Apps"));

        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 48) {
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 24,
            margin_start = 12
        };

        scrolled = new Gtk.ScrolledWindow () {
            child = box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        var spinner = new Gtk.Spinner () {
            halign = Gtk.Align.CENTER,
            hexpand = true
        };
        spinner.start ();

        stack = new Gtk.Stack ();
        stack.add_child (spinner);
        stack.add_child (scrolled);

        var title_label = new Gtk.Label (category.name);
        title_label.add_css_class (Granite.STYLE_CLASS_TITLE_LABEL);

        var search_button = new Gtk.Button.from_icon_name ("edit-find") {
            action_name = "win.search",
            /// TRANSLATORS: the action of searching
            tooltip_text = C_("action", "Search")
        };
        search_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var headerbar = new Gtk.HeaderBar () {
            title_widget = title_label
        };
        headerbar.pack_start (new BackButton ());
        headerbar.pack_end (search_button);

        var toolbar_view = new Adw.ToolbarView () {
            content = stack
        };
        toolbar_view.add_top_bar (headerbar);

        child = toolbar_view;
        title = category.name;

        populate ();

        recently_updated_flowbox.show_package.connect ((package) => {
            show_app (package);
        });

        paid_flowbox.show_package.connect ((package) => {
            show_app (package);
        });

        free_flowbox.show_package.connect ((package) => {
            show_app (package);
        });

        AppCenterCore.FlatpakBackend.get_default ().package_list_changed.connect (() => {
            populate ();
        });
    }

    private void populate () {
        get_packages.begin ((obj, res) => {
            while (box.get_first_child () != null) {
                box.remove (box.get_first_child ());
            };

            var paid_model = new GLib.ListStore (typeof (AppCenterCore.Package));
            var free_model = new GLib.ListStore (typeof (AppCenterCore.Package));

            var packages = get_packages.end (res);
            foreach (var package in packages) {
                if (package.is_native && package.get_payments_key () != null && package.get_suggested_amount () != "0") {
                    paid_model.insert_sorted (package, package_compare_func);
                } else {
                    free_model.insert_sorted (package, package_compare_func);
                }
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

            var recent_model = new GLib.ListStore (typeof (AppCenterCore.Package));
            var datetime = new GLib.DateTime.now_local ().add_months (-6);
            var recent_count = 0;
            foreach (var recent_package in recent_packages_list) {
                if (recent_count == 4) {
                    break;
                }

                var newest_release = recent_package.get_newest_release ();
                if (newest_release == null) {
                    continue;
                }

                // Don't add packages over 6 months old
                if (newest_release.get_timestamp () < datetime.to_unix ()) {
                    continue;
                }

                if (!recent_package.installed) {
                    recent_model.append (recent_package);
                    recent_count++;
                }
            }

            if (recent_model.n_items > 0) {
                recently_updated_flowbox.bind_model (recent_model);
                box.append (recently_updated_flowbox);
            }

            if (paid_model.n_items > 0) {
                paid_flowbox.bind_model (paid_model);
                box.append (paid_flowbox);
            }

            if (free_model.n_items > 0) {
                box.append (free_flowbox);
                free_flowbox.bind_model (free_model);
            }

            stack.visible_child = scrolled;
        });
    }

    private async Gee.Collection<AppCenterCore.Package> get_packages () {
        SourceFunc callback = get_packages.callback;

        var packages = new Gee.TreeSet <AppCenterCore.Package> ();
        new Thread<void> ("get_packages", () => {
            foreach (var package in AppCenterCore.FlatpakBackend.get_default ().get_applications_for_category (category)) {
                if (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT) {
                    packages.add (package);
                }
            }

            Idle.add ((owned) callback);
        });

        yield;
        return packages;
    }

    private int package_compare_func (Object object1, Object object2) {
        var package1 = (AppCenterCore.Package) object1;
        var package2 = (AppCenterCore.Package) object2;

#if CURATED
        if (package1.is_native && !package2.is_native) {
            return -1;
        } else if (!package1.is_native && package2.is_native) {
            return 1;
        }
#endif
        return package1.get_name ().collate (package2.get_name ());
    }

    private class SubcategoryFlowbox : Gtk.Box {
        public signal void show_package (AppCenterCore.Package package);

        public string? label { get; construct; }

        private static Gtk.SizeGroup size_group;
        private Gtk.FlowBox flowbox;

        static construct {
            size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        }

        public SubcategoryFlowbox (string? label = null) {
            Object (label: label);
        }

        construct {
            flowbox = new Gtk.FlowBox () {
                column_spacing = 24,
                homogeneous = true,
                max_children_per_line = 4,
                row_spacing = 12,
                valign = Gtk.Align.START
            };

            orientation = Gtk.Orientation.VERTICAL;

            if (label != null) {
                var header = new Granite.HeaderLabel (label) {
                    margin_start = 12
                };
                header.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
                append (header);
            }
            append (flowbox);

            flowbox.child_activated.connect ((child) => {
                var row = (Widgets.ListPackageRowGrid) child.get_child ();
                show_package (row.package);
            });
        }

        public void bind_model (GLib.ListModel model) {
            flowbox.bind_model (model, create_widget_func);
        }

        private Gtk.Widget create_widget_func (Object object) {
            unowned var package = (AppCenterCore.Package) object;
            var package_row = new Widgets.ListPackageRowGrid (package);
            size_group.add_widget (package_row);
            return package_row;
        }
    }
}
