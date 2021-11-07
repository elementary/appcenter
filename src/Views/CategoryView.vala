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

public class AppCenter.CategoryView : Gtk.ScrolledWindow {
    public AppStream.Category category { get; construct; }

    public CategoryView (AppStream.Category category) {
        Object (category: category);
    }

    construct {
        var paid_header = new Granite.HeaderLabel (_("Paid Apps")) {
            margin_start = 12
        };

        var paid_flowbox = new SubcategoryFlowbox ();

        var paid_grid = new Gtk.Grid ();
        paid_grid.attach (paid_header, 0, 0);
        paid_grid.attach (paid_flowbox, 0, 1);

        var free_header = new Granite.HeaderLabel (_("Free Apps")) {
            margin_start = 12
        };

        var free_flowbox = new SubcategoryFlowbox ();

        var free_grid = new Gtk.Grid ();
        free_grid.attach (free_header, 0, 0);
        free_grid.attach (free_flowbox, 0, 1);

        var uncurated_header = new Granite.HeaderLabel (_("Non-Curated Apps")) {
            margin_start = 12
        };

        var uncurated_flowbox = new SubcategoryFlowbox ();

        var uncurated_grid = new Gtk.Grid ();
        uncurated_grid.attach (uncurated_header, 0, 0);
        uncurated_grid.attach (uncurated_flowbox, 0, 1);

        unowned var client = AppCenterCore.Client.get_default ();
        foreach (var package in client.get_applications_for_category (category)) {
            // Don't show plugins or fonts in search and category views
            if (!package.is_plugin && !package.is_font) {
                var package_row = new AppCenter.Widgets.ListPackageRowGrid (package);

                if (package.is_native) {
                    if (package.get_payments_key () != null && package.get_suggested_amount () != "0") {
                        paid_flowbox.add (package_row);
                    } else {
                        free_flowbox.add (package_row);
                    }
                } else {
                    uncurated_flowbox.add (package_row);
                }

            }
        }

        var grid = new Gtk.Grid () {
            margin = 12,
            margin_top = 24,
            margin_bottom = 24
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 48
        };

        if (paid_flowbox.get_child_at_index (0) != null) {
            grid.add (paid_grid);
        }

        if (free_flowbox.get_child_at_index (0) != null) {
            grid.add (free_grid);
        }

        if (uncurated_flowbox.get_child_at_index (0) != null) {
            grid.add (uncurated_grid);
        }

        hscrollbar_policy = Gtk.PolicyType.NEVER;
        add (grid);

        show_all ();
    }

    private class SubcategoryFlowbox : Gtk.FlowBox {
        construct {
            column_spacing = 24;
            homogeneous = true;
            max_children_per_line = 5;
            min_children_per_line = 3;
            row_spacing = 12;
            valign = Gtk.Align.START;
        }
    }
}
