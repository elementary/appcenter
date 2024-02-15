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

    GenericArray<AppStream.Screenshot> screenshots;

    private Granite.HeaderLabel whats_new_label;
    private Gtk.CssProvider accent_provider;
    private Gtk.ComboBox origin_combo;
    private Gtk.Label app_subtitle;
    private Gtk.ListBox extension_box;
    private Gtk.ListStore origin_liststore;
    private Gtk.Overlay screenshot_overlay;
    private Gtk.Revealer origin_combo_revealer;
    private Adw.Carousel release_carousel;
    private Adw.Carousel screenshot_carousel;
    private Adw.Clamp screenshot_not_found_clamp;
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

    public bool to_recycle { public get; private set; default = false; }

    public AppInfoView (AppCenterCore.Package package) {
        Object (package: package);
    }

    class construct {
        set_css_name ("appinfoview");
    }

    static construct {
        banner_provider = new Gtk.CssProvider ();
        banner_provider.load_from_resource ("io/elementary/appcenter/banner.css");
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
                    accent_provider.load_from_data (accent_css.data);
                }
            }

            var colored_css = BANNER_STYLE_CSS.printf (bg_color, text_color);
            colored_css += accent_css;

            accent_provider.load_from_data (colored_css.data);
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
            child = app_icon,
            valign = Gtk.Align.START
        };

        var scale_factor = get_scale_factor ();

        var plugin_host_package = package.get_plugin_host_package ();
        if (package.kind == AppStream.ComponentKind.ADDON && plugin_host_package != null) {
            app_icon.gicon = plugin_host_package.get_icon (app_icon.pixel_size, scale_factor);
            badge_image.gicon = package.get_icon (badge_image.pixel_size / 2, scale_factor);

            app_icon_overlay.add_overlay (badge_image);
        } else {
            app_icon.gicon = package.get_icon (app_icon.pixel_size, scale_factor);

            if (package.is_runtime_updates) {
                badge_image.icon_name = "system-software-update";
                app_icon_overlay.add_overlay (badge_image);
            }
        }

        var app_title = new Gtk.Label (package.get_name ()) {
            selectable = true,
            wrap = true,
            xalign = 0
        };
        app_title.add_css_class (Granite.STYLE_CLASS_H1_LABEL);

        app_subtitle = new Gtk.Label (null) {
            label = package.get_summary (),
            selectable = true,
            wrap = true,
            wrap_mode = Pango.WrapMode.WORD_CHAR,
            xalign = 0
        };
        app_subtitle.add_css_class (Granite.STYLE_CLASS_H3_LABEL);
        app_subtitle.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        origin_liststore = new Gtk.ListStore (2, typeof (AppCenterCore.Package), typeof (string));
        origin_combo = new Gtk.ComboBox.with_model (origin_liststore) {
            halign = Gtk.Align.START,
            valign = Gtk.Align.CENTER
        };

        origin_combo_revealer = new Gtk.Revealer () {
            child = origin_combo,
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
        };

        var renderer = new Gtk.CellRendererText ();
        origin_combo.pack_start (renderer, true);
        origin_combo.add_attribute (renderer, "text", 1);

        var uninstall_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
            tooltip_text = _("Uninstall"),
            margin_end = 12
        };
        uninstall_button.add_css_class ("raised");

        unowned var uninstall_button_context = uninstall_button.get_style_context ();
        uninstall_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        uninstall_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        uninstall_button_revealer = new Gtk.Revealer () {
            child = uninstall_button,
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
            overflow = VISIBLE
        };

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            hexpand = true
        };
        button_box.append (uninstall_button_revealer);
        button_box.append (action_stack);

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
            size_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            header_grid.attach (size_label, 1, 1);
        }

        var header_box = new Gtk.Box (HORIZONTAL, 6);
        header_box.append (app_icon_overlay);
        header_box.append (header_grid);

        var header_clamp = new Adw.Clamp () {
            child = header_box,
            maximum_size = MAX_WIDTH
        };

        var header = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true
        };
        header.append (header_clamp);

        unowned var header_context = header.get_style_context ();
        header.add_css_class ("banner");
        header_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        header_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        unowned var action_button_context = action_button.get_style_context ();
        action_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);
        action_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        action_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        unowned var open_button_context = open_button.get_style_context ();
        open_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);
        open_button_context.add_provider (banner_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        open_button_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        unowned var cancel_button_context = cancel_button.get_style_context ();
        cancel_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);
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
        oars_flowbox.add_css_class ("content-warning-box");

        oars_flowbox_revealer = new Gtk.Revealer () {
            child = oars_flowbox
        };

        var content_warning_clamp = new Adw.Clamp () {
            child = oars_flowbox_revealer,
            maximum_size = MAX_WIDTH
        };

        if (!package.is_runtime_updates) {
#if CURATED
            if (!package.is_native) {
                var uncurated = new ContentType (
                    _("Non-Curated"),
                    _("Not reviewed by elementary for security, privacy, or system integration"),
                    "security-low-symbolic"
                );

                oars_flowbox.append (uncurated);
            }
#endif

#if HAS_APPSTREAM_1_0
            var active_locale = "en-US";
            if (package_component.get_context () != null) {
                active_locale = package_component.get_context ().get_locale () ?? "en-US";
            }
#else
            var active_locale = package_component.get_active_locale ();
#endif
            if (active_locale != "en_US" && active_locale != "en-US") {
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

                        oars_flowbox.append (locale);
                    } else if (percent_translated == 0) {
                        var locale = new ContentType (
                            _("Not Translated"),
                            _("This app is not available in your language"),
                            "metainfo-locale"
                        );

                        oars_flowbox.append (locale);
                    } else {
                        var locale = new ContentType (
                            _("Not Fully Translated"),
                            _("This app is %i%% translated in your language").printf (percent_translated),
                            "metainfo-locale"
                        );

                        oars_flowbox.append (locale);
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

                oars_flowbox.append (conflict);
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

                oars_flowbox.append (violence);
            }

            if (
                rating.get_value ("drugs-narcotics") > AppStream.ContentRatingValue.NONE
            ) {
                oars_flowbox.append (drugs);
            }

            if (
                rating.get_value ("sex-nudity") > AppStream.ContentRatingValue.NONE ||
                rating.get_value ("sex-themes") > AppStream.ContentRatingValue.NONE ||
                rating.get_value ("sex-prostitution") > AppStream.ContentRatingValue.NONE
            ) {
                oars_flowbox.append (sex_nudity);
            }

            if (
                // Mild is considered things like "Dufus"
                rating.get_value ("language-profanity") > AppStream.ContentRatingValue.MILD ||
                // Mild is considered things like slapstick humor
                rating.get_value ("language-humor") > AppStream.ContentRatingValue.MILD ||
                rating.get_value ("language-discrimination") > AppStream.ContentRatingValue.NONE
            ) {
                oars_flowbox.append (language);
            }

            if (
                rating.get_value ("money-gambling") > AppStream.ContentRatingValue.NONE
            ) {
                oars_flowbox.append (gambling);
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

                oars_flowbox.append (multiplayer);
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

                oars_flowbox.append (social);
            }

            if (rating.get_value ("social-location") > AppStream.ContentRatingValue.NONE) {
                var location = new ContentType (
                    _("Location Sharing"),
                    _("Other people can see your real-world location"),
                    "oars-social-location-symbolic"
                );

                oars_flowbox.append (location);
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

                oars_flowbox.append (social_info);
            }
        }

