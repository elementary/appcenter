/*
 * Copyright 2014–2021 elementary, Inc. (https://elementary.io)
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
 */

namespace AppCenter.Views {
    public class AppInfoView : AppCenter.AbstractAppContainer {
        public const int MAX_WIDTH = 800;

        public signal void show_other_package (
            AppCenterCore.Package package,
            bool remember_history = true,
            Gtk.StackTransitionType transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        );

        private static Gtk.CssProvider banner_provider;
        private static Gtk.CssProvider loading_provider;
        private static Gtk.CssProvider? previous_css_provider = null;

        GenericArray<AppStream.Screenshot> screenshots;

        private Gtk.ComboBox origin_combo;
        private Gtk.Grid release_grid;
        private Gtk.Label app_screenshot_not_found;
        private Gtk.Label package_summary;
        private Gtk.Label author_label;
        private Gtk.ListBox extension_box;
        private Gtk.ListStore origin_liststore;
        private Gtk.Overlay screenshot_overlay;
        private Gtk.Revealer origin_combo_revealer;
        private Hdy.Carousel app_screenshots;
        private Gtk.Stack screenshot_stack;
        private Gtk.Label app_description;
        private Widgets.ReleaseListBox release_list_box;
        private Widgets.SizeLabel size_label;
        private Hdy.CarouselIndicatorDots screenshot_switcher;
        private ArrowButton screenshot_next;
        private ArrowButton screenshot_previous;

        private unowned Gtk.StyleContext stack_context;

        public bool to_recycle { public get; private set; default = false; }

        public AppInfoView (AppCenterCore.Package package) {
            Object (package: package);
        }

        static construct {
            banner_provider = new Gtk.CssProvider ();
            banner_provider.load_from_resource ("io/elementary/appcenter/banner.css");

            loading_provider = new Gtk.CssProvider ();
            loading_provider.load_from_resource ("io/elementary/appcenter/loading.css");
        }

