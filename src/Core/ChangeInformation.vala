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

public class AppCenterCore.ChangeInformation : Object {
    public signal void status_changed ();
    public signal void progress_changed ();

    public Gee.TreeSet<Pk.Package> changes { public get; private set; }
    public Gee.TreeSet<Pk.Details> details { public get; private set; }
    public bool can_cancel { public get; private set; default=true; }
    private Gee.HashMap<string, double?> change_progress;
    public Pk.Status status;
    private double progress;
    public ChangeInformation () {
        
    }

    construct {
        changes = new Gee.TreeSet<Pk.Package> ();
        details = new Gee.TreeSet<Pk.Details> ();
        change_progress = new Gee.HashMap<string, double?> ();
        status = Pk.Status.SETUP;
        progress = 1.0f;
    }

    public bool has_changes () {
        return changes.size > 0;
    }

    public double get_progress () {
        return progress;
    }

    public string get_status () {
        switch (status) {
            case Pk.Status.SETUP:
                return _("Starting");
            case Pk.Status.WAIT:
                return _("Waiting in queue");
            case Pk.Status.RUNNING:
                return _("Running");
            case Pk.Status.QUERY:
                return _("Querying");
            case Pk.Status.INFO:
                return _("Getting information");
            case Pk.Status.REMOVE:
                return _("Removing packages");
            case Pk.Status.DOWNLOAD:
                return _("Downloading packages");
            case Pk.Status.INSTALL:
                return _("Installing packages");
            case Pk.Status.REFRESH_CACHE:
                return _("Refreshing software list");
            case Pk.Status.UPDATE:
                return _("Installing updates");
            case Pk.Status.CLEANUP:
                return _("Cleaning up packages");
            case Pk.Status.OBSOLETE:
                return _("Obsoleting packages");
            case Pk.Status.DEP_RESOLVE:
                return _("Resolving dependencies");
            case Pk.Status.SIG_CHECK:
                return _("Checking signatures");
            case Pk.Status.TEST_COMMIT:
                return _("Testing changes");
            case Pk.Status.COMMIT:
                return _("Committing changes");
            case Pk.Status.REQUEST:
                return _("Requesting data");
            case Pk.Status.FINISHED:
                return _("Finished");
            case Pk.Status.CANCEL:
                return _("Cancelling");
            case Pk.Status.DOWNLOAD_REPOSITORY:
                return _("Downloading repository information");
            case Pk.Status.DOWNLOAD_PACKAGELIST:
                return _("Downloading list of packages");
            case Pk.Status.DOWNLOAD_FILELIST:
                return _("Downloading file lists");
            case Pk.Status.DOWNLOAD_CHANGELOG:
                return _("Downloading lists of changes");
            case Pk.Status.DOWNLOAD_GROUP:
                return _("Downloading groups");
            case Pk.Status.DOWNLOAD_UPDATEINFO:
                return _("Downloading update information");
            case Pk.Status.REPACKAGING:
                return _("Repackaging files");
            case Pk.Status.LOADING_CACHE:
                return _("Loading cache");
            case Pk.Status.SCAN_APPLICATIONS:
                return _("Scanning applications");
            case Pk.Status.GENERATE_PACKAGE_LIST:
                return _("Generating package lists");
            case Pk.Status.WAITING_FOR_LOCK:
                return _("Waiting for package manager lock");
            case Pk.Status.WAITING_FOR_AUTH:
                return _("Waiting for authentication");
            case Pk.Status.SCAN_PROCESS_LIST:
                return _("Updating running applications");
            case Pk.Status.CHECK_EXECUTABLE_FILES:
                return _("Checking applications in use");
            case Pk.Status.CHECK_LIBRARIES:
                return _("Checking libraries in use");
            case Pk.Status.COPY_FILES:
                return _("Copying files");
            default:
                return _("Unknown state");
        }
    }

    public uint64 get_size () {
        uint64 size = 0ULL;
        foreach (var detail in details) {
            size += detail.size;
        }

        return size;
    }

    public void clear () {
        changes.clear ();
        details.clear ();
        reset ();
    }

    public void reset () {
        change_progress.clear ();
        status = Pk.Status.SETUP;
        status_changed ();
        progress = 1.0f;
        progress_changed ();
    }

    public void ProgressCallback (Pk.Progress progress, Pk.ProgressType type) {
        switch (type) {
            case Pk.ProgressType.ALLOW_CANCEL:
                can_cancel = progress.allow_cancel;
                break;
            case Pk.ProgressType.ITEM_PROGRESS:
                if (progress.package_id in change_progress.keys) {
                    change_progress.unset (progress.package_id);
                }

                change_progress.set (progress.package_id, (double)progress.percentage);
                double progress_sum = 0.0f;
                foreach (var change_package_progress in change_progress.values) {
                    if (change_package_progress != null) {
                        progress_sum += change_package_progress;
                    }
                }

                this.progress = ((double) progress_sum / (double)change_progress.size)/((double)100);
                progress_changed ();
                break;
            case Pk.ProgressType.STATUS:
                status = (Pk.Status) progress.status;
                status_changed ();
                break;
        }
    }
}
