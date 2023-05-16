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

public class AppCenter.Views.AppInfoView : AppCenter.AbstractAppContainer {
    public const int MAX_WIDTH = 800;

    public signal void show_other_package (
        AppCenterCore.Package package,
        bool remember_history = true,
        bool transition = true
    );

    private static Gtk.CssProvider banner_provider;
    private static Gtk.CssProvider loading_provider;

    GenericArray<AppStream.Screenshot> screenshots;

    private Granite.HeaderLabel whats_new_label;
    private Gtk.CssProvider accent_provider;
    private Gtk.ComboBox origin_combo;
    private Gtk.Label app_subtitle;
    private Gtk.ListBox extension_box;
    private Gtk.ListStore origin_liststore;
    private Gtk.Overlay screenshot_overlay;
    private Gtk.Revealer origin_combo_revealer;
    private Hdy.Carousel release_carousel;
    private Hdy.Carousel screenshot_carousel;
    private Hdy.Clamp screenshot_not_found_clamp;
    private Gtk.Stack screenshot_stack;
    private Gtk.Label app_description;
    private Widgets.SizeLabel size_label;
    private ArrowButton screenshot_next;
    private ArrowButton screenshot_previous;
    private Gtk.FlowBox oars_flowbox;
    private Gtk.Revealer oars_flowbox_revealer;
    private Gtk.Revealer uninstall_button_revealer;

    private bool is_runtime_warning_shown = false;
    private bool permissions_shown = false;

    private unowned Gtk.StyleContext stack_context;

    public bool to_recycle { public get; private set; default = false; }

    public AppInfoView (AppCenterCore.Package package) {
        Object (package: package);
    }

    class construct {
        set_css_name ("appinfoview");
    }

    static construct {
        var appinfoview_provider = new Gtk.CssProvider ();
        appinfoview_provider.load_from_resource ("io/elementary/appcenter/AppInfoView.css");

        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            appinfoview_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        banner_provider = new Gtk.CssProvider ();
        banner_provider.load_from_resource ("io/elementary/appcenter/banner.css");

        loading_provider = new Gtk.CssProvider ();
        loading_provider.load_from_resource ("io/elementary/appcenter/loading.css");
    }

    construct {
        AppCenterCore.BackendAggregator.get_default ().cache_flush_needed.connect (() => {
            to_recycle = true;
        });

        accent_provider = new Gtk.CssProvider ();
        try {
            string bg_color = DEFAULT_BANNER_COLOR_PRIMARY;
            string text_color = DEFAULT_BANNER_COLOR_PRIMARY_TEXT;

            var accent_css = "";
            if (package != null) {
                var primary_color = package.get_color_primary ();

                if (primary_color != null) {
                    var bg_rgba = Gdk.RGBA ();
                    bg_rgba.parse (primary_color);

                    bg_color = primary_color;
                    text_color = Granite.contrasting_foreground_color (bg_rgba).to_string ();

                    accent_css = "@define-color accent_color %s;".printf (primary_color);
                    accent_provider.load_from_data (accent_css, accent_css.length);
                }
            }

            var colored_css = BANNER_STYLE_CSS.printf (bg_color, text_color);
            colored_css += accent_css;

            accent_provider.load_from_data (colored_css, colored_css.length);
        } catch (GLib.Error e) {
            critical ("Unable to set accent color: %s", e.message);
        }

        var app_icon = new Gtk.Image () {
            pixel_size = 128
        };

        var badge_image = new Gtk.Image () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END,
            pixel_size = 64
        };

        var app_icon_overlay = new Gtk.Overlay () {
            valign = Gtk.Align.START
        };
        app_icon_overlay.add (app_icon);

        var scale_factor = get_scale_factor ();

        var plugin_host_package = package.get_plugin_host_package ();
        if (package.kind == AppStream.ComponentKind.ADDON && plugin_host_package != null) {
            app_icon.gicon = plugin_host_package.get_icon (app_icon.pixel_size, scale_factor);
            badge_image.gicon = package.get_icon (badge_image.pixel_size / 2, scale_factor);

            app_icon_overlay.add_overlay (badge_image);
        } else {
            app_icon.gicon = package.get_icon (app_icon.pixel_size, scale_factor);

            if (package.is_os_updates || package.is_runtime_updates) {
                badge_image.icon_name = "system-software-update";
                app_icon_overlay.add_overlay (badge_image);
            }
        }

