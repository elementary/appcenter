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

    Gtk.Stack top_stack;
    public InstalledView () {
        Client.get_default ().updates_available.connect (() => show_update_number ());

        get_apps.begin ();
    }

    construct {
        main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;

        app_list_view = new AppListView ();

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

        updates_grid = new Gtk.Grid ();
        updates_grid.orientation = Gtk.Orientation.HORIZONTAL;
        updates_grid.margin = 12;
        updates_grid.column_spacing = 12;
        updates_grid.valign = Gtk.Align.CENTER;
        update_label = new Gtk.Label (null);
        update_label.get_style_context ().add_class ("h2");
        update_label.hexpand = true;
        ((Gtk.Misc) update_label).xalign = 0;
        update_size = new Gtk.Label (null);
        update_all_button = new Gtk.Button.with_label (_("Update All"));
        update_all_button.valign = Gtk.Align.CENTER;
        update_all_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        updates_grid.add (update_label);
        updates_grid.add (update_size);
        updates_grid.add (update_all_button);

        top_stack.add (updating_grid);
        top_stack.add (updates_grid);
        main_grid.add (top_stack);
        main_grid.add (app_list_view);
        add (main_grid);

        app_list_view.show_app.connect ((package) => {
            subview_entered (C_("view", "Installed"));
            show_package (package);
        });
    }

    public override void return_clicked () {
        set_visible_child (main_grid);
    }

    private void show_update_number () {
        var applications = Client.get_default ().get_cached_applications ();
        int update_numbers = 0;
        uint64 update_real_size = 0U;
        foreach (var package in applications) {
            if (package.update_available) {
                update_numbers++;
                update_real_size += package.update_package.size;
            }
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
        client.refresh_updates.begin ();
        foreach (var app in installed_apps) {
            app_list_view.add_package (app);
        }
    }
}
