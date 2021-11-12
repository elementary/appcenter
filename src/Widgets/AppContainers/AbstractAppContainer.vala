/*
* Copyright 2016–2021 elementary, Inc. (https://elementary.io)
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

        protected Widgets.HumbleButton action_button;
        protected Gtk.Button open_button;

        protected Gtk.Grid progress_grid;
        protected Gtk.Grid button_grid;
        protected ProgressButton cancel_button;
        protected Gtk.SizeGroup action_button_group;
        protected Gtk.Stack action_stack;

        private Gtk.Revealer action_button_revealer;
        private Gtk.Revealer open_button_revealer;
        private Gtk.Revealer uninstall_button_revealer;

        private uint state_source = 0U;

        public bool action_sensitive {
            set {
                action_button.sensitive = value;
            }
        }

        protected bool updates_view = false;

        construct {
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

            var uninstall_button = new Gtk.Button.with_label (_("Uninstall")) {
                margin_end = 12
            };

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

            cancel_button = new ProgressButton () {
                halign = Gtk.Align.END,
                label = _("Cancel"),
                valign = Gtk.Align.END
            };
            cancel_button.clicked.connect (() => action_cancelled ());

            progress_grid = new Gtk.Grid ();
            progress_grid.halign = Gtk.Align.END;
            progress_grid.valign = Gtk.Align.CENTER;
            progress_grid.add (cancel_button);

            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            action_button_group.add_widget (action_button);
            action_button_group.add_widget (uninstall_button);
            action_button_group.add_widget (cancel_button);
            action_button_group.add_widget (open_button);

            action_stack = new Gtk.Stack ();
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

        protected class ProgressButton : Gtk.Button {
            public double fraction { get; set; }

            // 2px spacing on each side; otherwise it looks weird with button borders
            private const string CSS = """
                .progress-button {
                    background-size: calc(%i%% - 4px) calc(100%% - 4px);
                }
            """;
            private static Gtk.CssProvider style_provider;

            public ProgressButton (double fraction = 0.0) {
                Object (
                    fraction: fraction
                );
            }

            static construct {
                style_provider = new Gtk.CssProvider ();
                style_provider.load_from_resource ("io/elementary/appcenter/ProgressButton.css");
            }

            construct {
                unowned var style_context = get_style_context ();
                style_context.add_class ("progress-button");
                style_context.add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

                var provider = new Gtk.CssProvider ();

                notify["fraction"].connect (() => {
                    var css = CSS.printf ((int) (fraction * 100));

                    try {
                        provider.load_from_data (css, css.length);
                        style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    } catch (Error e) {
                        critical (e.message);
                    }
                });
            }
        }

        private void show_stripe_dialog (int amount) {
            var stripe = new Widgets.StripeDialog (
                amount,
                package.get_name (),
                package.normalized_component_id,
                package.get_payments_key ()
            );

            stripe.transient_for = (Gtk.Window) get_toplevel ();

            stripe.download_requested.connect (() => {
                action_clicked.begin ();

                if (stripe.amount != 0) {
                    App.add_paid_app (package.component.get_id ());
                }
            });

            stripe.show ();
        }

        protected virtual void set_up_package () {
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
            if (package == null || package.component == null || !package.is_native || package.is_os_updates) {
                action_button.can_purchase = false;
            } else {
                var can_purchase = package.get_payments_key () != null;
                action_button.can_purchase = can_purchase;

                if (can_purchase) {
                    action_button.amount = int.parse (package.get_suggested_amount ());
                }
            }

            action_button.allow_free = true;

            if (action_stack.get_child_by_name ("buttons") != null) {
                action_stack.visible_child_name = "buttons";
            }

            switch (package.state) {
                case AppCenterCore.Package.State.NOT_INSTALLED:
#if PAYMENTS
                    action_button.free_string = _("Free");
#else
                    action_button.free_string = _("Install");
#endif
                    if (package.component.get_id () in App.settings.get_strv ("paid-apps")) {
                        action_button.amount = 0;
                    }

                    uninstall_button_revealer.reveal_child = false;
                    action_button_revealer.reveal_child = !package.is_os_updates;
                    open_button_revealer.reveal_child = false;

                    break;
                case AppCenterCore.Package.State.INSTALLED:
                    uninstall_button_revealer.reveal_child = show_uninstall && !package.is_os_updates && !package.is_compulsory;
                    action_button_revealer.reveal_child = package.should_pay && updates_view;
                    open_button_revealer.reveal_child = show_open && package.get_can_launch ();

                    action_button.allow_free = false;
                    break;
                case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                    action_button.free_string = _("Update");

                    if (!package.should_nag_update) {
                       action_button.amount = 0;
                    }

                    uninstall_button_revealer.reveal_child = show_uninstall && !package.is_os_updates && !package.is_compulsory;
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
                cancel_button.fraction = package.progress;
                return GLib.Source.REMOVE;
            });
        }

        protected virtual void update_progress_status () {
            Idle.add (() => {
                cancel_button.tooltip_text = package.get_progress_description ();
                cancel_button.sensitive = package.change_information.can_cancel && !package.changes_finished;
                /* Ensure progress bar shows complete to match status (lp:1606902) */
                if (package.changes_finished) {
                    cancel_button.fraction = 1.0f;
                }

                return GLib.Source.REMOVE;
            });
        }

        private void action_cancelled () {
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
            if (package.installed && !package.update_available) {
                action_button_revealer.reveal_child = false;
            } else if (package.update_available) {
                try {
                    yield package.update ();
                } catch (Error e) {
                    if (!(e is GLib.IOError.CANCELLED)) {
                        new UpgradeFailDialog (package, e).present ();
                    }
                }
            } else {
                if (yield package.install ()) {
                    MainWindow.installed_view.add_app.begin (package);
                }
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
#if CURATED
            var curated_dialog_allowed = App.settings.get_boolean ("non-curated-warning");
            var app_installed = package.state != AppCenterCore.Package.State.NOT_INSTALLED;
            var app_curated = package.is_native || package.is_os_updates;

            // Only show the curated dialog if the user has left them enabled, the app isn't installed
            // and it isn't a curated app
            if (curated_dialog_allowed && !app_installed && !app_curated) {
                approved = false;

                var non_curated_warning = new Widgets.NonCuratedWarningDialog (package.get_name ());
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
#endif
            return approved;
        }
    }
}
