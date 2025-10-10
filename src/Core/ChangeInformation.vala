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

    public enum Status {
        UNKNOWN,
        CANCELLED,
        WAITING,
        RUNNING
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

    public Cancellable cancellable { get; private set; }
    public bool can_cancel { get; private set; default = true; }
    public double progress { get; private set; default = 0.0f; }
    public Status status { get; private set; default = Status.UNKNOWN; }
    public string status_description { get; private set; default = _("Waiting"); }

    public void start () {
        cancellable = new Cancellable ();
        can_cancel = true;
        status = Status.WAITING;
        status_description = _("Waiting");
        status_changed ();
        progress_changed ();
    }

    public void cancel () {
        status = Status.CANCELLED;
        status_description = _("Cancelling");
        status_changed ();
        progress_changed ();
    }

    public void complete () {
        can_cancel = false;
        progress = 0;
        status = Status.UNKNOWN;
        status_description = _("Unknown");
        status_changed ();
        progress_changed ();
    }

    public void callback (double progress, string status_description) {
        Idle.add_once (() => idle_callback (progress, status_description));
    }

    private void idle_callback (double progress, string status_description) {
        if (status != RUNNING) {
            status = RUNNING;
        }

        this.progress = progress;
        this.status_description = status_description;

        status_changed ();
        progress_changed ();
    }
}
