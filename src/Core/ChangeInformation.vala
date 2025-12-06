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
    public const string CANCEL_ACTION_NAME = "cancel";

    public enum Status {
        UNKNOWN,
        CANCELLED,
        WAITING,
        RUNNING,
        FINISHED
    }

    /**
     * This signal is likely to be fired from a non-main thread. Ensure any UI
     * logic driven from this runs on the GTK thread
     */
    public signal void status_changed ();

    /**
     * This signal is likely to be fired from a non-main thread. Ensure any UI
     * logic driven from this runs on the GTK thread
     */
    public signal void progress_changed ();

    public Gee.ArrayList<string> updatable_packages { get; private set; }

    public ActionGroup action_group { get; private set; }

    public Cancellable cancellable { get; private set; }
    public double progress { public get; private set; default=0.0f; }
    public Status status { public get; private set; default=Status.UNKNOWN; }
    public string status_description { public get; private set; default=_("Waiting"); }
    public uint64 size;

    private SimpleAction cancel_action;

    construct {
        updatable_packages = new Gee.ArrayList<string> ();
        size = 0;

        cancel_action = new SimpleAction (CANCEL_ACTION_NAME, null);
        cancel_action.activate.connect (cancel);

        var simple_action_group = new SimpleActionGroup ();
        simple_action_group.add_action (cancel_action);
        action_group = simple_action_group;
    }

    public bool has_changes () {
        return updatable_packages.size > 0;
    }

    public void start () {
        cancel_action.set_enabled (true);
        cancellable = new Cancellable ();
        progress = 0.0f;
        status = Status.WAITING;
        status_description = _("Waiting");
        status_changed ();
        progress_changed ();
    }

    public void complete () {
        cancel_action.set_enabled (false);
        status = Status.FINISHED;
        status_description = _("Finished");
        status_changed ();
        reset_progress ();
    }

    private void cancel () {
        cancellable.cancel ();
        cancel_action.set_enabled (false);
        status = Status.CANCELLED;
        status_description = _("Cancelling");
        status_changed ();
    }

    public void clear_update_info () {
         updatable_packages.clear ();
         size = 0;
     }

    public void reset_progress () {
        status = Status.UNKNOWN;
        status_description = _("Starting");
        progress = 0.0f;
    }

    public void callback (string status_description, double progress, Status status) {
        if (this.status_description != status_description || this.status != status) {
            this.status_description = status_description;
            this.status = status;
            status_changed ();
        }

        if (this.progress != progress) {
            this.progress = progress;
            progress_changed ();
        }
    }
}