        var app_title = new Gtk.Label (package.get_name ()) {
            selectable = true,
            wrap = true,
            xalign = 0
        };
        app_title.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        app_subtitle = new Gtk.Label (null) {
            label = package.get_summary (),
            selectable = true,
            wrap = true,
            wrap_mode = Pango.WrapMode.WORD_CHAR,
            xalign = 0
        };
        app_subtitle.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        app_subtitle.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        origin_liststore = new Gtk.ListStore (2, typeof (AppCenterCore.Package), typeof (string));
        origin_combo = new Gtk.ComboBox.with_model (origin_liststore) {
            halign = Gtk.Align.START,
            valign = Gtk.Align.CENTER
        };

        origin_combo_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
        };
        origin_combo_revealer.add (origin_combo);

        var renderer = new Gtk.CellRendererText ();
        origin_combo.pack_start (renderer, true);
        origin_combo.add_attribute (renderer, "text", 1);

        var uninstall_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
            tooltip_text = _("Uninstall"),
            margin_end = 12
        };

        unowned var uninstall_button_context = uninstall_button.get_style_context ();
        uninstall_button_context.add_class (Gtk.STYLE_CLASS_RAISED);
        uninstall_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        uninstall_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        uninstall_button_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT
        };
        uninstall_button_revealer.add (uninstall_button);

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            hexpand = true
        };
        button_box.add (uninstall_button_revealer);
        button_box.add (action_stack);

        var header_grid = new Gtk.Grid () {
            column_spacing = 12,
            valign = Gtk.Align.CENTER
        };
        header_grid.attach (app_title, 0, 0);
        header_grid.attach (app_subtitle, 0, 1);
        header_grid.attach (origin_combo_revealer, 0, 2, 2);
        header_grid.attach (button_box, 1, 0);

        if (!package.is_local) {
            size_label = new Widgets.SizeLabel () {
                halign = Gtk.Align.END
            };
            size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            action_button_group.add_widget (size_label);

            header_grid.attach (size_label, 1, 1);
        }

        var header_box = new Gtk.Box (HORIZONTAL, 6);
        header_box.add (app_icon_overlay);
        header_box.add (header_grid);

        var header_clamp = new Hdy.Clamp () {
            maximum_size = MAX_WIDTH
        };
        header_clamp.add (header_box);

        var header = new Gtk.Grid () {
            hexpand = true
        };
        header.add (header_clamp);

        unowned var header_context = header.get_style_context ();
        header_context.add_class ("banner");
        header_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        header_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        unowned var action_button_context = action_button.get_style_context ();
        action_button_context.add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        action_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        action_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        unowned var open_button_context = open_button.get_style_context ();
        open_button_context.add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        open_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        open_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        unowned var cancel_button_context = cancel_button.get_style_context ();
        cancel_button_context.add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        cancel_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        cancel_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

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

        oars_flowbox = new Gtk.FlowBox () {
            column_spacing = 24,
            row_spacing = 24,
            selection_mode = Gtk.SelectionMode.NONE
        };
        oars_flowbox.get_style_context ().add_class ("content-warning-box");

        oars_flowbox_revealer = new Gtk.Revealer ();
        oars_flowbox_revealer.add (oars_flowbox);

        var content_warning_clamp = new Hdy.Clamp () {
            maximum_size = MAX_WIDTH
        };
        content_warning_clamp.add (oars_flowbox_revealer);

        if (!package.is_os_updates && !package.is_runtime_updates) {
#if CURATED
            if (!package.is_native) {
                var uncurated = new ContentType (
                    _("Non-Curated"),
                    _("Not reviewed by elementary for security, privacy, or system integration"),
                    "security-low-symbolic"
                );

                oars_flowbox.add (uncurated);
            }
#endif
            var active_locale = package_component.get_active_locale ();
            if (active_locale != "en_US") {
                var percent_translated = package_component.get_language (
                    // Expects language without locale
                    active_locale.split ("_")[0]
                );

                if (percent_translated < 100) {
                    if (percent_translated == -1) {
                        var locale = new ContentType (
                            _("May Not Be Translated"),
                            _("This app does not provide language information"),
                            "metainfo-locale"
                        );

                        oars_flowbox.add (locale);
                    } else if (percent_translated == 0) {
                        var locale = new ContentType (
                            _("Not Translated"),
                            _("This app is not available in your language"),
                            "metainfo-locale"
                        );

                        oars_flowbox.add (locale);
                    } else {
                        var locale = new ContentType (
                            _("Not Fully Translated"),
                            _("This app is %i%% translated in your language").printf (percent_translated),
                            "metainfo-locale"
                        );

                        oars_flowbox.add (locale);
                    }
                }
            }
        }

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
            screenshot_carousel = new Hdy.Carousel () {
                allow_mouse_drag = true,
                allow_scroll_wheel = false,
                height_request = 500
            };

            var screenshot_switcher = new Hdy.CarouselIndicatorDots () {
                carousel = screenshot_carousel
            };

            var screenshot_box = new Gtk.Box (VERTICAL, 0);
            screenshot_box.add (screenshot_carousel);
            screenshot_box.add (screenshot_switcher);

            screenshot_previous = new ArrowButton ("go-previous-symbolic") {
                sensitive = false,
                no_show_all = true
            };
            screenshot_previous.clicked.connect (() => {
                GLib.List<unowned Gtk.Widget> screenshot_children = screenshot_carousel.get_children ();
                var index = screenshot_carousel.get_position ();
                if (index > 0) {
                    screenshot_carousel.scroll_to (screenshot_children.nth_data ((uint) index - 1));
                }
            });

            screenshot_next = new ArrowButton ("go-next-symbolic") {
                no_show_all = true
            };
            screenshot_next.clicked.connect (() => {
                GLib.List<unowned Gtk.Widget> screenshot_children = screenshot_carousel.get_children ();
                var index = screenshot_carousel.get_position ();
                if (index < screenshot_children.length () - 1) {
                    screenshot_carousel.scroll_to (screenshot_children.nth_data ((uint) index + 1));
                }
            });

            screenshot_carousel.page_changed.connect ((index) => {
                screenshot_previous.sensitive = screenshot_next.sensitive = true;

                GLib.List<unowned Gtk.Widget> screenshot_children = screenshot_carousel.get_children ();

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
            screenshot_overlay.add (screenshot_box);
            screenshot_overlay.add_overlay (screenshot_arrow_revealer_p);
            screenshot_overlay.add_overlay (screenshot_arrow_revealer_n);

            screenshot_carousel.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK);
            screenshot_carousel.add_events (Gdk.EventMask.LEAVE_NOTIFY_MASK);

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

            screenshot_carousel.enter_notify_event.connect (() => {
                screenshot_arrow_revealer_n.reveal_child = true;
                screenshot_arrow_revealer_p.reveal_child = true;
                return false;
            });

            screenshot_carousel.leave_notify_event.connect ((event) => {
                // Prevent hiding prev/next button when they're marked as insensitive
                if (event.mode != Gdk.CrossingMode.STATE_CHANGED) {
                    screenshot_arrow_revealer_n.reveal_child = false;
                    screenshot_arrow_revealer_p.reveal_child = false;
                }

                return false;
            });

            var app_screenshot_spinner = new Gtk.Spinner () {
                active = true,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };

            var screenshot_not_found = new Gtk.Label (_("Screenshot Not Available"));

            unowned var screenshot_not_found_context = screenshot_not_found.get_style_context ();
            screenshot_not_found_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            screenshot_not_found_context.add_class ("screenshot");
            screenshot_not_found_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            screenshot_not_found_clamp = new Hdy.Clamp () {
                maximum_size = MAX_WIDTH
            };
            screenshot_not_found_clamp.add (screenshot_not_found);

            screenshot_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE
            };
            screenshot_stack.add (app_screenshot_spinner);
            screenshot_stack.add (screenshot_overlay);
            screenshot_stack.add (screenshot_not_found_clamp);

            stack_context = screenshot_stack.get_style_context ();
            stack_context.add_class ("loading");
            stack_context.add_provider (loading_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        app_description = new Gtk.Label (null) {
            selectable = true,
            // Allow wrapping but prevent expanding the parent
            width_request = 1,
            wrap = true,
            xalign = 0
        };

        whats_new_label = new Granite.HeaderLabel (_("What's New:")) {
            no_show_all = true
        };

        release_carousel = new Hdy.Carousel () {
            allow_mouse_drag = true,
            allow_long_swipes = true,
            allow_scroll_wheel = false
        };

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        content_box.add (app_description);
        content_box.add (whats_new_label);
        content_box.get_style_context ().add_class ("content-box");

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

            content_box.add (extension_label);
            content_box.add (extension_box);
            load_extensions.begin ();
        }

        var links_flowbox = new Gtk.FlowBox () {
            column_spacing = 12,
            row_spacing = 6,
            hexpand = true
        };

        var project_license = package.component.project_license;
        if (project_license != null) {
            string? license_copy = null;
            string? license_url = null;

            parse_license (project_license, out license_copy, out license_url);

            var license_button = new UrlButton (_(license_copy), license_url, "text-x-copying-symbolic");

            links_flowbox.add (license_button);
        }

        var homepage_url = package_component.get_url (AppStream.UrlKind.HOMEPAGE);
        if (homepage_url != null) {
            var website_button = new UrlButton (_("Homepage"), homepage_url, "web-browser-symbolic");
            links_flowbox.add (website_button);
        }

        var translate_url = package_component.get_url (AppStream.UrlKind.TRANSLATE);
        if (translate_url != null) {
            var translate_button = new UrlButton (_("Translate"), translate_url, "preferences-desktop-locale-symbolic");
            links_flowbox.add (translate_button);
        }

        var bugtracker_url = package_component.get_url (AppStream.UrlKind.BUGTRACKER);
        if (bugtracker_url != null) {
            var bugtracker_button = new UrlButton (_("Send Feedback"), bugtracker_url, "bug-symbolic");
            links_flowbox.add (bugtracker_button);
        }

        var help_url = package_component.get_url (AppStream.UrlKind.HELP);
        if (help_url != null) {
            var help_button = new UrlButton (_("Help"), help_url, "dialog-question-symbolic");
            links_flowbox.add (help_button);
        }

