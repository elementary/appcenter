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
 */

using Gee;
using AppCenterCore;

// An immutable, signal-able package list container
public class AppCenterCore.PackageList : Object {
    public signal void updated ();

    protected Gee.ConcurrentList<AppCenterCore.Package> _packages_backend;

    public PackageList () {
        _packages_backend = new ConcurrentList<Package> ();
    }

    public PackageList set_packages (Collection<Package> collection) {
        _packages_backend.clear ();
        _packages_backend.add_all (collection);
        updated ();
        return this;
    }

    public PackageList set_from_iterator (Iterator<Package> itor) {
        _packages_backend.clear ();
        _packages_backend.add_all_iterator (itor);
        updated ();
        return this;
    }

    public PackageList set_from_array (Package[] arr) {
        _packages_backend.clear ();
        _packages_backend.add_all_array (arr);
        updated ();
        return this;
    }

    public Collection<Package> get_packages () {
        return _packages_backend.read_only_view;
    }
 }
