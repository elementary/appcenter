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

public class AppCenter.Views.InstalledView : View {
    Gtk.Grid main_grid;
    AppListView app_list_view;

    Gtk.Grid updating_grid;
    Gtk.Grid updates_grid;

    Gtk.Label update_label;
    Gtk.Label update_size;
    Gtk.Button update_all_button;

    Gtk.ProgressBar progress_bar;
    Gtk.Label progress_label;

    Gtk.Stack top_stack;
    Gtk.Stack top_right_stack;

    Gee.TreeSet<Package> updates;
    public InstalledView () {
        // We need this line in order to show the No Update view.
        Client.get_default ().updates_available.connect (() => {
            var package = Client.get_default ().os_updates;
            if (package.update_available) {
                app_list_view.add_package (package);
            }

            show_update_number ();
        });
        get_apps.begin ();
    }

    construct {
        updates = new Gee.TreeSet<Package> ();

        main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;

        app_list_view = new AppListView (true);

        top_stack = new Gtk.Stack ();
        top_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        updating_grid = new Gtk.Grid ();
        updating_grid.orientation = Gtk.Orientation.HORIZONTAL;
        updating_grid.margin = 12;
        updating_grid.column_spacing = 12;
        updating_grid.halign = Gtk.Align.CENTER;
        updating_grid.valign = Gtk.Align.CENTER;
        var updating_spinner = new Gtk.Spinner ();
        updating_spinner.start ();
        var updating_label = new Gtk.Label (_("Searching for updates…"));
        updating_label.get_style_context ().add_class ("h2");
        ((Gtk.Misc) updating_label).xalign = 0;
        updating_grid.add (updating_spinner);
        updating_grid.add (updating_label);

        update_label = new Gtk.Label (null);
        update_label.get_style_context ().add_class ("h2");
        update_label.hexpand = true;
        ((Gtk.Misc) update_label).xalign = 0;

        update_size = new Gtk.Label (null);

        update_all_button = new Gtk.Button.with_label (_("Update All"));
        update_all_button.valign = Gtk.Align.CENTER;
        update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var buttons_grid = new Gtk.Grid ();
        buttons_grid.orientation = Gtk.Orientation.HORIZONTAL;
        buttons_grid.column_spacing = 12;
        buttons_grid.halign = Gtk.Align.END;
        buttons_grid.valign = Gtk.Align.CENTER;
        buttons_grid.add (update_size);
        buttons_grid.add (update_all_button);

        progress_bar = new Gtk.ProgressBar ();
        progress_label = new Gtk.Label (null);

        var progress_grid = new Gtk.Grid ();
        progress_grid.orientation = Gtk.Orientation.VERTICAL;
        progress_grid.row_spacing = 6;
        progress_grid.halign = Gtk.Align.CENTER;
        progress_grid.valign = Gtk.Align.CENTER;
        progress_grid.add (progress_label);
        progress_grid.add (progress_bar);

        top_right_stack = new Gtk.Stack ();
        top_right_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        top_right_stack.add_named (buttons_grid, "buttons");
        top_right_stack.add_named (progress_grid, "progress");

        updates_grid = new Gtk.Grid ();
        updates_grid.orientation = Gtk.Orientation.HORIZONTAL;
        updates_grid.margin = 12;
        updates_grid.column_spacing = 12;
        updates_grid.valign = Gtk.Align.CENTER;
        updates_grid.add (update_label);
        updates_grid.add (top_right_stack);

        top_stack.add (updating_grid);
        top_stack.add (updates_grid);
        main_grid.add (top_stack);
        main_grid.add (app_list_view);
        add (main_grid);

        app_list_view.show_app.connect ((package) => {
            subview_entered (C_("view", "Installed"));
            show_package (package);
        });

        update_all_button.clicked.connect (() => update_all_apps.begin ());
    }

    public override void return_clicked () {
        set_visible_child (main_grid);
    }

    private void show_update_number () {
        var applications = app_list_view.get_packages ();
        int update_numbers = 0;
        uint64 update_real_size = 0ULL;
        foreach (var package in applications) {
            if (package.update_available) {
                update_numbers++;
                update_real_size += package.update_size;
            }
        }

        var package = Client.get_default ().os_updates;
        if (package.update_available) {
            update_numbers++;
            update_real_size += package.update_size;
        }

        if (update_numbers > 0) {
            update_size.label = _("Size: %s").printf (GLib.format_size (update_real_size));
            update_label.label = ngettext ("%d update is available.", "%d updates are available.", update_numbers).printf (update_numbers);
            update_all_button.show ();
            update_size.show ();
        } else {
            update_label.label = _("Your System is up-to-date.");
            update_all_button.hide ();
            update_size.hide ();
        }

        top_stack.set_visible_child (updates_grid);
#if HAVE_UNITY
        var launcher_entry = Unity.LauncherEntry.get_for_desktop_file ("appcenter.desktop");
        launcher_entry.count = update_numbers;
        launcher_entry.count_visible = update_numbers > 0;
#endif
    }

    private async void get_apps () {
        unowned Client client = Client.get_default ();
        var installed_apps = yield client.get_installed_applications ();
        foreach (var app in installed_apps) {
            app_list_view.add_package (app);
        }

        yield client.refresh_updates ();
    }

    private async void update_all_apps () {
        top_right_stack.set_visible_child_name ("progress");
        /*updates.clear ();
        unowned Client client = Client.get_default ();
        var applications = client.get_cached_applications ();
        foreach (var package in applications) {
            if (package.update_available) {
                updates.add (package);
            }
        }

        try {
            yield client.update_packages (updates, (progress, type) => ProgressCallback (progress, type));
            top_right_stack.set_visible_child_name ("buttons");
        } catch (Error e) {
            critical (e.message);
            top_right_stack.set_visible_child_name ("buttons");
        }*/
    }
}
