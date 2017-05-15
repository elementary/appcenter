/*
* Copyright (c) 2016-2017 elementary LLC (https://elementary.io)
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
    public abstract class AbstractAppContainer : Gtk.Grid {
        public AppCenterCore.Package package { get; construct set; }

        protected Gtk.Image image;
        protected Gtk.Label package_name;
        protected Gtk.Label package_author;
        protected Gtk.Label package_summary;

        protected Widgets.HumbleButton action_button;
        protected Gtk.Button uninstall_button;
        protected Gtk.Button open_button;

        protected Gtk.ProgressBar progress_bar;
        protected Gtk.Button cancel_button;
        protected Gtk.SizeGroup action_button_group;
        protected Gtk.Stack action_stack;
        protected bool show_uninstall = true;
        protected bool show_open = true;

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
                if (this.package == null || this.package.component == null || updates_view) {
                    return false;
                }

                return this.package.get_payments_key () != null;
            }
        }

        public bool updates_view = false;

        construct {
            image = new Gtk.Image ();

            package_author = new Gtk.Label ("");
            package_name = new Gtk.Label ("");
            image = new Gtk.Image ();

            action_button = new Widgets.HumbleButton ();
            action_button.download_requested.connect (() => action_clicked.begin ());

            action_button.payment_requested.connect ((amount) => {
                var stripe = new Widgets.StripeDialog (amount, this.package_name.label, this.package.component.get_desktop_id ().replace (".desktop", ""), this.package.get_payments_key());

                stripe.download_requested.connect (() => action_clicked.begin ());
                stripe.show ();
            });

            uninstall_button = new Gtk.Button.with_label (_("Uninstall"));
            uninstall_button.clicked.connect (() => uninstall_clicked.begin ());

            open_button = new Gtk.Button.with_label (_("Open"));
            open_button.clicked.connect (launch_package_app);

            var button_grid = new Gtk.Grid ();
            button_grid.column_spacing = 6;
            button_grid.halign = Gtk.Align.END;
            button_grid.valign = Gtk.Align.CENTER;
            button_grid.add (uninstall_button);
            button_grid.add (action_button);
            button_grid.add (open_button);

            progress_bar = new Gtk.ProgressBar ();
            progress_bar.show_text = true;
            progress_bar.valign = Gtk.Align.CENTER;
            /* Request a width large enough for the longest text to stop width of
             * progress bar jumping around */
            progress_bar.width_request = 350;

            cancel_button = new Gtk.Button.with_label (_("Cancel"));
            cancel_button.clicked.connect (() => action_cancelled ());

            var progress_grid = new Gtk.Grid ();
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
            action_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            action_stack.add_named (button_grid, "buttons");
            action_stack.add_named (progress_grid, "progress");
            action_stack.show_all ();
        }

        protected virtual void set_up_package (uint icon_size = 48) {
            package_name.label = package.get_name ();

            if (package.component.get_id () != AppCenterCore.Package.OS_UPDATES_ID) {
                var author = package.component.developer_name;

                if (author == null) {
                    var project_group = package.component.project_group;

                    if (project_group != null) {
                        author = project_group;
                    } else {
                        author = _("The %s Developers").printf (package.get_name ());
                    }
                }

                package_author.label = _("by %s").printf (author);
            }

            image.gicon = package.get_icon (icon_size);

            package.notify["state"].connect (() => update_state ());

            package.change_information.bind_property ("can-cancel", cancel_button, "sensitive", GLib.BindingFlags.SYNC_CREATE);
            package.change_information.progress_changed.connect (update_progress);
            package.change_information.status_changed.connect (update_progress_status);

            update_progress_status ();
            update_progress ();
            update_state (true);
        }

        protected virtual void update_state (bool first_update = false) {
            update_action ();
        }

        protected void update_action () {
            action_button.can_purchase = payments_enabled;
            if (payments_enabled) {
                action_button.amount = int.parse (this.package.get_suggested_amount ());
            }

            action_stack.set_visible_child_name ("buttons");

            switch (package.state) {
                case AppCenterCore.Package.State.NOT_INSTALLED:
                    action_button.label = _("Free");

                    set_widget_visibility (uninstall_button, false);
                    set_widget_visibility (action_button, true);
                    set_widget_visibility (open_button, false);

                    break;
                case AppCenterCore.Package.State.INSTALLED:
                    set_widget_visibility (uninstall_button, show_uninstall && !is_os_updates);
                    set_widget_visibility (action_button, false);
                    set_widget_visibility (open_button, show_open && package.get_can_launch ());

                    break;
                case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                    action_button.label = _("Update");

                    set_widget_visibility (uninstall_button, show_uninstall && !is_os_updates);
                    set_widget_visibility (action_button, true);
                    set_widget_visibility (open_button, false);

                    break;
                case AppCenterCore.Package.State.INSTALLING:
                case AppCenterCore.Package.State.UPDATING:
                case AppCenterCore.Package.State.REMOVING:
                    set_widget_visibility (uninstall_button, false);
                    set_widget_visibility (action_button, false);
                    set_widget_visibility (open_button, false);

                    action_stack.set_visible_child_name ("progress");
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private static void set_widget_visibility (Gtk.Widget widget, bool show) {
            widget.no_show_all = !show;
            widget.visible = show;
        }

        protected void update_progress () {
             progress_bar.fraction = package.progress;
         }

        protected virtual void update_progress_status () {
            progress_bar.text = package.get_progress_description ();
            /* Ensure progress bar shows complete to match status (lp:1606902) */
            if (package.changes_finished) {
                progress_bar.fraction = 1.0f;
                cancel_button.sensitive = false;
            }
        }

        private void action_cancelled () {
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
                 yield package.update ();
            } else if (yield package.install ()) {
                 // Add this app to the Installed Apps View
                 MainWindow.installed_view.add_app.begin (package);
            }
        }

        private async void uninstall_clicked () {
            if (yield package.uninstall ()) {
                // Remove this app from the Installed Apps View
                MainWindow.installed_view.remove_app.begin (package);
            }
        }
    }
}

