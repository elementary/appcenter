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
 * Authored by: Fabian Thoma <fabian@elementary.io>
 */

public interface AppCenterCore.Package : Object {

    public enum State {
        NOT_INSTALLED,
        INSTALLED,
        INSTALLING,
        UPDATE_AVAILABLE,
        UPDATING,
        REMOVING
    }

	public signal void changing (bool is_changing);
    public signal void info_changed (Pk.Status status);

    public abstract GLib.Cancellable action_cancellable { public get; protected set; }
    public abstract State state { public get; protected set; }
    public abstract double progress { public get; }
    public abstract bool installed { public get; }
    public abstract bool update_available { public get; }
    public abstract bool should_nag_update { public get; }
    public abstract bool is_updating { public get; }
    public abstract bool changes_finished { public get; }
    public abstract bool is_os_updates { public get; }
    public abstract bool is_driver { public get; }
    public abstract bool is_local { public get; }
    public abstract bool is_shareable { public get; }
    public abstract bool is_native { public get; }
    public abstract bool has_payments { public get; }
    public abstract string author { public get; }
    public abstract string author_title { public get; }
    public abstract string? latest_version { public get; internal set; }

    public abstract void update_state ();
    public abstract async bool update ();
    public abstract async bool install ();

    public abstract async bool uninstall ();
    public abstract void launch () throws Error;
    public abstract string? get_id ();
    public abstract string? get_name ();
    public abstract string? get_desktop_id ();
    public abstract string? get_description ();
    public abstract string? get_summary ();
    public abstract int get_size ();
    public abstract string get_progress_description ();
    public abstract GLib.Icon get_icon (uint size = 32);
    public abstract string? get_version ();
    public abstract string? get_color_primary ();
    public abstract string? get_color_primary_text ();
    public abstract string? get_payments_key ();
    public abstract string get_suggested_amount ();
    public abstract bool get_can_launch ();
    public abstract Gee.ArrayList<AppStream.Release> get_newest_releases (int min_releases, int max_releases);
    public abstract AppStream.Release? get_newest_release ();
    public abstract Pk.Package? find_package ();
}