        construct {
            AppCenterCore.BackendAggregator.get_default ().cache_flush_needed.connect (() => {
                to_recycle = true;
            });

            action_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            var package_component = package.component;

            var drugs = new ContentType (
                _("Illicit Substances"),
                _("Presence of or references to alcohol, narcotics, or tobacco"),
                "oars-illicit-substance-symbolic"
            );

            var sex_nudity = new ContentType (
                _("Sex & Nudity"),
                _("Adult nudity or sexual themes"),
                "oars-sex-nudity-symbolic"
            );

            var language = new ContentType (
                _("Offensive Language"),
                _("Profanity, discriminatory language, or adult humor"),
                "oars-offensive-language-symbolic"
            );

            var gambling = new ContentType (
                _("Gambling"),
                _("Realistic or participatory gambling"),
                "oars-gambling-symbolic"
            );

            var oars_flowbox = new Gtk.FlowBox () {
                column_spacing = 24,
                margin_bottom = 24,
                row_spacing = 24,
                selection_mode = Gtk.SelectionMode.NONE
            };

#if CURATED
            if (!package.is_native && !package.is_os_updates) {
                var uncurated = new ContentType (
                    _("Non-Curated"),
                    _("Not reviewed by elementary for security, privacy, or system integration"),
                    "security-low-symbolic"
                );

                oars_flowbox.add (uncurated);
            }
#endif

            var ratings = package_component.get_content_ratings ();
            for (int i = 0; i < ratings.length; i++) {
                var rating = ratings[i];

                var fantasy_violence_value = rating.get_value ("violence-fantasy");
                var realistic_violence_value = rating.get_value ("violence-realistic");

                if (
                    fantasy_violence_value == AppStream.ContentRatingValue.MILD ||
                    fantasy_violence_value == AppStream.ContentRatingValue.MODERATE ||
                    realistic_violence_value == AppStream.ContentRatingValue.MILD ||
                    realistic_violence_value == AppStream.ContentRatingValue.MODERATE
                ) {
                    var conflict = new ContentType (
                        _("Conflict"),
                        _("Depictions of unsafe situations or aggressive conflict"),
                        "oars-conflict-symbolic"
                    );

                    oars_flowbox.add (conflict);
                }

                if (
                    fantasy_violence_value == AppStream.ContentRatingValue.INTENSE ||
                    realistic_violence_value == AppStream.ContentRatingValue.INTENSE ||
                    rating.get_value ("violence-bloodshed") > AppStream.ContentRatingValue.NONE ||
                    rating.get_value ("violence-sexual") > AppStream.ContentRatingValue.NONE
                ) {
                    string? title = _("Violence");
                    if (
                        fantasy_violence_value == AppStream.ContentRatingValue.INTENSE &&
                        realistic_violence_value < AppStream.ContentRatingValue.INTENSE
                    ) {
                        title = _("Fantasy Violence");
                    }

                    var violence = new ContentType (
                        title,
                        _("Graphic violence, bloodshed, or death"),
                        "oars-violence-symbolic"
                    );

                    oars_flowbox.add (violence);
                }

                if (
                    rating.get_value ("drugs-narcotics") > AppStream.ContentRatingValue.NONE
                ) {
                    oars_flowbox.add (drugs);
                }

                if (
                    rating.get_value ("sex-nudity") > AppStream.ContentRatingValue.NONE ||
                    rating.get_value ("sex-themes") > AppStream.ContentRatingValue.NONE ||
                    rating.get_value ("sex-prostitution") > AppStream.ContentRatingValue.NONE
                ) {
                    oars_flowbox.add (sex_nudity);
                }

                if (
                    // Mild is considered things like "Dufus"
                    rating.get_value ("language-profanity") > AppStream.ContentRatingValue.MILD ||
                    // Mild is considered things like slapstick humor
                    rating.get_value ("language-humor") > AppStream.ContentRatingValue.MILD ||
                    rating.get_value ("language-discrimination") > AppStream.ContentRatingValue.NONE
                ) {
                    oars_flowbox.add (language);
                }

                if (
                    rating.get_value ("money-gambling") > AppStream.ContentRatingValue.NONE
                ) {
                    oars_flowbox.add (gambling);
                }

                var social_chat_value = rating.get_value ("social-chat");
                // MILD is defined as multi-player period, no chat
                if (
                    social_chat_value > AppStream.ContentRatingValue.NONE &&
                    package.component.has_category ("Game")
                ) {
                    var multiplayer = new ContentType (
                        _("Multiplayer"),
                        _("Online play with other people"),
                        "system-users-symbolic"
                    );

                    oars_flowbox.add (multiplayer);
                }

                var social_audio_value = rating.get_value ("social-audio");
                if (
                    social_chat_value > AppStream.ContentRatingValue.MILD ||
                    social_audio_value > AppStream.ContentRatingValue.NONE
                ) {

                    // social-audio in OARS includes video as well
                    string? description = null;
                    if (social_chat_value == AppStream.ContentRatingValue.INTENSE || social_audio_value == AppStream.ContentRatingValue.INTENSE) {
                        description = _("Unmoderated Audio, Video, or Text messaging with other people");
                    } else if (social_chat_value == AppStream.ContentRatingValue.MODERATE || social_audio_value == AppStream.ContentRatingValue.MODERATE) {
                        description = _("Moderated Audio, Video, or Text messaging with other people");
                    }

                    var social = new ContentType (
                        _("Online Interactions"),
                        description,
                        "oars-chat-symbolic"
                    );

                    oars_flowbox.add (social);
                }

                if (rating.get_value ("social-location") > AppStream.ContentRatingValue.NONE) {
                    var location = new ContentType (
                        _("Location Sharing"),
                        _("Other people can see your real-world location"),
                        "find-location-symbolic"
                    );

                    oars_flowbox.add (location);
                }

                var social_info_value = rating.get_value ("social-info");
                if (social_info_value > AppStream.ContentRatingValue.MILD) {
                    string? description = null;
                    switch (social_info_value) {
                        case AppStream.ContentRatingValue.MODERATE:
                            description = _("Collects anonymous usage data");
                            break;
                        case AppStream.ContentRatingValue.INTENSE:
                            description = _("Collects usage data that could be used to identify you");
                            break;
                    }

                    var social_info = new ContentType (
                        _("Info Sharing"),
                        description,
                        "oars-socal-info-symbolic"
                    );

                    oars_flowbox.add (social_info);
                }
            }

            screenshots = package_component.get_screenshots ();

            if (screenshots.length > 0) {
                app_screenshots = new Hdy.Carousel () {
                    height_request = 500
                };

                screenshot_previous = new ArrowButton ("go-previous-symbolic") {
                    sensitive = false,
                    no_show_all = true
                };
                screenshot_previous.clicked.connect (() => {
                    GLib.List<unowned Gtk.Widget> screenshot_children = app_screenshots.get_children ();
                    var index = app_screenshots.get_position ();
                    if (index > 0) {
                        app_screenshots.scroll_to (screenshot_children.nth_data ((uint) index - 1));
                    }
                });

                screenshot_next = new ArrowButton ("go-next-symbolic") {
                    no_show_all = true
                };
                screenshot_next.clicked.connect (() => {
                    GLib.List<unowned Gtk.Widget> screenshot_children = app_screenshots.get_children ();
                    var index = app_screenshots.get_position ();
                    if (index < screenshot_children.length () - 1) {
                        app_screenshots.scroll_to (screenshot_children.nth_data ((uint) index + 1));
                    }
                });

                app_screenshots.page_changed.connect ((index) => {
                    screenshot_previous.sensitive = screenshot_next.sensitive = true;

                    GLib.List<unowned Gtk.Widget> screenshot_children = app_screenshots.get_children ();

                    if (index == 0) {
                        screenshot_previous.sensitive = false;
                    } else if (index == screenshot_children.length () - 1) {
                        screenshot_next.sensitive = false;
                    }
                });

                var screenshot_arrow_revealer_p = new Gtk.Revealer () {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.CENTER,
                    transition_type = Gtk.RevealerTransitionType.CROSSFADE
                };
                screenshot_arrow_revealer_p.add (screenshot_previous);

                var screenshot_arrow_revealer_n = new Gtk.Revealer () {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.CENTER,
                    transition_type = Gtk.RevealerTransitionType.CROSSFADE
                };
                screenshot_arrow_revealer_n.add (screenshot_next);

                screenshot_overlay = new Gtk.Overlay ();
                screenshot_overlay.add (app_screenshots);
                screenshot_overlay.add_overlay (screenshot_arrow_revealer_p);
                screenshot_overlay.add_overlay (screenshot_arrow_revealer_n);

                app_screenshots.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK);
                app_screenshots.add_events (Gdk.EventMask.LEAVE_NOTIFY_MASK);
                screenshot_overlay.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK);
                screenshot_overlay.add_events (Gdk.EventMask.LEAVE_NOTIFY_MASK);

