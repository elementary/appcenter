/*
* Copyright (c) 2016–2019 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace AppCenter {
    public abstract class AbstractAppContainer : Gtk.Bin {
        public AppCenterCore.Package package { get; construct set; }
        protected bool show_uninstall { get; set; default = true; }
        protected bool show_open { get; set; default = true; }

        protected Gtk.Overlay image;
        protected Gtk.Image inner_image;
        protected Gtk.Label package_name;
        protected Gtk.Label package_author;

        protected Widgets.ContentWarningDialog content_warning;
        protected Widgets.NonCuratedWarningDialog non_curated_warning;
        protected Widgets.HumbleButton action_button;
        protected Gtk.Button uninstall_button;
        protected Gtk.Button open_button;

        protected Gtk.Grid progress_grid;
        protected Gtk.Grid button_grid;
        protected Gtk.ProgressBar progress_bar;
        protected Gtk.Button cancel_button;
        protected Gtk.SizeGroup action_button_group;
        protected Gtk.Stack action_stack;

        private Gtk.Revealer open_button_revealer;
        private Gtk.Revealer uninstall_button_revealer;
        private Gtk.Revealer action_button_revealer;
        private Mutex action_mutex = Mutex ();
        private Cancellable action_cancellable = new Cancellable ();

        private uint state_source = 0U;

        private enum ActionResult {
            NONE = 0,
            HIDE_BUTTON = 1,
            ADD_TO_INSTALLED_SCREEN = 2
        }

        public bool is_os_updates {
            get {
                return package.is_os_updates;
            }
        }

        public bool is_driver {
            get {
                return package.is_driver;
            }
        }

        public bool update_available {
            get {
                return package.update_available || package.is_updating;
            }
        }

        public bool is_updating {
            get {
                return package.is_updating;
            }
        }

        public string name_label {
            get {
                return package_name.label;
            }
        }

        public bool action_sensitive {
            set {
                action_button.sensitive = value;
            }
        }

        public bool payments_enabled {
            get {
                if (package == null || package.component == null || !package.is_native || package.is_os_updates) {
                    return false;
                }

                return package.get_payments_key () != null;
            }
        }

        protected bool updates_view = false;

        construct {
            image = new Gtk.Overlay ();
            inner_image = new Gtk.Image ();
            image.add (inner_image);

            package_author = new Gtk.Label (null);
            package_name = new Gtk.Label (null);

            action_button = new Widgets.HumbleButton ();

            action_button_revealer = new Gtk.Revealer ();
            action_button_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
            action_button_revealer.add (action_button);

            action_button.download_requested.connect (() => {
                if (install_approved ()) {
                    action_clicked.begin ();
                }
            });

            action_button.payment_requested.connect ((amount) => {
                if (install_approved ()) {
                    show_stripe_dialog (amount);
                }
            });

            uninstall_button = new Gtk.Button.with_label (_("Uninstall"));
            uninstall_button.margin_end = 12;

            uninstall_button_revealer = new Gtk.Revealer ();
            uninstall_button_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
            uninstall_button_revealer.add (uninstall_button);

            uninstall_button.clicked.connect (() => uninstall_clicked.begin ());

            open_button = new Gtk.Button.with_label (_("Open"));

            open_button_revealer = new Gtk.Revealer ();
            open_button_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
            open_button_revealer.add (open_button);

            open_button.clicked.connect (launch_package_app);

            button_grid = new Gtk.Grid ();
            button_grid.valign = Gtk.Align.CENTER;
            button_grid.halign = Gtk.Align.END;
            button_grid.hexpand = false;

            button_grid.add (uninstall_button_revealer);
            button_grid.add (action_button_revealer);
            button_grid.add (open_button_revealer);

            progress_bar = new Gtk.ProgressBar ();
            progress_bar.show_text = true;
            progress_bar.valign = Gtk.Align.CENTER;
            /* Request a width large enough for the longest text to stop width of
             * progress bar jumping around, but allow space for long package names */
            progress_bar.width_request = 250;

            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            cancel_button.valign = Gtk.Align.END;
            cancel_button.halign = Gtk.Align.END;
            cancel_button.clicked.connect (() => action_cancelled ());

            progress_grid = new Gtk.Grid ();
            progress_grid.halign = Gtk.Align.END;
            progress_grid.valign = Gtk.Align.CENTER;
            progress_grid.column_spacing = 12;
            progress_grid.attach (progress_bar, 0, 0, 1, 1);
            progress_grid.attach (cancel_button, 1, 0, 1, 1);

            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            action_button_group.add_widget (action_button);
            action_button_group.add_widget (uninstall_button);
            action_button_group.add_widget (cancel_button);
            action_button_group.add_widget (open_button);

            action_stack = new Gtk.Stack ();
            action_stack.hexpand = true;
            action_stack.hhomogeneous = false;
            action_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            action_stack.add_named (button_grid, "buttons");
            action_stack.add_named (progress_grid, "progress");
            action_stack.show_all ();

            destroy.connect (() => {
                if (state_source > 0) {
                    GLib.Source.remove (state_source);
                }
            });
        }

        private void show_stripe_dialog (int amount) {
            var stripe = new Widgets.StripeDialog (
                amount,
                package_name.label,
                package.component.id.replace (".desktop", ""),
                package.get_payments_key ()
            );

            stripe.transient_for = (Gtk.Window) get_toplevel ();

            stripe.download_requested.connect (() => {
                action_clicked.begin ();
                App.add_paid_app (package.component.get_id ());
            });

            stripe.show ();
        }

        protected virtual void set_up_package (uint icon_size = 48) {
            package_name.label = Utils.unescape_markup (package.get_name ());

            if (package.component.get_id () != AppCenterCore.Package.OS_UPDATES_ID) {
                package_author.label = package.author_title;
            }

            var scale_factor = inner_image.get_scale_factor ();

            var badge_icon_size = Gtk.IconSize.LARGE_TOOLBAR;
            var badge_pixel_size = 24;
            if (icon_size >= 128) {
                badge_icon_size = Gtk.IconSize.DIALOG;
                badge_pixel_size = 64;
            }

            var plugin_host_package = package.get_plugin_host_package ();
            if (package.is_plugin && plugin_host_package != null) {
                inner_image.gicon = plugin_host_package.get_icon (icon_size, scale_factor);
                var overlay_gicon = package.get_icon (icon_size / 2, scale_factor);

                var overlay_image = new Gtk.Image.from_gicon (overlay_gicon, badge_icon_size);
                overlay_image.halign = overlay_image.valign = Gtk.Align.END;
                overlay_image.pixel_size = badge_pixel_size;
                image.add_overlay (overlay_image);
            } else {
                inner_image.gicon = package.get_icon (icon_size, scale_factor);

                if (is_os_updates) {
                    var overlay_image = new Gtk.Image.from_icon_name ("system-software-update", badge_icon_size);
                    overlay_image.halign = overlay_image.valign = Gtk.Align.END;
                    overlay_image.pixel_size = badge_pixel_size;

                    image.add_overlay (overlay_image);
                }
            }

            package.notify["state"].connect (on_package_state_changed);

            package.change_information.progress_changed.connect (update_progress);
            package.change_information.status_changed.connect (update_progress_status);

            update_progress_status ();
            update_progress ();
            update_state (true);
        }

        private void on_package_state_changed () {
            if (state_source > 0) {
                return;
            }

            state_source = Idle.add (() => {
                update_state ();
                state_source = 0U;
                return GLib.Source.REMOVE;
            });
        }

        protected virtual void update_state (bool first_update = false) {
            update_action ();
        }

        protected void update_action () {
            action_button.can_purchase = payments_enabled;
            action_button.allow_free = true;
            if (payments_enabled) {
                action_button.amount = int.parse (this.package.get_suggested_amount ());
            }

            if (action_stack.get_child_by_name ("buttons") != null) {
                action_stack.visible_child_name = "buttons";
            }

            switch (package.state) {
                case AppCenterCore.Package.State.NOT_INSTALLED:
#if PAYMENTS
                    action_button.label = _("Free");
#else
                    action_button.label = _("Install");
#endif
                    if (package.component.get_id () in App.settings.get_strv ("paid-apps")) {
                        action_button.amount = 0;
                    }

                    uninstall_button_revealer.reveal_child = false;
                    action_button_revealer.reveal_child = !package.is_os_updates;
                    open_button_revealer.reveal_child = false;

                    break;
                case AppCenterCore.Package.State.INSTALLED:
                    uninstall_button_revealer.reveal_child = show_uninstall && !is_os_updates && !package.is_compulsory;
                    action_button_revealer.reveal_child = package.should_pay && updates_view;
                    open_button_revealer.reveal_child = show_open && package.get_can_launch ();

                    action_button.allow_free = false;
                    break;
                case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                    if (!package.should_nag_update) {
                       action_button.amount = 0;
                    }

                    action_button.label = _("Update");

                    uninstall_button_revealer.reveal_child = show_uninstall && !is_os_updates && !package.is_compulsory;
                    action_button_revealer.reveal_child = true;
                    open_button_revealer.reveal_child = false;

                    break;
                case AppCenterCore.Package.State.INSTALLING:
                case AppCenterCore.Package.State.UPDATING:
                case AppCenterCore.Package.State.REMOVING:

                    action_stack.set_visible_child_name ("progress");
                    break;

                default:
                    critical ("Unrecognised package state %s", package.state.to_string ());
                    break;
            }
        }

        protected void update_progress () {
            Idle.add (() => {
                progress_bar.fraction = package.progress;
                return GLib.Source.REMOVE;
            });
        }

        protected virtual void update_progress_status () {
            Idle.add (() => {
                progress_bar.text = package.get_progress_description ();
                cancel_button.sensitive = package.change_information.can_cancel && !package.changes_finished;
                /* Ensure progress bar shows complete to match status (lp:1606902) */
                if (package.changes_finished) {
                    progress_bar.fraction = 1.0f;
                }

                return GLib.Source.REMOVE;
            });
        }

        private void action_cancelled () {
            action_cancellable.cancel ();
            update_action ();
            package.action_cancellable.cancel ();
        }

        private void launch_package_app () {
            try {
                package.launch ();
            } catch (Error e) {
                warning ("Failed to launch %s: %s".printf (package.get_name (), e.message));
            }
        }

        private async void action_clicked () {
            ActionResult result = 0;
            SourceFunc callback = action_clicked.callback;

            // Apply packagekit actions in the background, and ultimately yield a result
            // to this once the action is complete
            ThreadFunc<bool> run = () => {
                // Ensure that only one action is performed at a time.
                action_mutex.lock ();

                var loop = new MainLoop ();

                if (package.installed && !package.update_available) {
                    result = ActionResult.HIDE_BUTTON;
                } else if (package.update_available) {
                    package.update.begin (true, (obj, res) => {
                        package.update.end (res);
                        loop.quit ();
                    });
                } else {
                    package.install.begin ((obj, res) => {
                        if (package.update.end (res)) {
                            result = ActionResult.ADD_TO_INSTALLED_SCREEN;
                        }

                        loop.quit ();
                    });
                }

                if (action_cancellable.is_cancelled ()) {
                    package.action_cancellable.cancel ();
                    action_cancellable.reset ();
                    action_mutex.unlock ();
                    Idle.add ((owned)callback);
                    return true;
                }

                loop.run (); // wait for async methods above

                action_mutex.unlock ();
                Idle.add ((owned)callback);
                return true;
            };

            new Thread<bool> ("action_clicked", run);

            action_stack.set_visible_child_name ("progress");

            yield;

            switch (result) {
                case ActionResult.HIDE_BUTTON:
                    action_button_revealer.reveal_child = false;
                    break;
                case ActionResult.ADD_TO_INSTALLED_SCREEN:
                    // Add this app to the Installed Apps View
                    MainWindow.installed_view.add_app.begin (package);
                    break;
                default:
                    break;
            }
        }

        private async void uninstall_clicked () {
            package.uninstall.begin ((obj, res) => {
                try {
                    if (package.uninstall.end (res)) {
                        MainWindow.installed_view.remove_app.begin (package);
                    }
                } catch (Error e) {
                    // Disable error dialog for if user clicks cancel. Reason: Failed to obtain authentication
                    // Pk ErrorEnums are mapped to the error code at an offset of 0xFF (see packagekit-glib2/pk-client.h)
                    if (!(e is Pk.ClientError) || e.code != Pk.ErrorEnum.NOT_AUTHORIZED + 0xFF) {
                        new UninstallFailDialog (package, e).present ();
                    }
                }
            });
        }

        private bool install_approved () {
            bool approved = true;

            var curated_dialog_allowed = App.settings.get_boolean ("non-curated-warning");
            var app_installed = package.state != AppCenterCore.Package.State.NOT_INSTALLED;
            var app_curated = package.is_native || is_os_updates;

            // Only show the curated dialog if the user has left them enabled, the app isn't installed
            // and it isn't a curated app
            if (curated_dialog_allowed && !app_installed && !app_curated) {
                approved = false;

                non_curated_warning = new Widgets.NonCuratedWarningDialog (this.package_name.label);
                non_curated_warning.transient_for = (Gtk.Window) get_toplevel ();

                non_curated_warning.response.connect ((response_id) => {
                    switch (response_id) {
                        case Gtk.ResponseType.OK:
                            approved = true;
                            break;
                        case Gtk.ResponseType.CANCEL:
                        case Gtk.ResponseType.CLOSE:
                        case Gtk.ResponseType.DELETE_EVENT:
                            approved = false;
                            break;
                        default:
                            assert_not_reached ();
                    }

                    non_curated_warning.close ();
                });

                non_curated_warning.run ();
                non_curated_warning.destroy ();

                // If the install has been rejected at this stage, return early
                if (!approved) {
                    return false;
                }
            }

            if (App.settings.get_boolean ("content-warning") == true && package.is_explicit) {
                approved = false;

                content_warning = new Widgets.ContentWarningDialog (this.package_name.label);
                content_warning.transient_for = (Gtk.Window) get_toplevel ();

                content_warning.response.connect ((response_id) => {
                    switch (response_id) {
                        case Gtk.ResponseType.OK:
                            approved = true;
                            break;
                        case Gtk.ResponseType.CANCEL:
                        case Gtk.ResponseType.CLOSE:
                        case Gtk.ResponseType.DELETE_EVENT:
                            approved = false;
                            break;
                        default:
                            assert_not_reached ();
                    }

                    content_warning.close ();
                });

                content_warning.run ();
                content_warning.destroy ();
            }

            return approved;
        }
    }
}