#if PAYMENTS
        if (package.get_payments_key () != null) {
            var fund_button = new FundButton (package);
            links_flowbox.add (fund_button);
        }
#endif

        var body_clamp = new Hdy.Clamp () {
            maximum_size = MAX_WIDTH
        };
        body_clamp.add (content_box);

        var links_clamp = new Hdy.Clamp () {
            maximum_size = MAX_WIDTH
        };
        links_clamp.add (links_flowbox);
        links_clamp.get_style_context ().add_class ("content-box");

        var author_view = new AuthorView (package, MAX_WIDTH);

        author_view.show_other_package.connect ((package) => {
            show_other_package (package);
        });

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        box.add (header);
        box.add (content_warning_clamp);

        if (screenshots.length > 0) {
            box.add (screenshot_stack);
        }

        box.add (body_clamp);
        box.add (release_carousel);
        box.add (links_clamp);
        box.add (author_view);

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            hexpand = true,
            vexpand = true
        };
        scrolled.add (box);

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

            var share_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            share_box.add (share_icon);
            share_box.add (share_label);

            var share_button = new Gtk.MenuButton () {
                direction = Gtk.ArrowType.UP,
                popover = share_popover
            };
            share_button.add (share_box);

            unowned var share_button_context = share_button.get_style_context ();
            share_button_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            share_button_context.add_class (Gtk.STYLE_CLASS_FLAT);

            share_popover.link_copied.connect (() => {
                toast.send_notification ();
            });

            links_flowbox.add (share_button);
        }