                screenshot_overlay.enter_notify_event.connect (() => {
                    screenshot_arrow_revealer_n.reveal_child = true;
                    screenshot_arrow_revealer_p.reveal_child = true;
                    return false;
                });

                screenshot_overlay.leave_notify_event.connect ((event) => {
                    // Prevent hiding prev/next button when they're marked as insensitive
                    if (event.mode != Gdk.CrossingMode.STATE_CHANGED) {
                        screenshot_arrow_revealer_n.reveal_child = false;
                        screenshot_arrow_revealer_p.reveal_child = false;
                    }

                    return false;
                });

                app_screenshots.enter_notify_event.connect (() => {
                    screenshot_arrow_revealer_n.reveal_child = true;
                    screenshot_arrow_revealer_p.reveal_child = true;
                    return false;
                });

                app_screenshots.leave_notify_event.connect ((event) => {
                    // Prevent hiding prev/next button when they're marked as insensitive
                    if (event.mode != Gdk.CrossingMode.STATE_CHANGED) {
                        screenshot_arrow_revealer_n.reveal_child = false;
                        screenshot_arrow_revealer_p.reveal_child = false;
                    }

                    return false;
                });

                screenshot_switcher = new Hdy.CarouselIndicatorDots () {
                    carousel = app_screenshots
                };

                var app_screenshot_spinner = new Gtk.Spinner () {
                    active = true,
                    halign = Gtk.Align.CENTER,
                    valign = Gtk.Align.CENTER
                };

                app_screenshot_not_found = new Gtk.Label (_("Screenshot Not Available"));
                app_screenshot_not_found.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                app_screenshot_not_found.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

                screenshot_stack = new Gtk.Stack () {
                    transition_type = Gtk.StackTransitionType.CROSSFADE
                };
                screenshot_stack.add (app_screenshot_spinner);
                screenshot_stack.add (screenshot_overlay);
                screenshot_stack.add (app_screenshot_not_found);

