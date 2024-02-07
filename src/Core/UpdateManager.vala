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
    public bool restart_required { public get; private set; default = false; }
    public Package os_updates { public get; private set; }
    public Package runtime_updates { public get; private set; }
    public int unpaid_apps_number { get; private set; default = 0; }
    public uint64 updates_size { get; private set; default = 0ULL; }
    public bool has_flatpak_updates { get; private set; default = false; }

    private const string RESTART_REQUIRED_FILE = "/var/run/reboot-required";

    private File restart_file;

    construct {
        restart_file = File.new_for_path (RESTART_REQUIRED_FILE);

        var os_icon = new AppStream.Icon ();
        os_icon.set_name ("distributor-logo");
        os_icon.set_kind (AppStream.IconKind.STOCK);

        var os_updates_component = new AppStream.Component ();
        os_updates_component.id = AppCenterCore.Package.OS_UPDATES_ID;
        os_updates_component.name = _("Operating System Updates");
        os_updates_component.summary = _("Updates to system components");
        os_updates_component.add_icon (os_icon);

        os_updates = new AppCenterCore.Package (BackendAggregator.get_default (), os_updates_component);

        var runtime_icon = new AppStream.Icon ();
        runtime_icon.set_name ("application-vnd.flatpak");
        runtime_icon.set_kind (AppStream.IconKind.STOCK);

        var runtime_updates_component = new AppStream.Component ();
        runtime_updates_component.id = AppCenterCore.Package.RUNTIME_UPDATES_ID;
        runtime_updates_component.name = _("Runtime Updates");
        runtime_updates_component.summary = _("Updates to app runtimes");
        runtime_updates_component.add_icon (runtime_icon);

        runtime_updates = new AppCenterCore.Package (BackendAggregator.get_default (), runtime_updates_component);
    }

    public async uint get_updates (Cancellable? cancellable = null) {
        var apps_with_updates = new Gee.TreeSet<Package> ();
        uint count = 0;
        has_flatpak_updates = false;
        unpaid_apps_number = 0;
        updates_size = 0ULL;

        // Clear any packages previously marked as updatable
        var installed_packages = yield BackendAggregator.get_default ().get_installed_applications ();
        foreach (var installed_package in installed_packages) {
            installed_package.change_information.clear_update_info ();
            installed_package.update_state ();
        }


        uint os_count = 0;
        string os_desc = "";

#if PACKAGEKIT_BACKEND
        Pk.Results pk_updates;
        unowned PackageKitBackend client = PackageKitBackend.get_default ();
        try {
            pk_updates = yield client.get_updates (cancellable);
        } catch (Error e) {
            warning ("Unable to get updates from PackageKit backend: %s", e.message);
            return 0;
        }

        var package_array = pk_updates.get_package_array ();
        debug ("PackageKit backend reports %d updates", package_array.length);

        package_array.foreach ((pk_package) => {
            var pkg_name = pk_package.get_name ();
            debug ("Added %s to OS updates", pkg_name);
            os_count++;
            unowned string pkg_summary = pk_package.get_summary ();
            unowned string pkg_version = pk_package.get_version ();
            os_desc += Markup.printf_escaped (
                " • %s\n\t%s\n\t%s\n",
                pkg_name,
                pkg_summary,
                _("Version: %s").printf (pkg_version)
            );
        });
#endif

        os_updates.component.set_pkgnames ({});
        os_updates.change_information.clear_update_info ();

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

                count++;
                updates_size += appcenter_package.change_information.size;
                has_flatpak_updates = true;

                appcenter_package.change_information.updatable_packages.@set (fp_client, flatpak_update);
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
                has_flatpak_updates = true;

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
                runtime_updates.change_information.updatable_packages.@set (fp_client, flatpak_update);
            }
        }

        if (os_count == 0) {
            debug ("No OS updates found");
            var latest_version = _("No components with updates");
            os_updates.latest_version = latest_version;
            os_updates.description = GLib.Markup.printf_escaped ("%s\n", latest_version);
        } else {
            debug ("%u OS updates found", os_count);
            var latest_version = ngettext ("%u component with updates", "%u components with updates", os_count).printf (os_count);
            os_updates.latest_version = latest_version;
            os_updates.description = "%s\n%s\n".printf (GLib.Markup.printf_escaped (_("%s:"), latest_version), os_desc);
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

        debug ("%u app updates found", count);
        if (os_count > 0) {
            count += 1;
        }

        if (runtime_count > 0) {
            count += 1;
        }

#if PACKAGEKIT_BACKEND
        pk_updates.get_details_array ().foreach ((pk_detail) => {
            var pk_package = new Pk.Package ();
            try {
                pk_package.set_id (pk_detail.get_package_id ());
                var pkg_name = pk_package.get_name ();

                var pkgnames = os_updates.component.pkgnames;
                pkgnames += pkg_name;
                os_updates.component.pkgnames = pkgnames;

                os_updates.change_information.updatable_packages.@set (client, pk_package.get_id ());
                os_updates.change_information.size += pk_detail.size;
            } catch (Error e) {
                critical (e.message);
            }
        });
#endif

        os_updates.update_state ();
        runtime_updates.update_state ();
        return count;
    }

    public void update_restart_state () {
#if PACKAGEKIT_BACKEND
        var should_restart = restart_file.query_exists () || PackageKitBackend.get_default ().is_restart_required ();
#else
        var should_restart = restart_file.query_exists ();
#endif

        if (should_restart) {
            if (!restart_required) {
                string title = _("Restart Required");
                string body = _("Please restart your system to finalize updates");
                var notification = new Notification (title);
                notification.set_body (body);
                notification.set_icon (new ThemedIcon ("system-reboot"));
                notification.set_priority (NotificationPriority.URGENT);
                notification.set_default_action ("app.open-application");
                Application.get_default ().send_notification ("restart", notification);
            }

            restart_required = true;
        } else if (restart_required) {
            restart_required = false;
        }
    }

    private static GLib.Once<UpdateManager> instance;
    public static unowned UpdateManager get_default () {
        return instance.once (() => { return new UpdateManager (); });
    }
}