#endif
        view_entered ();
        set_up_package ();

        if (oars_flowbox.get_children ().length () > 0) {
            oars_flowbox_revealer.reveal_child = true;
        }

        origin_combo.changed.connect (() => {
            Gtk.TreeIter iter;
            AppCenterCore.Package selected_origin_package;
            origin_combo.get_active_iter (out iter);
            origin_liststore.@get (iter, 0, out selected_origin_package);
            if (selected_origin_package != null && selected_origin_package != package) {
                show_other_package (selected_origin_package, false, false);
            }
        });

        uninstall_button.clicked.connect (() => uninstall_clicked.begin ());

        realize.connect (load_more_content);
    }

    protected override void update_state (bool first_update = false) {
        if (!package.is_local) {
            size_label.update ();
        }

        switch (package.state) {
            case AppCenterCore.Package.State.NOT_INSTALLED:
                get_app_download_size.begin ();
                uninstall_button_revealer.reveal_child = false;
                break;
            case AppCenterCore.Package.State.INSTALLED:
                uninstall_button_revealer.reveal_child = !package.is_os_updates && !package.is_runtime_updates && !package.is_compulsory;
                break;
            case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                uninstall_button_revealer.reveal_child = !package.is_os_updates && !package.is_runtime_updates && !package.is_compulsory;
                break;
            default:
                break;
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

        ContentType? runtime_warning = null;
        switch (package.runtime_status) {
            case RuntimeStatus.END_OF_LIFE:
                runtime_warning = new ContentType (
                    _("End of Life"),
                    _("May not work as expected or receive security updates"),
                    "flatpak-eol-symbolic"
                );
                break;
            case RuntimeStatus.MAJOR_OUTDATED:
                runtime_warning = new ContentType (
                    _("Outdated"),
                    _("May not work as expected or support the latest features"),
                    "flatpak-eol-symbolic"
                );
                break;
            case RuntimeStatus.MINOR_OUTDATED:
                break;
            case RuntimeStatus.UNSTABLE:
                runtime_warning = new ContentType (
                    _("Unstable"),
                    _("Built for an unstable version of %s; may contain major issues. Not recommended for use on a production system.").printf (Environment.get_os_info (GLib.OsInfoKey.NAME)),
                    "applications-development-symbolic"
                );
                break;
            case RuntimeStatus.UP_TO_DATE:
                break;
        }

        if (package.permissions_flags != AppCenterCore.Package.PermissionsFlags.UNKNOWN && !permissions_shown) {
            permissions_shown = true;

            if (AppCenterCore.Package.PermissionsFlags.FILESYSTEM_FULL in package.permissions_flags || AppCenterCore.Package.PermissionsFlags.FILESYSTEM_READ in package.permissions_flags) {
                var filesystem = new ContentType (
                    _("System Folder Access"),
                    _("Including everyone's Home folders, but not including system internals"),
                    "drive-harddisk-symbolic"
                );

                oars_flowbox.add (filesystem);
            }
        }

        if (runtime_warning != null && !is_runtime_warning_shown) {
            is_runtime_warning_shown = true;

            oars_flowbox.insert (runtime_warning, 0);
        }

        if (oars_flowbox.get_children ().length () > 0) {
            oars_flowbox.show_all ();
            oars_flowbox_revealer.reveal_child = true;
        }
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
                if (description != null) {
                    app_description.label = description;
                }
                return false;
            });

            get_app_download_size.begin ();

            Idle.add (() => {
                var releases = package.component.get_releases ();

                foreach (unowned var release in releases) {
                    if (release.get_version () == null) {
                        releases.remove (release);
                    }
                }

                if (releases.length > 0) {
                    releases.sort_with_data ((a, b) => {
                        return b.vercmp (a);
                    });

                    foreach (unowned var release in releases) {
                        var release_row = new Widgets.ReleaseRow (release);
                        release_row.get_style_context ().add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

                        release_carousel.add (release_row);

                        if (package.installed && AppStream.utils_compare_versions (release.get_version (), package.get_version ()) <= 0) {
                            break;
                        }
                    }

                    whats_new_label.no_show_all = false;
                    whats_new_label.show ();
                    release_carousel.show_all ();
                }

                return false;
            });

            if (screenshots.length == 0) {
                return null;
            }

            List<CaptionedUrl> captioned_urls = new List<CaptionedUrl> ();

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

                var captioned_url = new CaptionedUrl (
                    screenshot.get_caption (),
                    best_image.get_url ()
                );

                if (screenshot.get_kind () == AppStream.ScreenshotKind.DEFAULT && best_image != null) {
                    captioned_urls.prepend (captioned_url);
                } else if (best_image != null) {
                    captioned_urls.append (captioned_url);
                }
            });

            string?[] screenshot_files = new string?[captioned_urls.length ()];
            bool[] results = new bool[captioned_urls.length ()];
            int completed = 0;

            // Fetch each screenshot in parallel.
            for (int i = 0; i < captioned_urls.length (); i++) {
                string url = captioned_urls.nth_data (i).url;
                string? file = null;
                int index = i;

                cache.fetch.begin (url, (obj, res) => {
                    results[index] = cache.fetch.end (res, out file);
                    screenshot_files[index] = file;
                    completed++;
                });
            }

            // TODO: dynamically load screenshots as they become available.
            while (captioned_urls.length () != completed) {
                Thread.usleep (100000);
            }

            // Load screenshots that were successfully obtained.
            for (int i = 0; i < captioned_urls.length (); i++) {
                if (results[i] == true) {
                    string caption = captioned_urls.nth_data (i).caption;
                    load_screenshot (caption, screenshot_files[i]);
                }
            }

            Idle.add (() => {
                var number_of_screenshots = screenshot_carousel.get_children ().length ();

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
                    screenshot_stack.visible_child = screenshot_not_found_clamp;
                    stack_context.remove_class ("loading");
                }

                return GLib.Source.REMOVE;
            });

            return null;
        });
    }

    // We need to first download the screenshot locally so that it doesn't freeze the interface.
    private void load_screenshot (string? caption, string path) {
        var scale_factor = get_scale_factor ();
        try {
            var pixbuf = new Gdk.Pixbuf.from_file_at_scale (path, MAX_WIDTH * scale_factor, 600 * scale_factor, true);

            var image = new Gtk.Image () {
                height_request = 500,
                icon_name = "image-x-generic",
                vexpand = true
            };
            image.gicon = pixbuf;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                halign = Gtk.Align.CENTER
            };

            unowned var box_context = box.get_style_context ();
            box_context.add_class ("screenshot");
            box_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            if (caption != null) {
                var label = new Gtk.Label (caption) {
                    max_width_chars = 50,
                    wrap = true
                };

                unowned var label_context = label.get_style_context ();
                label_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

                box.add (label);
            }

            box.add (image);

            Idle.add (() => {
                box.show_all ();
                screenshot_carousel.add (box);
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

    private async void uninstall_clicked () {
        package.uninstall.begin ((obj, res) => {
            try {
                package.uninstall.end (res);
            } catch (Error e) {
#if PACKAGEKIT_BACKEND
                // Disable error dialog for if user clicks cancel. Reason: Failed to obtain authentication
                // Pk ErrorEnums are mapped to the error code at an offset of 0xFF (see packagekit-glib2/pk-client.h)
                if (!(e is Pk.ClientError) || e.code != Pk.ErrorEnum.NOT_AUTHORIZED + 0xFF) {
                    new UninstallFailDialog (package, (owned) e.message).present ();
                }
#endif
            }
        });
    }

    class UrlButton : Gtk.Box {
        public UrlButton (string label, string? uri, string icon_name) {
            get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            tooltip_text = uri;

            var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.SMALL_TOOLBAR) {
                valign = Gtk.Align.CENTER
            };

            var title = new Gtk.Label (label);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.add (icon);
            box.add (title);

            if (uri != null) {
                var button = new Gtk.Button ();
                button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

                button.add (box);
                add (button);

                button.clicked.connect (() => {
                    try {
                        Gtk.show_uri_on_window ((Gtk.Window) get_toplevel (), uri, Gdk.CURRENT_TIME);
                    } catch (Error e) {
                        critical (e.message);
                    }
                });
            } else {
                add (box);
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

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.add (icon);
            box.add (title);

            tooltip_text = _("Fund the development of this app");

            add (box);

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
            hexpand = true;
            vexpand = true;
            valign = Gtk.Align.CENTER;

            unowned var context = get_style_context ();
            context.add_class (Gtk.STYLE_CLASS_FLAT);
            context.add_class ("circular");
            context.add_class ("arrow");
            context.add_provider (arrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }

    private class CaptionedUrl : Object {
        public string? caption { get; construct; }
        public string url { get; construct; }

        public CaptionedUrl (string? caption, string url) {
            Object (caption: caption, url: url);
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

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            box.add (icon);
            box.add (label);
            box.add (description_label);

            add (box);
        }
    }
}
