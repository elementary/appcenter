// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2016 elementary LLC. (https://elementary.io)
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
    public Pk.Status status { public get; private set; }
    public double progress { public get; private set; }
    private int current_progress;
    private int last_progress;
    private Pk.Status current_status;
    private double progress_denom;

    construct {
        changes = new Gee.TreeSet<Pk.Package> ();
        details = new Gee.TreeSet<Pk.Details> ();
        status = Pk.Status.SETUP;
        progress = 0.0f;
        current_progress = 0;
        last_progress = 0;
        current_status = Pk.Status.SETUP;
        /* usually we have 2 transactions, each with 100% progress */
        progress_denom = 200.0f;
    }

    public bool has_changes () {
        return changes.size > 0;
    }

    public string get_status_string () {
        switch (status) {
            case Pk.Status.SETUP:
                return _("Starting");
            case Pk.Status.WAIT:
                return _("Waiting");
            case Pk.Status.RUNNING:
                return _("Running");
            case Pk.Status.QUERY:
                return _("Querying");
            case Pk.Status.INFO:
                return _("Getting information");
            case Pk.Status.REMOVE:
                return _("Removing packages");
            case Pk.Status.DOWNLOAD:
                return _("Downloading");
            case Pk.Status.INSTALL:
                return _("Installing");
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

    public void start () {
        progress = 0.0f;
        progress_changed ();
        status = Pk.Status.WAIT;
        status_changed ();
    }

    public void complete () {
        status = Pk.Status.FINISHED;
        status_changed ();
        reset_progress ();
    }

    public void cancel () {
        progress = 0.0f;
        progress_changed ();
        status = Pk.Status.CANCEL;
        status_changed ();
        reset_progress ();
    }

    public void clear_update_info () {
         changes.clear ();
         details.clear ();
     }

    public void reset_progress () {
        status = Pk.Status.SETUP;
        progress = 0.0f;
        last_progress = 0;
        current_progress = 0;
        current_status = 0;
        progress_denom = 200.0f;
    }

    public void ProgressCallback (Pk.Progress progress, Pk.ProgressType type) {
        switch (type) {
            case Pk.ProgressType.ALLOW_CANCEL:
                can_cancel = progress.allow_cancel;
                break;
            case Pk.ProgressType.ITEM_PROGRESS:
                if (current_status == Pk.Status.SETUP) {
                    current_status = (Pk.Status) progress.status;
                    /* skipping package download, we have cached packages */
                    if (current_status != Pk.Status.DOWNLOAD) {
                        progress_denom = 100.0f;
                    }
                }
                /* transaction changed so progress count is starting over */
                else if ((Pk.Status) progress.status != current_status) {
                    current_status = (Pk.Status) progress.status;
                    current_progress = last_progress;
                }

                last_progress = progress.percentage;
                double progress_sum = current_progress + last_progress;
                this.progress = progress_sum / progress_denom;
                progress_changed ();
                break;
            case Pk.ProgressType.STATUS:
                status = (Pk.Status) progress.status;
                status_changed ();
                break;
        }
    }
}
