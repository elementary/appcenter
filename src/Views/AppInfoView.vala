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

public class AppCenter.Views.AppInfoView : Adw.NavigationPage {
    public const int MAX_WIDTH = 800;

    public signal void show_other_package (AppCenterCore.Package package);

    public AppCenterCore.Package package { get; construct set; }

    GenericArray<AppStream.Screenshot> screenshots;

    private ActionStack action_stack;
    private GLib.ListStore origin_liststore;
    private Granite.HeaderLabel whats_new_label;
    private Gtk.CssProvider accent_provider;
    private Gtk.DropDown origin_dropdown;
    private Gtk.Label app_subtitle;
    private Gtk.ListBox extension_box;
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

    private static AppCenterCore.ScreenshotCache? screenshot_cache;

    public AppInfoView (AppCenterCore.Package package) {
        Object (package: package);
    }

    class construct {
        set_css_name ("appinfoview");
    }

    static construct {
        screenshot_cache = new AppCenterCore.ScreenshotCache ();
    }

    construct {
        AppCenterCore.FlatpakBackend.get_default ().cache_flush_needed.connect (() => {
            to_recycle = true;
        });

        var title_image = new Gtk.Image.from_gicon (package.get_icon (32, scale_factor)) {
            icon_size = LARGE
        };
        var title_label = new Gtk.Label (package.get_name ()) {
            ellipsize = END
        };

        var title_widget = new Gtk.Box (HORIZONTAL, 0);
        title_widget.append (title_image);
        title_widget.append (title_label);
        title_widget.add_css_class (Granite.STYLE_CLASS_TITLE_LABEL);

        var title_revealer = new Gtk.Revealer () {
            child = title_widget,
            transition_type = CROSSFADE
        };

        var search_button = new Gtk.Button.from_icon_name ("edit-find") {
            action_name = "win.search",
            /// TRANSLATORS: the action of searching
            tooltip_text = C_("action", "Search")
        };
        search_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var uninstall_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
            tooltip_text = _("Uninstall"),
            valign = CENTER
        };
        uninstall_button.add_css_class ("raised");

        uninstall_button_revealer = new Gtk.Revealer () {
            child = uninstall_button,
            transition_type = SLIDE_LEFT,
            overflow = VISIBLE
        };

        action_stack = new ActionStack (package) {
            hexpand = false
        };

        action_stack.action_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);
        action_stack.open_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);

        var headerbar = new Gtk.HeaderBar () {
            title_widget = title_revealer
        };
        headerbar.pack_start (new BackButton ());
        headerbar.pack_end (search_button);
        headerbar.pack_end (action_stack);
        headerbar.pack_end (uninstall_button_revealer);

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

        origin_liststore = new GLib.ListStore (typeof (AppCenterCore.Package));

        var list_factory = new Gtk.SignalListItemFactory ();
        list_factory.setup.connect (origin_setup_factory);
        list_factory.bind.connect (origin_bind_factory);

        origin_dropdown = new Gtk.DropDown (origin_liststore, null) {
            halign = START,
            valign = CENTER,
            factory = list_factory
        };

        origin_combo_revealer = new Gtk.Revealer () {
            child = origin_dropdown,
            overflow = VISIBLE,
            transition_type = SLIDE_DOWN
        };

        var header_grid = new Gtk.Grid () {
            column_spacing = 12,
            valign = Gtk.Align.CENTER
        };
        header_grid.attach (app_title, 0, 0);
        header_grid.attach (app_subtitle, 0, 1, 2);
        header_grid.attach (origin_combo_revealer, 0, 2, 2);

        if (!package.is_local) {
            size_label = new Widgets.SizeLabel () {
                halign = Gtk.Align.END,
                hexpand = true
            };
            size_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            header_grid.attach (size_label, 1, 0);
        }

        var header_box = new Gtk.Box (HORIZONTAL, 6);
        header_box.append (app_icon_overlay);
        header_box.append (header_grid);

        var header_clamp = new Adw.Clamp () {
            child = header_box,
            hexpand = true,
            maximum_size = MAX_WIDTH
        };

        var header = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true
        };
        header.append (header_clamp);

        header.add_css_class ("banner");
        header.get_style_context ().add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

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
            if (package.is_native) {
                var made_for_elementary = new ContentType (
                    _("Made for elementary OS"),
                    _("Reviewed by elementary for security, privacy, and system integration"),
                    "runtime-elementary-symbolic"
                );

                oars_flowbox.append (made_for_elementary);
            }