                stack_context = screenshot_stack.get_style_context ();
                stack_context.add_class (Gtk.STYLE_CLASS_BACKGROUND);
                stack_context.add_class ("loading");
                stack_context.add_provider (loading_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }

            var app_icon = new Gtk.Image () {
                margin_top = 12,
                pixel_size = 128
            };

            var badge_image = new Gtk.Image () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END,
                pixel_size = 64
            };

            var app_icon_overlay = new Gtk.Overlay ();
            app_icon_overlay.add (app_icon);

            var scale_factor = get_scale_factor ();

            var plugin_host_package = package.get_plugin_host_package ();
            if (package.is_plugin && plugin_host_package != null) {
                app_icon.gicon = plugin_host_package.get_icon (app_icon.pixel_size, scale_factor);
                badge_image.gicon = package.get_icon (badge_image.pixel_size / 2, scale_factor);

                app_icon_overlay.add_overlay (badge_image);
            } else {
                app_icon.gicon = package.get_icon (app_icon.pixel_size, scale_factor);

                if (package.is_os_updates) {
                    badge_image.icon_name = "system-software-update";
                    app_icon_overlay.add_overlay (badge_image);
                }
            }

            var package_name = new Gtk.Label (package.get_name ()) {
                ellipsize = Pango.EllipsizeMode.MIDDLE,
                selectable = true,
                valign = Gtk.Align.END,
                xalign = 0
            };
            package_name.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

            author_label = new Gtk.Label (null) {
                selectable = true,
                valign = Gtk.Align.START,
                xalign = 0
            };
            author_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            package_summary = new Gtk.Label (null) {
                label = package.get_summary (),
                selectable = true,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                valign = Gtk.Align.CENTER,
                xalign = 0
            };
            package_summary.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            app_description = new Gtk.Label (null) {
                // Allow wrapping but prevent expanding the parent
                width_request = 1,
                wrap = true,
                xalign = 0
            };
            app_description.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            var links_grid = new Gtk.Grid () {
                column_spacing = 12
            };

            var project_license = package.component.project_license;
            if (project_license != null) {
                string? license_copy = null;
                string? license_url = null;

                parse_license (project_license, out license_copy, out license_url);

                var license_button = new UrlButton (_(license_copy), license_url, "text-x-copying-symbolic") {
                    hexpand = true
                };

                links_grid.add (license_button);
            }

            var homepage_url = package_component.get_url (AppStream.UrlKind.HOMEPAGE);
            if (homepage_url != null) {
                var website_button = new UrlButton (_("Homepage"), homepage_url, "web-browser-symbolic");
                links_grid.add (website_button);
            }

            var translate_url = package_component.get_url (AppStream.UrlKind.TRANSLATE);
            if (translate_url != null) {
                var translate_button = new UrlButton (_("Translate"), translate_url, "preferences-desktop-locale-symbolic");
                links_grid.add (translate_button);
            }

            var bugtracker_url = package_component.get_url (AppStream.UrlKind.BUGTRACKER);
            if (bugtracker_url != null) {
                var bugtracker_button = new UrlButton (_("Send Feedback"), bugtracker_url, "bug-symbolic");
                links_grid.add (bugtracker_button);
            }

            var help_url = package_component.get_url (AppStream.UrlKind.HELP);
            if (help_url != null) {
                var help_button = new UrlButton (_("Help"), help_url, "dialog-question-symbolic");
                links_grid.add (help_button);
            }

#if PAYMENTS
            if (package.get_payments_key () != null) {
                var fund_button = new FundButton (package);
                links_grid.add (fund_button);
            }
#endif

            var whats_new_label = new Gtk.Label (_("What's New:")) {
                xalign = 0
            };
            whats_new_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            release_list_box = new Widgets.ReleaseListBox (package);

            release_grid = new Gtk.Grid () {
                no_show_all = true,
                row_spacing = 12
            };
            release_grid.attach (whats_new_label, 0, 0);
            release_grid.attach (release_list_box, 0, 1);
            release_grid.hide ();

