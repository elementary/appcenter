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
        var facebook_button = new Gtk.Button.from_icon_name ("online-account-facebook") {
            tooltip_text = _("Facebook")
        };

        var twitter_button = new Gtk.Button.from_icon_name ("online-account-twitter") {
            tooltip_text = _("Twitter")
        };

        var reddit_button = new Gtk.Button.from_icon_name ("online-account-reddit") {
            tooltip_text = _("Reddit")
        };

        var tumblr_button = new Gtk.Button.from_icon_name ("online-account-tumblr") {
            tooltip_text = _("Tumblr")
        };

        var telegram_button = new Gtk.Button.from_icon_name ("online-account-telegram") {
            tooltip_text = _("Telegram")
        };

        var copy_link_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
            tooltip_text = _("Copy link")
        };
        ((Gtk.Image) copy_link_button.child).pixel_size = 24;

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        size_group.add_widget (facebook_button);
        size_group.add_widget (copy_link_button);

        var service_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        service_box.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var mail_appinfo = AppInfo.get_default_for_uri_scheme ("mailto");
        if (mail_appinfo != null) {
            var email_button = new Gtk.Button () {
                child = new Gtk.Image.from_gicon (mail_appinfo.get_icon ()),
                tooltip_text = mail_appinfo.get_display_name ()
            };
            email_button.add_css_class ("image-button");

            service_box.append (email_button);

            email_button.clicked.connect (() => {
                show_uri ("mailto:?subject=%s&body=%s".printf (body, uri));
            });
        }

        service_box.append (facebook_button);
        service_box.append (twitter_button);
        service_box.append (reddit_button);
        service_box.append (tumblr_button);
        service_box.append (telegram_button);

        var system_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        system_box.append (copy_link_button);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (service_box);
        box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        box.append (system_box);

        child = box;

        copy_link_button.clicked.connect (() => {
            Gdk.Display.get_default ().get_clipboard ().set_text (uri);
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
        Gtk.show_uri (main_window, uri, Gdk.CURRENT_TIME);
        popdown ();
    }
}
