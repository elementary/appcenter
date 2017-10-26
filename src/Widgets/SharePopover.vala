/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Daniel Foré <daniel@elementary.io>
 */

public class SharePopover : Gtk.Popover {
    public signal void link_copied ();

    public string body { get; set; }
    public string uri { get; set; }

    public SharePopover (string body, string uri) {
        Object (
            body: body,
            uri: uri
        );
    }

    construct {
        var email_button = new Gtk.Button.from_icon_name ("internet-mail", Gtk.IconSize.DND);
        email_button.tooltip_text = _("Email");
        email_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var copy_link_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        copy_link_button.tooltip_text = _("Copy link");
        copy_link_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        size_group.add_widget (email_button);
        size_group.add_widget (copy_link_button);

        var service_grid = new Gtk.Grid ();
        service_grid.margin = 6;

        service_grid.add (make_share_button(_("Facebook"), "https://www.facebook.com/sharer/sharer.php?u=%s", "online-account-facebook"));
        service_grid.add (make_share_button(_("Twitter"), "http://twitter.com/home/?status=%s %s", "online-account-twitter"));
        service_grid.add (make_share_button(_("reddit"), "http://www.reddit.com/submit?title=%s&url=%s", "online-account-reddit"));
        service_grid.add (make_share_button(_("Tumblr"), "https://www.tumblr.com/share/link?url=%s", "online-account-tumblr"));
        service_grid.add (make_share_button(_("Telegram"), "https://t.me/share/url?url=%s", "online-account-telegram"));
        
        var system_grid = new Gtk.Grid ();
        system_grid.margin = 6;
        system_grid.add (copy_link_button);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.add (service_grid);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (system_grid);
        grid.show_all ();

        add (grid);

        copy_link_button.clicked.connect (() => {
            var clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
            clipboard.set_text (uri, -1);

            link_copied ();

            hide ();
        });

        email_button.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("mailto:?body=%s %s".printf (body, uri), null);
            } catch (Error e) {
                warning ("%s", e.message);
            }
            hide ();
        });
    }

    Gtk.Widget make_share_button(string name, string uri_template, string icon_name) {
        var button = new Gtk.Button.from_icon_name (icon_name, Gtk.IconSize.DND);
        button.tooltip_text = name;
        button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        button.clicked.connect (() => {
            try {
                if (uri_template.index_of("%s") == uri_template.last_index_of("%s")) {
                    AppInfo.launch_default_for_uri(uri_template.printf(uri), null);
                } else {
                    AppInfo.launch_default_for_uri(uri_template.printf(body, uri), null);
                }
            } catch (Error e) {
                warning ("%s", e.message);
            }
            hide();
        });
        return button;
    }
}
