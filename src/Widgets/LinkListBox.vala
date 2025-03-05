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
            accessible_role = GENERIC,
            hexpand = true,
            show_separators = true,
            selection_mode = NONE,
            valign = START
        };
        contact_listbox.add_css_class ("boxed-list");
        contact_listbox.add_css_class (Granite.STYLE_CLASS_RICH_LIST);

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
            accessible_role = GENERIC,
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
        if (payments_key != null) {
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

        var contribute_url = component.get_url (CONTRIBUTE);
        if (contribute_url != null) {
            contribute_listbox.append (new LinkRow (
                contribute_url,
                _("Get Involved"),
                "link-contribute-symbolic",
                "green"
            ));
        }

        var flowbox = new Gtk.FlowBox () {
            column_spacing = 24,
            max_children_per_line = 2,
            row_spacing = 24,
            selection_mode = NONE
        };
        flowbox.set_parent (this);

        if (contribute_listbox.get_first_child () != null) {
            flowbox.append (contribute_listbox);
        }

        if (contact_listbox.get_first_child () != null) {
            flowbox.append (contact_listbox);
        }

        // Workaround for bug where listboxes won't expand if there's only one of them
        if (flowbox.get_first_child ().get_next_sibling () == null) {
            flowbox.max_children_per_line = 1;
        }

        // Don't let container get focus, only actionable wigets get focus
        var flowbox_child = flowbox.get_first_child ();
        while (flowbox_child != null) {
            flowbox_child.focusable = false;
            flowbox_child = flowbox_child.get_next_sibling ();
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

        construct {
            var image = new Gtk.Image.from_icon_name (icon_name);
            image.add_css_class (Granite.STYLE_CLASS_ACCENT);
            image.add_css_class (color);

            var title_label = new Gtk.Label (label_string) {
                hexpand = true,
                xalign = 0
            };

            var description_label = new Gtk.Label (uri_or_key) {
                wrap = true,
                xalign = 0
            };
            description_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            description_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

            var link_image = new Gtk.Image.from_icon_name ("adw-external-link-symbolic");

            var grid = new Gtk.Grid () {
                valign = CENTER
            };
            grid.attach (image, 0, 0, 1, 2);
            grid.attach (title_label, 1, 0);
            grid.attach (description_label, 1, 1);
            grid.attach (link_image, 2, 0, 1, 2);

            accessible_role = LINK;
            child = grid;
            add_css_class ("link");

            if (is_stripe_key (uri_or_key)) {
                description_label.label = _("Payment provided by Stripe");
                link_image.icon_name = "payment-card-symbolic";
                accessible_role = BUTTON;
                update_property (Gtk.AccessibleProperty.HAS_POPUP, true, -1);
            }

            update_property (
                Gtk.AccessibleProperty.LABEL, title_label.label,
                Gtk.AccessibleProperty.DESCRIPTION, description_label.label,
                -1
            );
        }

        public void launch (AppStream.Component component) {
            if (!is_stripe_key (uri_or_key)) {
                var uri_launcher = new Gtk.UriLauncher (uri_or_key);
                uri_launcher.launch.begin (
                    ((Gtk.Application) GLib.Application.get_default ()).active_window,
                    null
                );
                return;
            }

            var stripe_dialog = new Widgets.StripeDialog (
                1,
                component.get_name (),
                component.id,
                uri_or_key
            ) {
                modal = true,
                transient_for = ((Gtk.Application) Application.get_default ()).active_window
            };
            stripe_dialog.present ();
        }

        private bool is_stripe_key (string uri_or_key) {
            return uri_or_key.has_prefix ("pk_live");
        }
    }
}
