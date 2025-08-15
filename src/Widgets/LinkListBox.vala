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
            string? license_description = null;
            string? license_url = null;
            parse_license (project_license, homepage_url, out license_label, out license_description, out license_url);

            contribute_listbox.append (new LinkRow (
                license_url,
                license_label,
                "text-x-copying-symbolic",
                "slate",
                license_description
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

    private void parse_license (
            string project_license,
            string project_homepage,
            out string license_copy,
            out string license_description,
            out string license_url
    ) {
        license_copy = null;
        license_url = null;
        license_description = null;
        string? developer_name = component.get_developer ().get_name ();
        if (developer_name == null) {
            developer_name = component.get_pkgname ();
        }

        if (project_license == null || project_license == "") {
            license_copy = _("No License");
            license_description = _("Contact %s for licensing information").printf (developer_name);
            license_url = project_homepage;
            return;
        }

        var spdx_license = AppStream.license_to_spdx_id (project_license);
        var token_array = AppStream.spdx_license_tokenize (spdx_license);
        var simple_license_tokens = simplify_license_tokens (token_array);

        if (simple_license_tokens.length > 1) {
            // TRANSLATORS: delimiter for a list of software licenses
            var joined_license_tokens = string.joinv (_(", "), simple_license_tokens);
            license_copy = _("Mixed License");
            license_description = joined_license_tokens;
            license_url = project_homepage;
            return;
        }

        // We can assume only one token exists from here onward
        license_url = AppStream.get_license_url (project_license);

        if (AppStream.license_is_free_license (project_license)) {
            var sanitized_license = project_license;
            if (AppStream.is_spdx_license_id (project_license)) {
                sanitized_license = AppStream.get_license_name (project_license);
            }
            license_copy = _("Free Software");
            license_description = AppStream.get_license_name (project_license);
            if (license_url == null) {
                // TRANSLATORS: Replace the link with the version for your language
                license_url = _("https://www.gnu.org/philosophy/free-sw");
            }
            return;
        }

        if (project_license.down ().contains ("proprietary")) {
            license_copy = _("Proprietary Software");
            if (license_url == null) {
                // TRANSLATORS: Replace the link with the version for your language
                license_url = _("https://www.gnu.org/proprietary/proprietary.en.html");
            }
            return;
        }

        if (project_license.down ().contains ("public-domain")) {
            license_copy = _("Public Domain");
            if (license_url == null) {
                // TRANSLATORS: Replace the link with the version for your language
                license_url = _("https://en.wikipedia.org/wiki/Public_domain");
            }
            return;
        }

        license_copy = _("Custom License");
        if (AppStream.is_spdx_license_id (project_license)) {
            license_description = AppStream.get_license_name (project_license);
        } else {
            license_description = _("Contact %s for licensing information").printf (developer_name);
        }
        if (license_url == null) {
            license_url = project_homepage;
        }
    }

    private string[] simplify_license_tokens (string[] spdx_license_tokens) {
        var final_token_list = new Gee.ArrayList<string> ();
        for (int i = 0; i < spdx_license_tokens.length; i++) {
            string sanitized_token;
            try {
                var regex = new GLib.Regex ("[@+\\(\\)\\^]");
                sanitized_token = regex.replace_literal (spdx_license_tokens[i], -1, 0, "");
            } catch (RegexError e) {
                sanitized_token = spdx_license_tokens[i];
            }

            if (AppStream.get_license_name (sanitized_token) != null) {
                final_token_list.add (sanitized_token);
            } else if (sanitized_token.down ().contains ("public-domain")) {
                final_token_list.add (_("Public Domain"));
            } else if (sanitized_token.down ().contains ("propietary")) {
                final_token_list.add (_("Proprietary"));
            }
        }

        return final_token_list.to_array ();
    }

    private class LinkRow : Gtk.ListBoxRow {
        public string uri_or_key { get; construct; }
        public string icon_name { get; construct; }
        public string label_string { get; construct; }
        public string? label_description { get; construct; }
        public string color { get; construct; }

        public LinkRow (string uri_or_key, string label_string, string icon_name, string color, string? label_description = null) {
            Object (
                uri_or_key: uri_or_key,
                label_string: label_string,
                icon_name: icon_name,
                color: color,
                label_description: label_description
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

            var description_label = new Gtk.Label (label_description == null ? uri_or_key : label_description) {
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
