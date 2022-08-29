/*-
 * Copyright 2017-2022 elementary, Inc. (https://elementary.io)
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
 * Authored by: Danielle Foré <danielle@elementary.io>
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
        var facebook_button = new Gtk.Button.from_icon_name ("online-account-facebook", Gtk.IconSize.DND) {
            tooltip_text = _("Facebook")
        };

        var twitter_button = new Gtk.Button.from_icon_name ("online-account-twitter", Gtk.IconSize.DND) {
            tooltip_text = _("Twitter")
        };

        var reddit_button = new Gtk.Button.from_icon_name ("online-account-reddit", Gtk.IconSize.DND) {
            tooltip_text = _("Reddit")
        };

        var tumblr_button = new Gtk.Button.from_icon_name ("online-account-tumblr", Gtk.IconSize.DND) {
            tooltip_text = _("Tumblr")
        };

        var telegram_button = new Gtk.Button.from_icon_name ("online-account-telegram", Gtk.IconSize.DND) {
            tooltip_text = _("Telegram")
        };

        var copy_link_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
            tooltip_text = _("Copy link")
        };

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        size_group.add_widget (facebook_button);
        size_group.add_widget (copy_link_button);

        var service_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };

        var mail_appinfo = AppInfo.get_default_for_uri_scheme ("mailto");
        if (mail_appinfo != null) {
            var email_button = new Gtk.Button () {
                image = new Gtk.Image.from_gicon (mail_appinfo.get_icon (), Gtk.IconSize.DND),
                tooltip_text = mail_appinfo.get_display_name ()
            };

            service_box.add (email_button);

            email_button.clicked.connect (() => {
                show_uri ("mailto:?subject=%s&body=%s".printf (body, uri));
            });
        }

        service_box.add (facebook_button);
        service_box.add (twitter_button);
        service_box.add (reddit_button);
        service_box.add (tumblr_button);
        service_box.add (telegram_button);

        var system_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        system_box.add (copy_link_button);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.add (service_box);
        box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        box.add (system_box);
        box.show_all ();

        add (box);

        copy_link_button.clicked.connect (() => {
            var clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
            clipboard.set_text (uri, -1);

            link_copied ();

            popdown ();
        });

        facebook_button.clicked.connect (() => {
            show_uri ("https://www.facebook.com/sharer/sharer.php?u=%s".printf (uri));
        });

        twitter_button.clicked.connect (() => {
            show_uri ("https://twitter.com/intent/tweet?text=%s&url=%s".printf (body, uri));
        });

        reddit_button.clicked.connect (() => {
            show_uri ("http://www.reddit.com/submit?title=%s&url=%s".printf (body, uri));
        });

        tumblr_button.clicked.connect (() => {
            show_uri ("https://www.tumblr.com/share/link?url=%s".printf (uri));
        });

        telegram_button.clicked.connect (() => {
            show_uri ("https://t.me/share/url?url=%s".printf (uri));
        });
    }

    private void show_uri (string uri) {
        var main_window = ((Gtk.Application) Application.get_default ()).active_window;
        try {
            Gtk.show_uri_on_window (main_window, uri, Gdk.CURRENT_TIME);
        } catch (Error e) {
            critical (e.message);
        }

        popdown ();
    }
}