#if HAS_APPSTREAM_1_0
        screenshots = package_component.get_screenshots_all ();
#else
        screenshots = package_component.get_screenshots ();
#endif

        if (screenshots.length > 0) {
            screenshot_carousel = new Adw.Carousel () {
                allow_mouse_drag = true,
                allow_scroll_wheel = false,
                height_request = 500
            };

            var screenshot_switcher = new Adw.CarouselIndicatorDots () {
                carousel = screenshot_carousel
            };

            var screenshot_box = new Gtk.Box (VERTICAL, 0);
            screenshot_box.append (screenshot_carousel);
            screenshot_box.append (screenshot_switcher);

            screenshot_previous = new ArrowButton ("go-previous-symbolic") {
                sensitive = false,
                visible = false
            };
            screenshot_previous.clicked.connect (() => {
                var index = (int) screenshot_carousel.position;
                if (index > 0) {
                    screenshot_carousel.scroll_to (screenshot_carousel.get_nth_page (index - 1), true);
                }
            });

            screenshot_next = new ArrowButton ("go-next-symbolic") {
                visible = false
            };

            screenshot_next.clicked.connect (() => {
                var index = (int) screenshot_carousel.position;
                if (index < screenshot_carousel.n_pages - 1) {
                    screenshot_carousel.scroll_to (screenshot_carousel.get_nth_page (index + 1), true);
                }
            });

            screenshot_carousel.page_changed.connect ((index) => {
                screenshot_previous.sensitive = screenshot_next.sensitive = true;

                if (index == 0) {
                    screenshot_previous.sensitive = false;
                } else if (index == screenshot_carousel.n_pages - 1) {
                    screenshot_next.sensitive = false;
                }
            });

            var screenshot_arrow_revealer_p = new Gtk.Revealer () {
                child = screenshot_previous,
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
                transition_type = Gtk.RevealerTransitionType.CROSSFADE
            };

            var screenshot_arrow_revealer_n = new Gtk.Revealer () {
                child = screenshot_next,
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                transition_type = Gtk.RevealerTransitionType.CROSSFADE
            };

            var screenshot_motion_controller = new Gtk.EventControllerMotion ();

            screenshot_overlay = new Gtk.Overlay () {
                child = screenshot_box
            };
            screenshot_overlay.add_overlay (screenshot_arrow_revealer_p);
            screenshot_overlay.add_overlay (screenshot_arrow_revealer_n);
            screenshot_overlay.add_controller (screenshot_motion_controller);

            screenshot_motion_controller.enter.connect (() => {
                screenshot_arrow_revealer_n.reveal_child = true;
                screenshot_arrow_revealer_p.reveal_child = true;
            });

            screenshot_motion_controller.leave.connect (() => {
                screenshot_arrow_revealer_n.reveal_child = false;
                screenshot_arrow_revealer_p.reveal_child = false;
            });

            var app_screenshot_spinner = new Gtk.Spinner () {
                spinning = true,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };

            var screenshot_not_found = new Gtk.Label (_("Screenshot Not Available"));
            screenshot_not_found.get_style_context ().add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            screenshot_not_found.add_css_class ("screenshot");
            screenshot_not_found.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            screenshot_not_found_clamp = new Adw.Clamp () {
                child = screenshot_not_found,
                maximum_size = MAX_WIDTH
            };

            screenshot_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE
            };
            screenshot_stack.add_child (app_screenshot_spinner);
            screenshot_stack.add_child (screenshot_overlay);
            screenshot_stack.add_child (screenshot_not_found_clamp);

            screenshot_stack.add_css_class ("loading");
        }

        app_description = new Gtk.Label (null) {
            selectable = true,
            // Allow wrapping but prevent expanding the parent
            width_request = 1,
            wrap = true,
            xalign = 0
        };

        whats_new_label = new Granite.HeaderLabel (_("What's New:")) {
            visible = false
        };

        release_carousel = new Adw.Carousel () {
            allow_mouse_drag = true,
            allow_long_swipes = true,
            allow_scroll_wheel = false
        };

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        content_box.append (app_description);
        content_box.append (whats_new_label);
        content_box.add_css_class ("content-box");

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
            extension_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

            content_box.append (extension_label);
            content_box.append (extension_box);
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

            links_flowbox.append (license_button);
        }

        var homepage_url = package_component.get_url (AppStream.UrlKind.HOMEPAGE);
        if (homepage_url != null) {
            var website_button = new UrlButton (_("Homepage"), homepage_url, "web-browser-symbolic");
            links_flowbox.append (website_button);
        }

        var translate_url = package_component.get_url (AppStream.UrlKind.TRANSLATE);
        if (translate_url != null) {
            var translate_button = new UrlButton (_("Translate"), translate_url, "preferences-desktop-locale-symbolic");
            links_flowbox.append (translate_button);
        }

        var bugtracker_url = package_component.get_url (AppStream.UrlKind.BUGTRACKER);
        if (bugtracker_url != null) {
            var bugtracker_button = new UrlButton (_("Send Feedback"), bugtracker_url, "bug-symbolic");
            links_flowbox.append (bugtracker_button);
        }

        var help_url = package_component.get_url (AppStream.UrlKind.HELP);
        if (help_url != null) {
            var help_button = new UrlButton (_("Help"), help_url, "dialog-question-symbolic");
            links_flowbox.append (help_button);
        }

