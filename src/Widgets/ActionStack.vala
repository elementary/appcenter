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

public class AppCenter.ActionStack : Gtk.Box {
    public AppCenterCore.Package package { get; construct set; }
    public bool show_open { get; set; default = true; }
    public bool updates_view = false;

    public Gtk.Button open_button { get; private set; }
    public Widgets.HumbleButton action_button { get; private set; }
    public ProgressButton cancel_button { get; private set; }

    public uint state_source = 0U;

    public bool action_sensitive {
        set {
            action_button.sensitive = value;
        }
    }

    private Gtk.Stack stack;
    private Gtk.Revealer action_button_revealer;
    private Gtk.Revealer open_button_revealer;

    public ActionStack (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        action_button = new Widgets.HumbleButton (package);

        action_button_revealer = new Gtk.Revealer () {
            child = action_button,
            overflow = Gtk.Overflow.VISIBLE,
            transition_type = SLIDE_LEFT
        };

        action_button.download_requested.connect (() => {
            action_clicked.begin ();
        });

        open_button = new Gtk.Button.with_label (_("Open"));

        open_button_revealer = new Gtk.Revealer () {
            child = open_button,
            transition_type = SLIDE_LEFT
        };

        open_button.clicked.connect (launch_package_app);

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        button_box.append (action_button_revealer);
        button_box.append (open_button_revealer);

        cancel_button = new ProgressButton (package);
        cancel_button.clicked.connect (() => action_cancelled ());

        var action_button_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        action_button_group.add_widget (action_button);
        action_button_group.add_widget (cancel_button);
        action_button_group.add_widget (open_button);

        stack = new Gtk.Stack () {
            hhomogeneous = false,
            halign = END,
            valign = CENTER,
            transition_type = CROSSFADE
        };
        stack.add_named (button_box, "buttons");
        stack.add_named (cancel_button, "progress");

        append (stack);

        destroy.connect (() => {
            if (state_source > 0) {
                GLib.Source.remove (state_source);
            }
        });
    }

    public void update_action () {
        if (package == null || package.component == null || !package.is_native || package.is_runtime_updates) {
            action_button.can_purchase = false;
        } else {
            var can_purchase = package.get_payments_key () != null;
            action_button.can_purchase = can_purchase;

            if (can_purchase) {
                action_button.amount = int.parse (package.get_suggested_amount ());
            }
        }

        action_button.allow_free = true;

        if (stack.get_child_by_name ("buttons") != null) {
            stack.visible_child_name = "buttons";
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

                action_button_revealer.reveal_child = !package.is_runtime_updates;
                open_button_revealer.reveal_child = false;

                break;
            case AppCenterCore.Package.State.INSTALLED:
                action_button_revealer.reveal_child = package.should_pay && updates_view;
                open_button_revealer.reveal_child = show_open && package.get_can_launch ();

                action_button.allow_free = false;
                break;
            case AppCenterCore.Package.State.UPDATE_AVAILABLE:
                action_button.free_string = _("Update");

                if (!package.should_pay) {
                    action_button.amount = 0;
                }

                action_button_revealer.reveal_child = true;
                open_button_revealer.reveal_child = false;

                break;
            case AppCenterCore.Package.State.INSTALLING:
            case AppCenterCore.Package.State.UPDATING:
            case AppCenterCore.Package.State.REMOVING:

                stack.set_visible_child_name ("progress");
                break;

            default:
                critical ("Unrecognised package state %s", package.state.to_string ());
                break;
        }
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
                    var fail_dialog = new UpgradeFailDialog (package, e.message) {
                        modal = true,
                        transient_for = (Gtk.Window) get_root ()
                    };
                    fail_dialog.present ();
                }
            }
        } else {
            if (yield package.install ()) {
                MainWindow.installed_view.add_app.begin (package);
            }
        }
    }
}
