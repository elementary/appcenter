/*-
* Copyright 2014-2023 elementary, Inc. (https://elementary.io)
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
*              Jeremy Wootten <jeremy@elementaryos.org>
*              Atheesh Thirumalairajan <candiedoperation@icloud.com>
*/

public class AppCenter.SearchView : Adw.NavigationPage {
    public signal void show_app (AppCenterCore.Package package);

    public const int VALID_QUERY_LENGTH = 3;

    public string search_term { get; construct; }
    public bool mimetype { get; set; default = false; }

    private GLib.ListStore list_store;
    private Gtk.ListView list_view;
    private Gtk.NoSelection selection_model;
    private Gtk.SearchEntry search_entry;
    private Gtk.Stack stack;
    private Granite.Placeholder alert_view;

    public SearchView (string search_term) {
        Object (search_term: search_term);
    }

    construct {
        var flathub_link = "<a href='https://flathub.org'>%s</a>".printf (_("Flathub"));
        alert_view = new Granite.Placeholder (_("No Apps Found")) {
            description = _("The search term must be at least 3 characters long."),
            icon = new ThemedIcon ("edit-find-symbolic")
        };

        var search_entry_eventcontrollerkey = new Gtk.EventControllerKey ();

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search Apps"),
            text = search_term
        };
        search_entry.add_controller (search_entry_eventcontrollerkey);
        search_entry.set_key_capture_widget (this);

        var search_clamp = new Adw.Clamp () {
            child = search_entry
        };

        var headerbar = new Gtk.HeaderBar () {
            title_widget = search_clamp
        };
        headerbar.pack_start (new BackButton ());

        list_store = new GLib.ListStore (typeof (AppCenterCore.Package));

        selection_model = new Gtk.NoSelection (list_store);

        var factory = new Gtk.SignalListItemFactory ();

        list_view = new Gtk.ListView (selection_model, factory) {
            single_click_activate = true,
            hexpand = true,
            vexpand = true
        };

        stack = new Gtk.Stack ();
        stack.add_child (alert_view);
        stack.add_child (list_view);

        var scrolled = new Gtk.ScrolledWindow () {
            child = stack,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        var toolbarview = new Adw.ToolbarView () {
            content = scrolled
        };
        toolbarview.add_top_bar (headerbar);

        add_css_class (Granite.STYLE_CLASS_VIEW);
        child = toolbarview;
        /// TRANSLATORS: the name of the Search view
        title = C_("view", "Search");

        shown.connect (() => {
            update_category ();
            search_entry.grab_focus ();
        });

        factory.setup.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            list_item.child = new SearchListItem ();
        });

        factory.bind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            ((SearchListItem) list_item.child).package = (AppCenterCore.Package) list_item.item;
        });

        list_view.activate.connect ((index) => {
            show_app ((AppCenterCore.Package) selection_model.get_item (index));
        });

        selection_model.items_changed.connect (on_items_changed);

        search_entry.search_changed.connect (search);

        search_entry_eventcontrollerkey.key_released.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.Down:
                    search_entry.move_focus (TAB_FORWARD);
                    break;
                case Gdk.Key.Escape:
                    search_entry.text = "";
                    break;
                default:
                    break;
            }
        });
    }

    private void search () {
        list_store.remove_all ();

        if (search_entry.text.length >= VALID_QUERY_LENGTH) {
            var dyn_flathub_link = "<a href='https://flathub.org/apps/search/%s'>%s</a>".printf (search_entry.text, _("Flathub"));
            alert_view.description = _("Try changing search terms. You can also sideload Flatpak apps e.g. from %s").printf (dyn_flathub_link);

            unowned var flatpak_backend = AppCenterCore.FlatpakBackend.get_default ();

            Gee.Collection<AppCenterCore.Package> found_apps;

            if (mimetype) {
                found_apps = flatpak_backend.search_applications_mime (search_entry.text);
                add_packages (found_apps);
            } else {
                var category = update_category ();

                found_apps = flatpak_backend.search_applications (search_entry.text, category);
                add_packages (found_apps);
            }

        } else {
            alert_view.description = _("The search term must be at least 3 characters long.");
        }

        if (mimetype) {
            mimetype = false;
        }
    }

    private void on_items_changed () {
        list_view.scroll_to (0, NONE, null);

        if (selection_model.n_items > 0) {
            stack.visible_child = list_view;
        } else {
            stack.visible_child = alert_view;
        }
    }

    private AppStream.Category? update_category () {
        var navigation_view = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));
        var previous_page = navigation_view.get_previous_page (navigation_view.visible_page);
        if (previous_page is CategoryView) {
            var category = ((CategoryView) previous_page).category;
            search_entry.placeholder_text = _("Search %s").printf (category.name);

            return category;
        }

        search_entry.placeholder_text = _("Search Apps");
        return null;
    }

    public void add_packages (Gee.Collection<AppCenterCore.Package> packages) {
        foreach (var package in packages) {
            // Don't show plugins or fonts in search and category views
            if (package.kind != AppStream.ComponentKind.ADDON && package.kind != AppStream.ComponentKind.FONT) {
                GLib.CompareDataFunc<AppCenterCore.Package> sort_fn = (a, b) => {
                    return compare_packages (a, b);
                };

                list_store.insert_sorted (package, sort_fn);
            }
        }
    }

    private int search_priority (string name) {
        if (name != null && search_entry.text != "") {
            var name_lower = name.down ();
            var term_lower = search_entry.text.down ();

            var term_position = name_lower.index_of (term_lower);

            // App name starts with our search term, highest priority
            if (term_position == 0) {
                return 2;
            // App name contains our search term, high priority
            } else if (term_position != -1) {
                return 1;
            }
        }

        // Otherwise, normal appstream search ranking order
        return 0;
    }

    private int compare_packages (AppCenterCore.Package p1, AppCenterCore.Package p2) {
        if ((p1.kind == AppStream.ComponentKind.ADDON) != (p2.kind == AppStream.ComponentKind.ADDON)) {
            return p1.kind == AppStream.ComponentKind.ADDON ? 1 : -1;
        }

        int sp1 = search_priority (p1.get_name ());
        int sp2 = search_priority (p2.get_name ());
        if (sp1 != sp2) {
            return sp2 - sp1;
        }

        return p1.get_name ().collate (p2.get_name ());
    }
}
