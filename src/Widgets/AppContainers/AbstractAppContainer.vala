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
        protected bool show_open { get; set; default = true; }

        protected Widgets.HumbleButton install_button;
        protected Gtk.Button open_button;
        protected ProgressButton cancel_button;
        protected Gtk.SizeGroup action_button_group;
        protected Gtk.Stack action_stack;

        private Gtk.Revealer open_button_revealer;

        private uint state_source = 0U;

        public bool action_sensitive {
            set {
                install_button.sensitive = value;
            }
        }

        protected bool updates_view = false;

        construct {
            install_button = new Widgets.HumbleButton (package);

            open_button = new Gtk.Button.with_label (_("Open"));

            open_button_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT
            };
            open_button_revealer.add (open_button);

            cancel_button = new ProgressButton () {
                label = _("Cancel")
            };

            action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            action_button_group.add_widget (install_button);
            action_button_group.add_widget (cancel_button);
            action_button_group.add_widget (open_button);

            action_stack = new Gtk.Stack () {
                homogeneous = false,
                transition_type = Gtk.StackTransitionType.CROSSFADE
            };
            action_stack.add (install_button);
            action_stack.add (open_button_revealer);
            action_stack.add (cancel_button);
            action_stack.show_all ();

            cancel_button.clicked.connect (() => action_cancelled ());

            install_button.download_requested.connect (() => {
                action_clicked.begin ();
            });

            open_button.clicked.connect (launch_package_app);

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
                install_button.can_purchase = false;
            } else {
                var can_purchase = package.get_payments_key () != null;
                install_button.can_purchase = can_purchase;

                if (can_purchase) {
                    install_button.amount = int.parse (package.get_suggested_amount ());
                }
            }

            install_button.allow_free = true;

            if (action_stack.get_child_by_name ("buttons") != null) {
                action_stack.visible_child_name = "buttons";
            }

            switch (package.state) {
                case AppCenterCore.Package.State.NOT_INSTALLED:
#if PAYMENTS
                    install_button.free_string = _("Free");
#else
                    install_button.free_string = _("Install");
#endif
                    if (package.component.get_id () in App.settings.get_strv ("paid-apps")) {
                        install_button.amount = 0;
                    }

                    action_stack.visible_child = install_button;

                    break;
                case AppCenterCore.Package.State.INSTALLED:
                    if (updates_view && package.should_pay) {
                        action_stack.visible_child = install_button;
                        install_button.allow_free = false;
                    } else {
                        action_stack.visible_child = open_button_revealer;
                    }

                    open_button_revealer.reveal_child = show_open && package.get_can_launch ();

                    break;
                case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                    action_stack.visible_child = install_button;
                    install_button.free_string = _("Update");

                    if (!package.should_nag_update) {
                       install_button.amount = 0;
                    }

                    break;
                case AppCenterCore.Package.State.INSTALLING:
                case AppCenterCore.Package.State.UPDATING:
                case AppCenterCore.Package.State.REMOVING:

                    action_stack.visible_child = cancel_button;
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
            if (package.update_available) {
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
    }
}