#if PAYMENTS
        if (package.get_payments_key () != null) {
            var fund_button = new FundButton (package);
            links_flowbox.append (fund_button);
        }
#endif

        var body_clamp = new Adw.Clamp () {
            child = content_box,
            maximum_size = MAX_WIDTH
        };

        var links_clamp = new Adw.Clamp () {
            child = links_flowbox,
            maximum_size = MAX_WIDTH
        };
        links_clamp.add_css_class ("content-box");

        var author_view = new AuthorView (package, MAX_WIDTH);

        author_view.show_other_package.connect ((package) => {
            show_other_package (package);
        });

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        box.append (header);
        box.append (content_warning_clamp);

        if (screenshots.length > 0) {
            box.append (screenshot_stack);
        }

        box.append (body_clamp);
        box.append (release_carousel);
        box.append (links_clamp);
        box.append (author_view);

        var scrolled = new Gtk.ScrolledWindow () {
            child = box,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            hexpand = true,
            vexpand = true
        };

        var toast = new Granite.Toast (_("Link copied to clipboard"));

        var overlay = new Gtk.Overlay () {
            child = scrolled
        };
        overlay.add_overlay (toast);

        append (overlay);

        open_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);
#if SHARING
        if (package.is_shareable) {
            var body = _("Check out %s on AppCenter:").printf (package.get_name ());
            var uri = "https://appcenter.elementary.io/%s".printf (package.component.get_id ());
            var share_popover = new SharePopover (body, uri);

            var share_icon = new Gtk.Image.from_icon_name ("send-to-symbolic") {
                valign = Gtk.Align.CENTER
            };

            var share_label = new Gtk.Label (_("Share"));

            var share_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            share_box.append (share_icon);
            share_box.append (share_label);

            var share_button = new Gtk.MenuButton () {
                child = share_box,
                has_frame = false,
                direction = Gtk.ArrowType.UP,
                popover = share_popover
            };
            share_button.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            share_popover.link_copied.connect (() => {
                toast.send_notification ();
            });

            links_flowbox.append (share_button);
        }
