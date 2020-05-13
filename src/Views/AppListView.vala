/*-
 * Copyright (c) 2014-2020 elementary, Inc. (https://elementary.io)
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
 */

namespace AppCenter.Views {
    /** AppList for Category and Search Views.  Sorts by name and does not show Uninstall Button **/
    public class AppListView : AbstractAppList {
        private uint current_visible_index = 0U;
        private GLib.ListStore list_store;

        construct {
            var alert_view = new Granite.Widgets.AlertView (
                _("No Results"),
                _("No apps could be found. Try changing search terms."),
                "edit-find-symbolic"
            );
            alert_view.show_all ();

#if CURATED
            list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) row_update_header);
#endif
            list_box.set_placeholder (alert_view);

            list_store = new GLib.ListStore (typeof (AppCenterCore.Package));
            scrolled.edge_reached.connect ((position) => {
                if (position == Gtk.PositionType.BOTTOM) {
                    show_more_apps ();
                }
            });

            add (scrolled);
        }

        public override void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
            foreach (var package in packages) {
                add_row_for_package (package);
            }

            if (current_visible_index < 20) {
                show_more_apps ();
            }
        }

        public override void add_package (AppCenterCore.Package package) {
            add_row_for_package (package);

            if (current_visible_index < 20) {
                show_more_apps ();
            }
        }

        private void add_row_for_package (AppCenterCore.Package package) {
            // Don't show plugins or fonts in search and category views
            if (!package.is_plugin && !package.is_font) {
                list_store.insert_sorted (package, (GLib.CompareDataFunc<AppCenterCore.Package>) compare_packages);
            }
        }

        public override void clear () {
            base.clear ();
            list_store.remove_all ();
            current_visible_index = 0U;
        }

        protected override Widgets.AppListRow construct_row_for_package (AppCenterCore.Package package) {
            return new Widgets.PackageRow.list (package, action_button_group);
        }

        // Show 20 more apps on the listbox
        private void show_more_apps () {
            uint old_index = current_visible_index;
            while (current_visible_index < list_store.get_n_items ()) {
                var package = (AppCenterCore.Package?) list_store.get_object (current_visible_index);
                var row = construct_row_for_package (package);
                add_row (row);
                current_visible_index++;
                if (old_index + 20 < current_visible_index) {
                    break;
                }
            }

            on_list_changed ();
        }

        private static int compare_packages (AppCenterCore.Package p1, AppCenterCore.Package p2) {
#if CURATED
            bool p1_is_elementary_native = p1.is_native;

            if (p1_is_elementary_native != p2.is_native) {
                return p1_is_elementary_native ? -1 : 1;
            }
#endif

            if (p1.is_plugin != p2.is_plugin) {
                return p1.is_plugin ? 1 : -1;
            }

            return p1.get_name ().collate (p2.get_name ());
        }

#if CURATED
        [CCode (instance_pos = -1)]
        protected override int package_row_compare (Widgets.AppListRow row1, Widgets.AppListRow row2) {
            bool p1_is_elementary_native = row1.get_package ().is_native;
            bool p1_is_plugin = row1.get_package ().is_plugin;

            if (p1_is_elementary_native != row2.get_package ().is_native) {
                return p1_is_elementary_native ? -1 : 1;
            }

            if (p1_is_plugin != row2.get_package ().is_plugin) {
                return p1_is_plugin ? 1 : -1;
            }

            return base.package_row_compare (row1, row2);
        }

        [CCode (instance_pos = -1)]
        private void row_update_header (Widgets.AppListRow row, Widgets.AppListRow? before) {
            bool elementary_native = row.get_package ().is_native;

            if (!elementary_native) {
                if (before == null || (before != null && before.get_package ().is_native)) {
                    mark_row_non_curated (row);
                }
            }
        }

        private void mark_row_non_curated (Widgets.AppListRow row) {
            var header = new Gtk.Label (_("Non-Curated Apps"));
            header.margin = 12;
            header.margin_top = 18;
            header.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            header.hexpand = true;
            header.xalign = 0;
            row.set_header (header);
        }
#endif
    }
}
