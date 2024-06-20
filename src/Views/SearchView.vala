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

    private AppCenterCore.SearchManager search_manager;
    private GLib.ListModel list_store;
    private Gtk.SearchEntry search_entry;
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

        search_manager = AppCenterCore.FlatpakBackend.get_default ().get_search_manager ();

        var selection_model = new Gtk.NoSelection (search_manager.results);

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            list_item.child = new Widgets.ListPackageRowGrid (null);
        });
        factory.bind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            ((Widgets.ListPackageRowGrid) list_item.child).bind ((AppCenterCore.Package) list_item.item);
        });

        var list_view = new Gtk.ListView (selection_model, factory) {
            single_click_activate = true,
            hexpand = true,
            vexpand = true
        };

        var scrolled = new Gtk.ScrolledWindow () {
            child = list_view,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        var stack = new Gtk.Stack ();
        stack.add_child (alert_view);
        stack.add_child (scrolled);

        var toolbarview = new Adw.ToolbarView () {
            content = stack
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

        selection_model.items_changed.connect (() => {
            list_view.scroll_to (0, NONE, null);

            if (selection_model.n_items > 0) {
                stack.visible_child = scrolled;
            } else {
                stack.visible_child = alert_view;
            }
        });

        list_view.activate.connect ((index) => {
            show_app ((AppCenterCore.Package) search_manager.results.get_item (index));
        });

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
        if (search_entry.text.length >= VALID_QUERY_LENGTH) {
            var dyn_flathub_link = "<a href='https://flathub.org/apps/search/%s'>%s</a>".printf (search_entry.text, _("Flathub"));
            alert_view.description = _("Try changing search terms. You can also sideload Flatpak apps e.g. from %s").printf (dyn_flathub_link);

            if (mimetype) {
                // This didn't do anything
            } else {
                search_manager.search (search_entry.text, update_category ());
            }

        } else {
            alert_view.description = _("The search term must be at least 3 characters long.");
        }

        if (mimetype) {
            mimetype = false;
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
}
