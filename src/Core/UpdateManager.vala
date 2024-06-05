/*
 * Copyright 2017–2021 elementary, Inc. (https://elementary.io)
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
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class AppCenterCore.UpdateManager : Object {
    public Package runtime_updates { public get; private set; }
    public int unpaid_apps_number { get; private set; default = 0; }
    public uint updates_number { get; private set; default = 0U; }
    public uint64 updates_size { get; private set; default = 0ULL; }

    construct {
        var runtime_icon = new AppStream.Icon ();
        runtime_icon.set_name ("application-vnd.flatpak");
        runtime_icon.set_kind (AppStream.IconKind.STOCK);

        var runtime_updates_component = new AppStream.Component ();
        runtime_updates_component.id = AppCenterCore.Package.RUNTIME_UPDATES_ID;
        runtime_updates_component.name = _("Runtime Updates");
        runtime_updates_component.summary = _("Updates to app runtimes");
        runtime_updates_component.add_icon (runtime_icon);

        runtime_updates = new AppCenterCore.Package (runtime_updates_component);
    }

    public async uint get_updates (Cancellable? cancellable = null) {
        var apps_with_updates = new Gee.TreeSet<Package> ();
        updates_number = 0;
        unpaid_apps_number = 0;
        updates_size = 0ULL;

        // Clear any packages previously marked as updatable
        var installed_packages = yield FlatpakBackend.get_default ().get_installed_applications ();
        foreach (var installed_package in installed_packages) {
            installed_package.change_information.clear_update_info ();
            installed_package.update_state ();
        }

        uint runtime_count = 0;
        string runtime_desc = "";

        unowned FlatpakBackend fp_client = FlatpakBackend.get_default ();
        var flatpak_updates = yield fp_client.get_updates ();
        debug ("Flatpak backend reports %d updates", flatpak_updates.size);

        foreach (var flatpak_update in flatpak_updates) {
            var appcenter_package = fp_client.lookup_package_by_id (flatpak_update);
            if (appcenter_package != null) {
                debug ("Added %s to app updates", flatpak_update);
                apps_with_updates.add (appcenter_package);

                if (appcenter_package.should_pay) {
                    unpaid_apps_number++;
                }

                updates_number++;
                updates_size += appcenter_package.change_information.size;

                appcenter_package.change_information.updatable_packages.add (flatpak_update);
                appcenter_package.update_state ();
                try {
                    appcenter_package.change_information.size = yield fp_client.get_download_size (appcenter_package, null, true);
                } catch (Error e) {
                    warning ("Unable to get flatpak download size: %s", e.message);
                }
            } else {
                debug ("Added %s to runtime updates", flatpak_update);
                string bundle_id;
                if (!FlatpakBackend.get_package_list_key_parts (flatpak_update, null, null, out bundle_id)) {
                    continue;
                }

                Flatpak.Ref @ref;
                try {
                    @ref = Flatpak.Ref.parse (bundle_id);
                } catch (Error e) {
                    warning ("Error parsing flatpak bundle ID: %s", e.message);
                    continue;
                }

                runtime_count++;

                runtime_desc += Markup.printf_escaped (
                    " • %s\n\t%s\n",
                    @ref.get_name (),
                    _("Version: %s").printf (@ref.get_branch ())
                );

                uint64 dl_size = 0;
                try {
                    dl_size = yield fp_client.get_download_size_by_id (flatpak_update, null, true);
                } catch (Error e) {
                    warning ("Unable to get flatpak download size: %s", e.message);
                }

                updates_size += dl_size;
                runtime_updates.change_information.size += dl_size;
                runtime_updates.change_information.updatable_packages.add (flatpak_update);
            }
        }

        if (runtime_count == 0) {
            debug ("No runtime updates found");
            var latest_version = _("No runtimes with updates");
            runtime_updates.latest_version = latest_version;
            runtime_updates.description = GLib.Markup.printf_escaped ("%s\n", latest_version);
        } else {
            debug ("%u runtime updates found", runtime_count);
            var latest_version = ngettext ("%u runtimes with updates", "%u runtimes with updates", runtime_count).printf (runtime_count);
            runtime_updates.latest_version = latest_version;
            runtime_updates.description = "%s\n%s\n".printf (GLib.Markup.printf_escaped (_("%s:"), latest_version), runtime_desc);
        }

        debug ("%u app updates found", updates_number);

        if (runtime_count > 0) {
            updates_number += 1;
        }

        if (!AppCenter.App.settings.get_boolean ("automatic-updates")) {
            var application = Application.get_default ();
            if (updates_number > 0) {
                var title = ngettext ("Update Available", "Updates Available", updates_number);
                var body = ngettext (
                    "%u app update is available",
                    "%u app updates are available",
                    updates_number
                ).printf (updates_number);

                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("software-update-available"));
                notification.set_default_action ("app.show-updates");

                application.send_notification ("io.elementary.appcenter.updates", notification);
            } else {
                application.withdraw_notification ("io.elementary.appcenter.updates");
            }

            try {
                yield Granite.Services.Application.set_badge (updates_number);
                yield Granite.Services.Application.set_badge_visible (updates_number != 0);
            } catch (Error e) {
                warning ("Error setting updates badge: %s", e.message);
            }
        }

        runtime_updates.update_state ();
        return updates_number;
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
