/*
 * Copyright (c) 2019 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.NonCuratedWarningDialog : Granite.MessageDialog {
    public string app_name { get; construct set; }

    private static Gtk.CssProvider provider;

    public NonCuratedWarningDialog (string _app_name) {
        Object (
            app_name: _app_name,
            image_icon: new ThemedIcon ("security-low"),
            title: _("Non-Curated Warning")
        );
    }

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("io/elementary/appcenter/NonCuratedWarningDialog.css");
    }

    construct {
        primary_text = _("Install non-curated app?");
        secondary_text = _("“%s” is not curated by elementary and has not been reviewed for security, privacy, or system integration.").printf (app_name);

        var updates_icon = new Gtk.Image.from_icon_name ("system-software-update-symbolic", Gtk.IconSize.BUTTON);
        updates_icon.valign = Gtk.Align.START;

        unowned Gtk.StyleContext updates_context = updates_icon.get_style_context ();
        updates_context.add_class ("updates");
        updates_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var updates_label = new Gtk.Label (_("It may not receive bug fix or feature updates"));
        updates_label.selectable = true;
        updates_label.max_width_chars = 50;
        updates_label.wrap = true;
        updates_label.xalign = 0;

        var unsandboxed_icon = new Gtk.Image.from_icon_name ("security-low-symbolic", Gtk.IconSize.BUTTON);
        unsandboxed_icon.valign = Gtk.Align.START;

        unowned Gtk.StyleContext unsandboxed_context = unsandboxed_icon.get_style_context ();
        unsandboxed_context.add_class ("unsandboxed");
        unsandboxed_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var unsandboxed_label = new Gtk.Label (_("It may access or change system or personal files without permission"));
        unsandboxed_label.selectable = true;
        unsandboxed_label.max_width_chars = 50;
        unsandboxed_label.wrap = true;
        unsandboxed_label.xalign = 0;

        var check = new Gtk.CheckButton.with_label (_("Show non-curated warnings"));
        check.margin_top = 12;

        var details_grid = new Gtk.Grid ();
        details_grid.orientation = Gtk.Orientation.VERTICAL;
        details_grid.column_spacing = 6;
        details_grid.row_spacing = 12;
        details_grid.attach (updates_icon, 0, 0);
        details_grid.attach (updates_label, 1, 0);
        details_grid.attach (unsandboxed_icon, 0, 1);
        details_grid.attach (unsandboxed_label, 1, 1);
        details_grid.attach (check, 0, 2, 2);

        App.settings.bind ("non-curated-warning", check, "active", SettingsBindFlags.DEFAULT);

        add_button (_("Don’t Install"), Gtk.ResponseType.CANCEL);
        var install = add_button (_("Install Anyway"), Gtk.ResponseType.OK);

        custom_bin.add (details_grid);
        custom_bin.show_all ();

        check.grab_focus ();
    }
}