            var content_grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.VERTICAL,
                row_spacing = 24
            };

            if (oars_flowbox.get_children ().length () > 0) {
                content_grid.add (oars_flowbox);
            }

            if (screenshots.length > 0) {
                content_grid.add (screenshot_stack);
                content_grid.add (screenshot_switcher);
            }

            content_grid.add (package_summary);
            content_grid.add (app_description);
            content_grid.add (release_grid);

            if (package_component.get_addons ().length > 0) {
                extension_box = new Gtk.ListBox () {
                    selection_mode = Gtk.SelectionMode.SINGLE
                };

                extension_box.row_activated.connect ((row) => {
                    var extension_row = row as Widgets.PackageRow;
                    if (extension_row != null) {
                        show_other_package (extension_row.get_package ());
                    }
                });

                var extension_label = new Gtk.Label (_("Extensions:")) {
                    halign = Gtk.Align.START,
                    margin_top = 12
                };
                extension_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

                content_grid.add (extension_label);
                content_grid.add (extension_box);
                load_extensions.begin ();
            }

            content_grid.add (links_grid);

            origin_liststore = new Gtk.ListStore (2, typeof (AppCenterCore.Package), typeof (string));
            origin_combo = new Gtk.ComboBox.with_model (origin_liststore) {
                halign = Gtk.Align.START,
                valign = Gtk.Align.START
            };

            origin_combo_revealer = new Gtk.Revealer ();
            origin_combo_revealer.add (origin_combo);

            var renderer = new Gtk.CellRendererText ();
            origin_combo.pack_start (renderer, true);
            origin_combo.add_attribute (renderer, "text", 1);

            action_stack.valign = Gtk.Align.END;
            action_stack.halign = Gtk.Align.END;
            action_stack.hexpand = true;

            /* This is required to stop any button movement when switch from button_grid to the
             * progress grid */
            progress_grid.margin_end = 6;
            progress_grid.margin_top = 12;
            button_grid.margin_top = progress_grid.margin_top;

            var header_grid = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 6,
                hexpand = true
            };
            header_grid.attach (app_icon_overlay, 0, 0, 1, 3);
            header_grid.attach (package_name, 1, 0);
            header_grid.attach (author_label, 1, 1);
            header_grid.attach (origin_combo_revealer, 1, 2, 3);
            header_grid.attach (action_stack, 3, 0);

            if (!package.is_local) {
                size_label = new Widgets.SizeLabel () {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.START
                };
                size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

                action_button_group.add_widget (size_label);

                header_grid.attach (size_label, 3, 1);
            }

            var header_clamp = new Hdy.Clamp () {
                margin = 24,
                maximum_size = MAX_WIDTH
            };
            header_clamp.add (header_grid);

            var header_box = new Gtk.Grid () {
                hexpand = true
            };
            header_box.get_style_context ().add_class ("banner");
            header_box.add (header_clamp);

            // FIXME: should be for context, not for screen
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (),
                banner_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            var body_clamp = new Hdy.Clamp () {
                margin = 24,
                maximum_size = MAX_WIDTH
            };
            body_clamp.add (content_grid);

            var other_apps_bar = new OtherAppsBar (package, MAX_WIDTH);

            other_apps_bar.show_other_package.connect ((package) => {
                show_other_package (package);
            });

            var grid = new Gtk.Grid () {
                row_spacing = 12
            };
            grid.attach (header_box, 0, 0);
            grid.attach (body_clamp, 0, 1);
            grid.attach (other_apps_bar, 0, 3);

            var scrolled = new Gtk.ScrolledWindow (null, null) {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                expand = true
            };
            scrolled.add (grid);

            var toast = new Granite.Widgets.Toast (_("Link copied to clipboard"));

            var overlay = new Gtk.Overlay ();
            overlay.add (scrolled);
            overlay.add_overlay (toast);

            add (overlay);

            open_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
#if SHARING
            if (package.is_shareable) {
                var body = _("Check out %s on AppCenter:").printf (package.get_name ());
                var uri = "https://appcenter.elementary.io/%s".printf (package.component.get_id ());
                var share_popover = new SharePopover (body, uri);

                var share_icon = new Gtk.Image.from_icon_name ("send-to-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
                    valign = Gtk.Align.CENTER
                };

                var share_label = new Gtk.Label (_("Share"));

                var share_grid = new Gtk.Grid () {
                    column_spacing = 6
                };
                share_grid.add (share_icon);
                share_grid.add (share_label);

                var share_button = new Gtk.MenuButton () {
                    direction = Gtk.ArrowType.UP,
                    popover = share_popover
                };
                share_button.add (share_grid);

                unowned var share_button_context = share_button.get_style_context ();
                share_button_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                share_button_context.add_class (Gtk.STYLE_CLASS_FLAT);

                share_popover.link_copied.connect (() => {
                    toast.send_notification ();
                });

                links_grid.add (share_button);
            }
