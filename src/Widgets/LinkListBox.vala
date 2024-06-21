/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2024 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.LinkListBox : Gtk.Widget {
    public unowned AppStream.Component component { get; construct; }

    public LinkListBox (AppStream.Component component) {
        Object (component: component);
    }

    class construct {
        set_css_name ("linklistbox");
    }

    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    construct {
        var contact_listbox = new Gtk.ListBox () {
            hexpand = true,
            show_separators = true,
            selection_mode = NONE,
            valign = START
        };
        contact_listbox .add_css_class ("boxed-list");
        contact_listbox .add_css_class (Granite.STYLE_CLASS_RICH_LIST);

        var homepage_url = component.get_url (HOMEPAGE);
        if (homepage_url != null) {
            contact_listbox.append (new LinkRow (
                homepage_url,
                _("Website"),
                "web-browser-symbolic",
                "slate"
            ));
        }

        var help_url = component.get_url (HELP);
        if (help_url != null) {
            contact_listbox.append (new LinkRow (
                help_url,
                _("Get Help"),
                "help-contents-symbolic",
                "blue"
            ));
        }

        var bugtracker_url = component.get_url (BUGTRACKER);
        if (bugtracker_url != null) {
            contact_listbox.append (new LinkRow (
                bugtracker_url,
                _("Send Feedback"),
                "bug-symbolic",
                "green"
            ));
        }

        var contact_url = component.get_url (CONTACT);
        if (contact_url != null) {
            contact_listbox.append (new LinkRow (
                contact_url,
                _("Contact The Developer"),
                "mail-send-symbolic",
                "yellow"
            ));
        }

        var contribute_listbox = new Gtk.ListBox () {
            hexpand = true,
            show_separators = true,
            selection_mode = NONE,
            valign = START
        };
        contribute_listbox.add_css_class ("boxed-list");
        contribute_listbox.add_css_class (Granite.STYLE_CLASS_RICH_LIST);

        var project_license = component.project_license;
        if (project_license != null) {
            string? license_label = null;
            string? license_url = null;
            parse_license (project_license, out license_label, out license_url);

            contribute_listbox.append (new LinkRow (
                license_url,
                _(license_label),
                "text-x-copying-symbolic",
                "slate"
            ));
        }

        var sponsor_url = component.get_url (DONATION);
#if PAYMENTS
        var payments_key = component.get_custom_value ("x-appcenter-stripe");
        if (payments_key  != null) {
            sponsor_url = payments_key;
        }
#endif
        if (sponsor_url != null) {
            contribute_listbox.append (new LinkRow (
                sponsor_url,
                _("Sponsor"),
                "face-heart-symbolic",
                "pink"
            ));
        }

        var translate_url = component.get_url (TRANSLATE);
        if (translate_url != null) {
            contribute_listbox.append (new LinkRow (
                translate_url,
                _("Contribute Translations"),
                "preferences-desktop-locale-symbolic",
                "blue"
            ));
        }

        var vcs_url = component.get_url (VCS_BROWSER);
        if (vcs_url != null) {
            contribute_listbox.append (new LinkRow (
                vcs_url,
                _("Get The Source Code"),
                "link-vcs-symbolic",
                "purple"
            ));
        }

        var box = new Gtk.Box (HORIZONTAL, 0) {
            homogeneous = true
        };
        box.set_parent (this);

        if (contribute_listbox.get_first_child != null) {
            box.append (contribute_listbox);
        }

        if (contact_listbox.get_first_child != null) {
            box.append (contact_listbox);
        }

        contact_listbox.row_activated.connect ((row) => {
            ((LinkRow) row).launch (component);
        });

        contribute_listbox.row_activated.connect ((row) => {
            ((LinkRow) row).launch (component);
        });
    }

    ~LinkListBox () {
        get_first_child ().unparent ();
    }

    private void parse_license (string project_license, out string license_copy, out string license_url) {
        license_copy = null;
        license_url = null;

        // NOTE: Ideally this would be handled in AppStream: https://github.com/ximion/appstream/issues/107
        if (project_license.has_prefix ("LicenseRef")) {
            // i.e. `LicenseRef-proprietary=https://example.com`
            string[] split_license = project_license.split_set ("=", 2);
            if (split_license[1] != null) {
                license_url = split_license[1];
            }

            string license_type = split_license[0].split_set ("-", 2)[1].down ();
            switch (license_type) {
                case "public-domain":
                    // TRANSLATORS: See the Wikipedia page
                    license_copy = _("Public Domain");
                    if (license_url == null) {
                        // TRANSLATORS: Replace the link with the version for your language
                        license_url = _("https://en.wikipedia.org/wiki/Public_domain");
                    }
                    break;
                case "free":
                    // TRANSLATORS: Freedom, not price. See the GNU page.
                    license_copy = _("Free Software");
                    if (license_url == null) {
                        // TRANSLATORS: Replace the link with the version for your language
                        license_url = _("https://www.gnu.org/philosophy/free-sw");
                    }
                    break;
                case "proprietary":
                    license_copy = _("Proprietary");
                    break;
                default:
                    license_copy = _("Unknown License");
                    break;
            }
        } else {
            license_copy = AppStream.get_license_name (project_license);
            license_url = AppStream.get_license_url (project_license);
        }
    }

    private class LinkRow : Gtk.ListBoxRow {
        public string uri_or_key { get; construct; }
        public string icon_name { get; construct; }
        public string label_string { get; construct; }
        public string color { get; construct; }

        public LinkRow (string uri_or_key, string label_string, string icon_name, string color) {
            Object (
                uri_or_key: uri_or_key,
                label_string: label_string,
                icon_name: icon_name,
                color: color
            );
        }

        class construct {
            set_accessible_role (LINK);
        }

        construct {
            var image = new Gtk.Image.from_icon_name (icon_name);
            image.add_css_class (Granite.STYLE_CLASS_ACCENT);
            image.add_css_class (color);

            var left_label = new Gtk.Label (label_string) {
                hexpand = true,
                xalign = 0
            };

            var link_image = new Gtk.Image.from_icon_name ("adw-external-link-symbolic");

            var box = new Gtk.Box (HORIZONTAL, 0);
            box.append (image);
            box.append (left_label);
            box.append (link_image);

            child = box;
            add_css_class ("link");
        }

        public void launch (AppStream.Component component) {
            if (uri_or_key.has_prefix ("http") || uri_or_key.has_prefix ("mailto")) {
                var uri_launcher = new Gtk.UriLauncher (uri_or_key);
                uri_launcher.launch.begin (
                    ((Gtk.Application) GLib.Application.get_default ()).active_window,
                    null
                );
                return;
            }

            var component_id = component.id;
            if (component_id.has_suffix (".desktop")) {
                // ".desktop" is always 8 bytes in UTF-8 so we can just chop 8 bytes off the end
                component_id = component_id.substring (0, component_id.length - 8);
            }

            var stripe_dialog = new Widgets.StripeDialog (
                1,
                component.get_name (),
                component_id,
                uri_or_key
            ) {
                modal = true,
                transient_for = ((Gtk.Application) Application.get_default ()).active_window
            };

            stripe_dialog.download_requested.connect (() => {
                if (stripe_dialog.amount != 0) {
                    App.add_paid_app (component.get_id ());
                }
            });

            stripe_dialog.present ();
        }
    }
}

