/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class AppCenterCore.ComponentStore : Object {
    private ListStore _components;
    public ListModel components { get { return _components; } }

    private Gee.HashMap<string, Component> components_by_id;

    construct {
        _components = new ListStore (typeof (Component));

        components_by_id = new Gee.HashMap<string, Component> ();
    }

    public void update (Gee.Collection<Package> removed, Gee.Collection<Package> added) {
        var new_components = new Gee.HashSet<Component> ();

        /* Add added packages to their components, creating new components if necessary */
        foreach (var added_package in added) {
            var comp_id = added_package.normalized_component_id;
            var comp = components_by_id[comp_id];

            if (comp == null) {
                comp = new Component (comp_id);
                new_components.add (comp);
            }

            components_by_id[comp_id] = comp;

            /* No op if package is already in the component */
            comp.add_package (added_package);
        }

        /* Remove removed packages from their components */
        foreach (var removed_package in removed) {
            var comp_id = removed_package.normalized_component_id;
            components_by_id[comp_id].remove_package (removed_package);
        }

        /* Cleanup empty components */
        if (!removed.is_empty) {
            for (int i = (int) _components.get_n_items () - 1; i >= 0; i--) {
                var component = (Component) _components.get_item (i);
                if (component.get_n_items () == 0) {
                    _components.remove (i);
                    components_by_id.unset (component.component_id);
                }
            }
        }

        /* Add new components */
        _components.splice (_components.n_items, 0, new_components.to_array ());
    }

    public Gee.Collection<Package> get_packages_for_component_id (string id) {
        var normalized_component_id = Utils.normalize_component_id (id);
        var component = components_by_id[normalized_component_id];
        var packages = new Gee.ArrayList<Package> ();

        if (component == null) {
            return packages;
        }

        for (uint i = 0; i < component.get_n_items (); i++) {
            var package = (Package) component.get_item (i);
            packages.add (package);
        }

        return packages;
    }
}