#endif
            view_entered ();
            set_up_package ();

            origin_combo.changed.connect (() => {
                Gtk.TreeIter iter;
                AppCenterCore.Package selected_origin_package;
                origin_combo.get_active_iter (out iter);
                origin_liststore.@get (iter, 0, out selected_origin_package);
                if (selected_origin_package != null && selected_origin_package != package) {
                    show_other_package (selected_origin_package, false, Gtk.StackTransitionType.CROSSFADE);
                }
            });

            realize.connect (load_more_content);
        }

        protected override void update_state (bool first_update = false) {
            if (!package.is_local) {
                size_label.update ();
            }

            if (package.state == AppCenterCore.Package.State.NOT_INSTALLED) {
                get_app_download_size.begin ();
            }

            update_action ();
        }

        private async void load_extensions () {
            package.component.get_addons ().@foreach ((extension) => {
                var extension_package = package.backend.get_package_for_component_id (extension.id);
                if (extension_package == null) {
                    return;
                }

                var row = new Widgets.PackageRow.list (extension_package);
                if (extension_box != null) {
                    extension_box.add (row);
                }
            });
        }

        private async void get_app_download_size () {
            if (package.state == AppCenterCore.Package.State.INSTALLED || package.is_local) {
                return;
            }

            var size = yield package.get_download_size_including_deps ();
            size_label.update (size, package.is_flatpak);
        }

        public void view_entered () {
            Gtk.TreeIter iter;
            AppCenterCore.Package origin_package;
            if (origin_liststore.get_iter_first (out iter)) {
                do {
                    origin_liststore.@get (iter, 0, out origin_package);
                    if (origin_package == package) {
                        origin_combo.set_active_iter (iter);
                    }
                } while (origin_liststore.iter_next (ref iter));
            }

            var provider = new Gtk.CssProvider ();
            try {
                string? color_primary = null;
                string? color_primary_text = null;
                if (package != null) {
                    color_primary = package.get_color_primary ();
                    color_primary_text = package.get_color_primary_text ();
                }

                if (color_primary == null || color_primary_text == null) {
                    color_primary = DEFAULT_BANNER_COLOR_PRIMARY;
                    color_primary_text = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;
                }

                var colored_css = BANNER_STYLE_CSS.printf (color_primary, color_primary_text);
                provider.load_from_data (colored_css, colored_css.length);

                if (previous_css_provider != null) {
                    Gtk.StyleContext.remove_provider_for_screen (Gdk.Screen.get_default (), previous_css_provider);
                }

                previous_css_provider = provider;
                Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (GLib.Error e) {
                critical (e.message);
            }
        }

        private void load_more_content () {
            var cache = AppCenterCore.Client.get_default ().screenshot_cache;

            Gtk.TreeIter iter;
            uint count = 0;
            foreach (var origin_package in package.origin_packages) {
                origin_liststore.append (out iter);
                origin_liststore.set (iter, 0, origin_package, 1, origin_package.origin_description);
                if (origin_package == package) {
                    origin_combo.set_active_iter (iter);
                }

                count++;
                if (count > 1) {
                    origin_combo_revealer.reveal_child = true;
                }
            }

            new Thread<void*> ("content-loading", () => {
                var description = package.get_description ();
                Idle.add (() => {
                    if (package.is_os_updates) {
                        author_label.label = package.get_version ();
                    } else {
                        author_label.label = package.author_title;
                    }

                    if (description != null) {
                        app_description.label = description;
                    }
                    return false;
                });

                get_app_download_size.begin ();

                Idle.add (() => {
                    if (release_list_box.populate ()) {
                        release_grid.no_show_all = false;
                        release_grid.show_all ();
                    }

                    return false;
                });

                if (screenshots.length == 0) {
                    return null;
                }

                List<string> urls = new List<string> ();

                var scale = get_scale_factor ();
                var min_screenshot_width = MAX_WIDTH * scale;

                screenshots.foreach ((screenshot) => {
                    AppStream.Image? best_image = null;
                    screenshot.get_images ().foreach ((image) => {
                        // Image is better than no image
                        if (best_image == null) {
                            best_image = image;
                        }

                        // If our current best is less than the minimum and we have a bigger image, choose that instead
                        if (best_image.get_width () < min_screenshot_width && image.get_width () >= best_image.get_width ()) {
                            best_image = image;
                        }

                        // If our new image is smaller than the current best, but still bigger than the minimum, pick that
                        if (image.get_width () < best_image.get_width () && image.get_width () >= min_screenshot_width) {
                            best_image = image;
                        }
                    });

                    if (screenshot.get_kind () == AppStream.ScreenshotKind.DEFAULT && best_image != null) {
                        urls.prepend (best_image.get_url ());
                    } else if (best_image != null) {
                        urls.append (best_image.get_url ());
                    }
                });

                string?[] screenshot_files = new string?[urls.length ()];
                bool[] results = new bool[urls.length ()];
                int completed = 0;

                // Fetch each screenshot in parallel.
                for (int i = 0; i < urls.length (); i++) {
                    string url = urls.nth_data (i);
                    string? file = null;
                    int index = i;

                    cache.fetch.begin (url, (obj, res) => {
                        results[index] = cache.fetch.end (res, out file);
                        screenshot_files[index] = file;
                        completed++;
                    });
                }

                // TODO: dynamically load screenshots as they become available.
                while (urls.length () != completed) {
                    Thread.usleep (100000);
                }

                // Load screenshots that were successfully obtained.
                for (int i = 0; i < urls.length (); i++) {
                    if (results[i] == true) {
                        load_screenshot (screenshot_files[i]);
                    }
                }

                Idle.add (() => {
                    var number_of_screenshots = app_screenshots.get_children ().length ();

                    if (number_of_screenshots > 0) {
                        screenshot_stack.visible_child = screenshot_overlay;
                        stack_context.remove_class ("loading");

                        if (number_of_screenshots > 1) {
                            screenshot_next.no_show_all = false;
                            screenshot_next.show_all ();
                            screenshot_previous.no_show_all = false;
                            screenshot_previous.show_all ();
                        }
                    } else {
                        screenshot_stack.visible_child = app_screenshot_not_found;
                        stack_context.remove_class ("loading");
                    }

                    return GLib.Source.REMOVE;
                });

                return null;
            });
        }

        // We need to first download the screenshot locally so that it doesn't freeze the interface.
        private void load_screenshot (string path) {
            var scale_factor = get_scale_factor ();
            try {
                var pixbuf = new Gdk.Pixbuf.from_file_at_scale (path, MAX_WIDTH * scale_factor, 600 * scale_factor, true);
                var image = new Gtk.Image ();
                image.width_request = MAX_WIDTH;
                image.height_request = 500;
                image.icon_name = "image-x-generic";
                image.halign = Gtk.Align.CENTER;
                image.gicon = pixbuf;

                Idle.add (() => {
                    image.show ();
                    app_screenshots.add (image);
                    return GLib.Source.REMOVE;
                });
            } catch (Error e) {
                critical (e.message);
            }
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
                license_copy = project_license;
                license_url = "https://choosealicense.com/licenses/";

                switch (project_license) {
                    case "Apache-2.0":
                        license_url = license_url + "apache-2.0";
                        break;
                    case "GPL-2":
                    case "GPL-2.0":
                    case "GPL-2.0+":
                        license_url = license_url + "gpl-2.0";
                        break;
                    case "GPL-3":
                    case "GPL-3.0":
                    case "GPL-3.0+":
                        license_url = license_url + "gpl-3.0";
                        break;
                    case "LGPL-2.1":
                    case "LGPL-2.1+":
                        license_url = license_url + "lgpl-2.1";
                        break;
                    case "MIT":
                        license_url = license_url + "mit";
                        break;
                }
            }
        }

        class UrlButton : Gtk.Grid {
            public UrlButton (string label, string? uri, string icon_name) {
                get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                tooltip_text = uri;

                var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.SMALL_TOOLBAR) {
                    valign = Gtk.Align.CENTER
                };

                var title = new Gtk.Label (label) {
                    ellipsize = Pango.EllipsizeMode.END
                };

                var grid = new Gtk.Grid () {
                    column_spacing = 6
                };
                grid.add (icon);
                grid.add (title);

                if (uri != null) {
                    var button = new Gtk.Button ();
                    button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

                    button.add (grid);
                    add (button);

                    button.clicked.connect (() => {
                        try {
                            AppInfo.launch_default_for_uri (uri, null);
                        } catch (Error e) {
                            warning ("%s\n", e.message);
                        }
                    });
                } else {
                    add (grid);
                }
            }
        }

        class FundButton : Gtk.Button {
            public FundButton (AppCenterCore.Package package) {
                get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

                var icon = new Gtk.Image.from_icon_name ("credit-card-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
                    valign = Gtk.Align.CENTER
                };

                var title = new Gtk.Label (_("Fund"));

                var grid = new Gtk.Grid () {
                    column_spacing = 6
                };
                grid.add (icon);
                grid.add (title);

                tooltip_text = _("Fund the development of this app");

                add (grid);

                clicked.connect (() => {
                    var stripe = new Widgets.StripeDialog (
                        1,
                        package.get_name (),
                        package.normalized_component_id,
                        package.get_payments_key ()
                    );
                    stripe.transient_for = (Gtk.Window) get_toplevel ();

                    stripe.download_requested.connect (() => {
                        if (stripe.amount != 0) {
                            App.add_paid_app (package.component.get_id ());
                        }
                    });

                    stripe.show ();
                });
            }
        }

        private class ArrowButton : Gtk.Button {
            private static Gtk.CssProvider arrow_provider;

            public ArrowButton (string icon_name) {
                Object (
                    image: new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR)
                );
            }

            static construct {
                arrow_provider = new Gtk.CssProvider ();
                arrow_provider.load_from_resource ("io/elementary/appcenter/arrow.css");
            }

            construct {
                expand = true;
                valign = Gtk.Align.CENTER;

                unowned var context = get_style_context ();
                context.add_class (Gtk.STYLE_CLASS_FLAT);
                context.add_class ("circular");
                context.add_class ("arrow");
                context.add_provider (arrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }
        }
    }

    class ContentType : Gtk.FlowBoxChild {
        public ContentType (string title, string description, string icon_name) {
            can_focus = false;

            var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DND) {
                halign = Gtk.Align.START,
                margin_bottom = 6
            };

            var label = new Gtk.Label (title) {
                xalign = 0
            };

            var description_label = new Gtk.Label (description) {
                max_width_chars = 25,
                wrap = true,
                xalign = 0
            };

            unowned var description_label_context = description_label.get_style_context ();
            description_label_context.add_class (Granite.STYLE_CLASS_SMALL_LABEL);
            description_label_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            var grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.VERTICAL,
                row_spacing = 3
            };

            grid.add (icon);
            grid.add (label);
            grid.add (description_label);

            add (grid);
        }
    }

    private class OtherAppsBar : Gtk.Grid {
        public signal void show_other_package (AppCenterCore.Package package);

        public AppCenterCore.Package package { get; construct; }
        public int max_width { get; construct; }

        private const int AUTHOR_OTHER_APPS_MAX = 10;

        public OtherAppsBar (AppCenterCore.Package package, int max_width) {
            Object (
                package: package,
                max_width: max_width
            );
        }

        construct {
            if (package.author == null) {
                return;
            }

            var author_packages = AppCenterCore.Client.get_default ().get_packages_by_author (package.author, AUTHOR_OTHER_APPS_MAX);
            if (author_packages.size <= 1) {
                return;
            }

            var header = new Granite.HeaderLabel (_("Other Apps by %s").printf (package.author_title));

            var flowbox = new Gtk.FlowBox () {
                activate_on_single_click = true,
                column_spacing = 12,
                row_spacing = 12,
                homogeneous = true
            };

            foreach (var author_package in author_packages) {
                if (author_package.component.get_id () == package.component.get_id ()) {
                    continue;
                }

                var other_app = new AppCenter.Widgets.ListPackageRowGrid (author_package);
                flowbox.add (other_app);
            }

            var grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.VERTICAL,
                row_spacing = 12
            };
            grid.add (header);
            grid.add (flowbox);

            var clamp = new Hdy.Clamp () {
                margin = 24,
                maximum_size = max_width
            };
            clamp.add (grid);

            add (clamp);
            get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            flowbox.child_activated.connect ((child) => {
                var package_row_grid = (AppCenter.Widgets.ListPackageRowGrid) child.get_child ();

                show_other_package (package_row_grid.package);
            });
        }
    }
}