#endif
            const string DEFAULT_LOCALE = "en-US";
            const string LOCALE_DELIMITER = "-";
            var active_locale = DEFAULT_LOCALE;
            if (package_component.get_context () != null) {
                active_locale = package_component.get_context ().get_locale () ?? DEFAULT_LOCALE;
            }

            if (active_locale != DEFAULT_LOCALE) {
                var percent_translated = package_component.get_language (
                    // Expects language without locale
                    active_locale.split (LOCALE_DELIMITER)[0]
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

        screenshots = package_component.get_screenshots_all ();

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

        var body_clamp = new Adw.Clamp () {
            child = content_box,
            maximum_size = MAX_WIDTH
        };

        var link_listbox = new LinkListBox (package_component);

        var links_clamp = new Adw.Clamp () {
            child = link_listbox,
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

        var toolbar_view = new Adw.ToolbarView () {
            content = scrolled,
            top_bar_style = RAISED
        };
        toolbar_view.add_top_bar (headerbar);

        child = toolbar_view;
        title = package.get_name ();
        tag = package.hash;

        package.notify["state"].connect (on_package_state_changed);
        on_package_state_changed ();

        scrolled.vadjustment.value_changed.connect (() => {
           title_revealer.reveal_child = scrolled.vadjustment.value > header.get_height ();
        });

        if (oars_flowbox.get_first_child () != null) {
            oars_flowbox_revealer.reveal_child = true;
        }

        origin_dropdown.notify["selected-item"].connect (() => {
            var selected_origin_package = (AppCenterCore.Package) origin_dropdown.selected_item;
            if (selected_origin_package != null && selected_origin_package != package) {
                show_other_package (selected_origin_package);
            }
        });

        uninstall_button.clicked.connect (() => uninstall_clicked.begin ());

        realize.connect (load_more_content);
    }

    private void on_package_state_changed () {
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
    }

    private async void load_extensions () {
        package.component.get_addons ().@foreach ((extension) => {
            var extension_package = AppCenterCore.FlatpakBackend.get_default ().get_package_for_component_id (extension.id);
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

    private void load_more_content () {
        uint count = 0;
        foreach (var origin_package in package.origin_packages) {
            origin_liststore.append (origin_package);
            if (origin_package == package) {
                origin_dropdown.selected = count;
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
                var releases = package.component.get_releases_plain ().get_entries ();

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

                        if (package.installed && AppStream.vercmp_simple (release.get_version (), package.get_version ()) <= 0) {
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

            var prefer_dark_theme = Gtk.Settings.get_default ().gtk_application_prefer_dark_theme;
            screenshots.foreach ((screenshot) => {
                var environment_id = screenshot.get_environment ();
                if (environment_id != null) {
                    var environment_split = environment_id.split (":", 2);
                    if (prefer_dark_theme && environment_split.length != 2) {
                        return;
                    }

                    var color_scheme = AppStream.ColorSchemeKind.from_string (environment_split[1]);
                    if ((prefer_dark_theme && color_scheme != AppStream.ColorSchemeKind.DARK) ||
                        (!prefer_dark_theme && color_scheme == AppStream.ColorSchemeKind.DARK)) {
                        return;
                    }
                }

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

                screenshot_cache.fetch.begin (url, (obj, res) => {
                    results[index] = screenshot_cache.fetch.end (res, out file);
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
            content_fit = SCALE_DOWN,
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

            label.get_style_context ().add_provider (accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            box.append (label);
        }

        box.append (image);

        Idle.add (() => {
            screenshot_carousel.append (box);
            return GLib.Source.REMOVE;
        });
    }

    private async void uninstall_clicked () {
        package.uninstall.begin ((obj, res) => {
            try {
                package.uninstall.end (res);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    private void origin_setup_factory (Object object) {
        var title = new Gtk.Label ("") {
            xalign = 0
        };

        var list_item = (Gtk.ListItem) object;
        list_item.child = title;
    }

    private void origin_bind_factory (Object object) {
        var list_item = object as Gtk.ListItem;

        var package = (AppCenterCore.Package) list_item.get_item ();

        var title = (Gtk.Label) list_item.child;
        title.label = package.origin_description;
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