#endif
        view_entered ();
        set_up_package ();

        if (oars_flowbox.get_first_child () != null) {
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
                uninstall_button_revealer.reveal_child = !package.is_runtime_updates && !package.is_compulsory;
                break;
            case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                uninstall_button_revealer.reveal_child = !package.is_runtime_updates && !package.is_compulsory;
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
                extension_box.append (row);
            }
        });
    }

    private async void get_app_download_size () {
        if (package.state == AppCenterCore.Package.State.INSTALLED || package.is_local) {
            return;
        }

        var size = yield package.get_download_size_including_deps ();
        size_label.update (size);

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

            if (AppCenterCore.Package.PermissionsFlags.ESCAPE_SANDBOX in package.permissions_flags) {
                var sandbox_escape = new ContentType (
                    _("Insecure Sandbox"),
                    _("Can ignore or modify its own system permissions"),
                    "sandbox-escape-symbolic"
                );

                oars_flowbox.append (sandbox_escape);
            }

            if (AppCenterCore.Package.PermissionsFlags.FILESYSTEM_FULL in package.permissions_flags || AppCenterCore.Package.PermissionsFlags.FILESYSTEM_READ in package.permissions_flags) {
                var filesystem = new ContentType (
                    _("System Folder Access"),
                    _("Including everyone's Home folders, but not including system internals"),
                    "sandbox-files-warning-symbolic"
                );

                oars_flowbox.append (filesystem);
            } else if (AppCenterCore.Package.PermissionsFlags.HOME_FULL in package.permissions_flags || AppCenterCore.Package.PermissionsFlags.HOME_READ in package.permissions_flags) {
                var home = new ContentType (
                    _("Home Folder Access"),
                    _("Including all documents, downloads, music, pictures, videos, and any hidden folders"),
                    "sandbox-files-symbolic"
                );

                oars_flowbox.append (home);
            }

            if (AppCenterCore.Package.PermissionsFlags.AUTOSTART in package.permissions_flags) {
                var autostart = new ContentType (
                    _("Legacy Autostart"),
                    _("Can automatically start up and run in the background without asking"),
                    "sandbox-autostart-symbolic"
                );

                oars_flowbox.append (autostart);
            }

            if (AppCenterCore.Package.PermissionsFlags.LOCATION in package.permissions_flags) {
                var location = new ContentType (
                    _("Location Access"),
                    _("Can see your precise location at any time without asking"),
                    "sandbox-location-symbolic"
                );

                oars_flowbox.append (location);
            }

            if (AppCenterCore.Package.PermissionsFlags.NOTIFICATIONS in package.permissions_flags) {
                var notifications = new ContentType (
                    _("Legacy Notifications"),
                    _("Bubbles may not be configurable or appear in notification center as “Other”"),
                    "sandbox-notifications-symbolic"
                );

                oars_flowbox.append (notifications);
            }

            if (AppCenterCore.Package.PermissionsFlags.SETTINGS in package.permissions_flags) {
                var filesystem = new ContentType (
                    _("System Settings Access"),
                    _("Can read and modify system settings"),
                    "sandbox-settings-symbolic"
                );

                oars_flowbox.append (filesystem);
            }
        }

        if (runtime_warning != null && !is_runtime_warning_shown) {
            is_runtime_warning_shown = true;

            oars_flowbox.insert (runtime_warning, 0);
        }

        if (oars_flowbox.get_first_child () != null) {
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
#if HAS_APPSTREAM_1_0
                var releases = package.component.get_releases_plain ().get_entries ();
#else
                var releases = package.component.get_releases ();
#endif

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

                        release_carousel.append (release_row);

#if HAS_APPSTREAM_1_0
                        if (package.installed && AppStream.vercmp_simple (release.get_version (), package.get_version ()) <= 0) {
#else
                        if (package.installed && AppStream.utils_compare_versions (release.get_version (), package.get_version ()) <= 0) {
#endif
                            break;
                        }
                    }

                    whats_new_label.visible = true;
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
                if (screenshot_carousel.n_pages > 0) {
                    screenshot_stack.visible_child = screenshot_overlay;
                    screenshot_stack.remove_css_class ("loading");

                    if (screenshot_carousel.n_pages > 1) {
                        screenshot_next.visible = true;
                        screenshot_previous.visible = true;
                    }
                } else {
                    screenshot_stack.visible_child = screenshot_not_found_clamp;
                    screenshot_stack.remove_css_class ("loading");
                }

                return GLib.Source.REMOVE;
            });

            return null;
        });
    }

    // We need to first download the screenshot locally so that it doesn't freeze the interface.
    private void load_screenshot (string? caption, string path) {
        var image = new Gtk.Picture.for_filename (path) {
            height_request = 500,
            vexpand = true
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            halign = Gtk.Align.CENTER
        };
        box.add_css_class ("screenshot");
        box.get_style_context ().add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (caption != null) {
            var label = new Gtk.Label (caption) {
                max_width_chars = 50,
                wrap = true
            };

            unowned var label_context = label.get_style_context ();
            label_context.add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            box.append (label);
        }

        box.append (image);

        Idle.add (() => {
            screenshot_carousel.append (box);
            return GLib.Source.REMOVE;
        });
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
            add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            tooltip_text = uri;

            var icon = new Gtk.Image.from_icon_name (icon_name) {
                valign = Gtk.Align.CENTER
            };

            var title = new Gtk.Label (label);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.append (icon);
            box.append (title);

            if (uri != null) {
                var button = new Gtk.Button () {
                    child = box
                };
                button.add_css_class (Granite.STYLE_CLASS_FLAT);

                append (button);

                button.clicked.connect (() => {
                    Gtk.show_uri ((Gtk.Window) get_root (), uri, Gdk.CURRENT_TIME);
                });
            } else {
                append (box);
            }
        }
    }

    class FundButton : Gtk.Button {
        public FundButton (AppCenterCore.Package package) {
            add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            add_css_class (Granite.STYLE_CLASS_FLAT);

            var icon = new Gtk.Image.from_icon_name ("credit-card-symbolic") {
                valign = Gtk.Align.CENTER
            };

            var title = new Gtk.Label (_("Fund"));

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.append (icon);
            box.append (title);

            tooltip_text = _("Fund the development of this app");

            child = box;

            clicked.connect (() => {
                var stripe = new Widgets.StripeDialog (
                    1,
                    package.get_name (),
                    package.normalized_component_id,
                    package.get_payments_key ()
                );
                stripe.transient_for = ((Gtk.Application) Application.get_default ()).active_window;

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
        public ArrowButton (string icon_name) {
            Object (icon_name: icon_name);
        }

        construct {
            hexpand = true;
            vexpand = true;
            valign = Gtk.Align.CENTER;

            add_css_class (Granite.STYLE_CLASS_FLAT);
            add_css_class (Granite.STYLE_CLASS_CIRCULAR);
            add_css_class ("arrow");
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

            var icon = new Gtk.Image.from_icon_name (icon_name) {
                halign = Gtk.Align.START,
                margin_bottom = 6,
                pixel_size = 32
            };

            var label = new Gtk.Label (title) {
                xalign = 0
            };

            var description_label = new Gtk.Label (description) {
                max_width_chars = 25,
                wrap = true,
                xalign = 0
            };
            description_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);
            description_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            box.append (icon);
            box.append (label);
            box.append (description_label);

            child = box;
        }
    }
}
