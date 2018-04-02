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

public interface AppCenterCore.Backend : Object {
	public signal void operation_finished (Package package, Package.State operation, Error? error);
    public signal void cache_update_failed (Error error);
    public signal void updates_available ();
    public signal void drivers_detected ();

	public abstract string backend_identifier { get; set; }
	public abstract bool restart_required { get; set; }
	public abstract bool connected { get; set; }
    public abstract uint task_count { get; set; }
    public abstract bool updating_cache { get; set; }

	public abstract async Gee.Collection<AppCenterCore.Package> get_updates (Cancellable? cancellable) throws Error;
	public abstract async Gee.Collection<AppCenterCore.Package> get_installed (Cancellable? cancellable) throws Error;
    public abstract Gee.Collection<AppCenterCore.Package> get_applications_for_category (AppStream.Category category);
    public abstract Gee.Collection<AppCenterCore.Package> search_applications (string query, AppStream.Category? category);

	public void update_restart_state () {
        return;
    }
}
