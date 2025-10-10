/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2016-2024 elementary, Inc. (https://elementary.io)
 */

public class AppCenter.ActionStack : Gtk.Box {
    public AppCenterCore.Package package { get; construct set; }
    public bool show_open { get; set; default = true; }
    public bool updates_view = false;

    public Gtk.Button open_button { get; private set; }
    public Widgets.HumbleButton action_button { get; private set; }
    public ProgressButton cancel_button { get; private set; }

    public bool action_sensitive {
        set {
            action_button.sensitive = value;
        }
    }

    private uint state_source = 0U;
    private Gtk.Stack stack;
    private Gtk.Revealer action_button_revealer;
    private Gtk.Revealer open_button_revealer;

    public ActionStack (AppCenterCore.Package package) {
        Object (package: package);
    }

    construct {
        action_button = new Widgets.HumbleButton (package) {
            halign = END
        };

        var in_app_label = new Gtk.Label (_("In-app purchases")) {
            visible = false
        };
        in_app_label.add_css_class (Granite.CssClass.DIM);
        in_app_label.add_css_class ("tiny-label");

        foreach (unowned var rating in package.component.get_content_ratings ()) {
            if (rating.get_value ("money-purchasing") == INTENSE) {
                in_app_label.visible = true;
                break;
            }
        }

        var action_box = new Gtk.Box (VERTICAL, 0);
        action_box.append (action_button);
        action_box.append (in_app_label);

        action_button_revealer = new Gtk.Revealer () {
            child = action_box,
            overflow = Gtk.Overflow.VISIBLE,
            transition_type = SLIDE_LEFT
        };

        action_button.download_requested.connect (() => {
            action_clicked.begin ();
        });

        open_button = new Gtk.Button.with_label (_("Open")) {
            valign = CENTER
        };

        open_button_revealer = new Gtk.Revealer () {
            child = open_button,
            overflow = VISIBLE,
            transition_type = SLIDE_LEFT
        };

        open_button.clicked.connect (launch_package_app);

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        button_box.append (action_button_revealer);
        button_box.append (open_button_revealer);

        cancel_button = new ProgressButton (package) {
            valign = CENTER
        };
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

        package.notify["state"].connect (on_package_state_changed);
        update_action ();

        destroy.connect (() => {
            if (state_source > 0) {
                GLib.Source.remove (state_source);
            }
        });
    }

    private void on_package_state_changed () {
        if (state_source > 0) {
            return;
        }

        state_source = Idle.add (() => {
            update_action ();
            state_source = 0U;
            return GLib.Source.REMOVE;
        });
    }

    private void update_action () {
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
                action_button.free_string = _("Install");

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
        package.change_information.cancel ();
    }

    private void launch_package_app () {
        try {
            package.launch ();
        } catch (Error e) {
            warning ("Failed to launch %s: %s".printf (package.name, e.message));
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
            yield package.install ();
        }
    }
}
