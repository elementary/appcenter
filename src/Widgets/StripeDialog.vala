/*
* Copyright (c) 2016 elementary LLC (https://launchpad.net/granite)
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
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
*/

public class AppCenter.Widgets.StripeDialog : Gtk.Dialog {
    private const string HOUSTON_URI =  "http://192.168.1.7:3000/api/payment/%s?key=%s&token=%s&amount=%s&currency=USD";
    private const string USER_AGENT = "Stripe checkout";
    private const string STRIPE_URI = "https://api.stripe.com/v1/tokens?email=%s"
                            + "&payment_user_agent=%s&amount=%s&card[number]=%s"
                            + "&card[cvc]=%s&card[exp_month]=%s&card[exp_year]=%s"
                            + "&key=%s";

    private Gtk.Grid card_layout;
    private Gtk.Grid? processing_layout = null;
    private Gtk.Grid? error_layout = null;
    private Gtk.Stack layouts;

    private Gtk.Entry email_entry;
    private Gtk.Entry card_number_entry;
    private Gtk.Entry card_expiration_entry;
    private Gtk.Entry card_cvc_entry;
    private Gtk.Button pay_button;
    private Gtk.Button cancel_button;

    public int amount { get; construct set; }
    public string app_name { get; construct set; }
    public string app_id { get; construct set; }
    public string stripe_key { get; construct set; }

    private bool email_valid = false;
    private bool card_valid = false;
    private bool expiration_valid = true;
    private bool cvc_valid = true;

    public StripeDialog (int amount_, string app_name_, string app_id_, string stripe_key_) {
        Object (amount: amount_, app_name: app_name_, app_id: app_id_, stripe_key: stripe_key_);
        deletable = false;
        resizable = false;

        var primary_label = new Gtk.Label ("AppCenter");
        primary_label.get_style_context ().add_class ("primary");

        var secondary_label = new Gtk.Label (app_name);

        email_entry = new Gtk.Entry ();
        email_entry.input_purpose = Gtk.InputPurpose.EMAIL;
        email_entry.placeholder_text = "Email";
        email_entry.primary_icon_name = "internet-mail-symbolic";

        email_entry.changed.connect (() => {
           email_entry.text = email_entry.text.replace (" ", "").down ();
           validate (0, email_entry.text);
        });

        card_number_entry = new Gtk.Entry ();
        card_number_entry.input_purpose = Gtk.InputPurpose.DIGITS;
        card_number_entry.max_length = 20;
        card_number_entry.placeholder_text = "Card Number";
        card_number_entry.primary_icon_name = "credit-card-symbolic";

        card_number_entry.changed.connect (() => {
            card_number_entry.text = card_number_entry.text.replace (" ", "");
            validate (1, card_number_entry.text);
        });

        card_expiration_entry = new Gtk.Entry ();
        card_expiration_entry.max_length = 4;
        card_expiration_entry.placeholder_text = "MM / YY";
        card_expiration_entry.primary_icon_name = "office-calendar-symbolic";

        card_cvc_entry = new Gtk.Entry ();
        card_cvc_entry.input_purpose = Gtk.InputPurpose.DIGITS;
        card_cvc_entry.max_length = 4;
        card_cvc_entry.placeholder_text = "CVC";
        card_cvc_entry.primary_icon_name = "channel-secure-symbolic";

        var card_grid_bottom = new Gtk.Grid ();
        card_grid_bottom.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid_bottom.add (card_expiration_entry);
        card_grid_bottom.add (card_cvc_entry);

        var card_grid = new Gtk.Grid ();
        card_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid.orientation = Gtk.Orientation.VERTICAL;
        card_grid.add (card_number_entry);
        card_grid.add (card_grid_bottom);

        var remember_button = new Gtk.CheckButton.with_label ("Remember me");

        card_layout = new Gtk.Grid ();
        card_layout.get_style_context ().add_class ("login");
        card_layout.row_spacing = 12;
        card_layout.orientation = Gtk.Orientation.VERTICAL;
        card_layout.add (primary_label);
        card_layout.add (secondary_label);
        card_layout.add (email_entry);
        card_layout.add (card_grid);
        // card_layout.add (remember_button);

        layouts = new Gtk.Stack ();
        layouts.add_named (card_layout, "card");
        layouts.set_visible_child_name ("card");
        layouts.homogeneous = false;

        var content = get_content_area () as Gtk.Box;
        content.add (layouts);
        content.margin = 12;

        var action_area = get_action_area ();
        action_area.margin_top = 14;
        action_area.margin_left = 6;

        cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CLOSE) as Gtk.Button;

        pay_button = add_button (_("Pay $%s.00").printf (amount.to_string ()), Gtk.ResponseType.APPLY) as Gtk.Button;
        pay_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        pay_button.set_sensitive (false);

        show_all ();

        response.connect (on_response);
    }

    private void show_spinner_view () {
        if (processing_layout == null) {
            processing_layout = new Gtk.Grid ();
            processing_layout.orientation = Gtk.Orientation.VERTICAL;
            processing_layout.column_spacing = 12;

            var spinner = new Gtk.Spinner ();
            spinner.width_request = 48;
            spinner.height_request = 48;
            spinner.start ();

            var label = new Gtk.Label (_("Processing"));
            label.hexpand = true;
            label.get_style_context ().add_class ("h2");

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.valign = Gtk.Align.CENTER;
            box.vexpand = true;

            box.add (spinner);
            box.add (label);
            processing_layout.add (box);

            layouts.add_named (processing_layout, "processing");
            layouts.show_all ();
        }

        layouts.set_visible_child_name ("processing");
        cancel_button.set_sensitive (false);
        pay_button.set_sensitive (false);
    }

    private void show_error_view () {
        if (error_layout == null) {
            error_layout = new Gtk.Grid ();

            var primary_label = new Gtk.Label (_("There was a problem processing your payment"));
            primary_label.get_style_context ().add_class ("primary");
            primary_label.max_width_chars = 60;
            primary_label.xalign = 0;

            var secondary_label = new Gtk.Label (_("Please review your payment info and try again"));
            secondary_label.max_width_chars = 60;
            secondary_label.xalign = 0;

            var icon = new Gtk.Image.from_icon_name ("system-software-install", Gtk.IconSize.DIALOG);

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            grid.margin_bottom = 24;
            grid.attach (icon, 0, 0, 1, 2);
            grid.attach (primary_label, 1, 0, 1, 1);
            grid.attach (secondary_label, 1, 1, 1, 1);

            error_layout.add (grid);

            layouts.add_named (error_layout, "error");
            layouts.show_all ();
        }

        layouts.set_visible_child_name ("error");
        cancel_button.label = _("Pay Later");
        pay_button.label = _("Retry");

        cancel_button.set_sensitive (true);
        pay_button.set_sensitive (true);
    }

    private void show_card_view () {
        pay_button.label = _("Pay $%s.00").printf (amount.to_string ());
        cancel_button.label = _("Cancel");

        layouts.set_visible_child_name ("card");
        is_payment_sensitive ();
    }

    private void validate (int entry, string new_text) {
        switch (entry) {
        case 0:
            var regex = new Regex ("""[a-z|0-9]+@[a-z|0-9]+\.[a-z]+""");
            email_valid = regex.match (new_text);
            break;
        case 1:
            card_valid = is_card_valid (new_text);
            break;
        }

        is_payment_sensitive ();
    }

    private void is_payment_sensitive () {
        if (email_valid && card_valid && expiration_valid && cvc_valid) {
            pay_button.set_sensitive (true);
        } else {
            pay_button.set_sensitive (false);
        }
    }

    private bool is_card_valid (string numbers) {
        var char_count = numbers.char_count ();

        if (char_count < 14) return false;

        int hash = int.parse (numbers[char_count-1:char_count]);

        int j = 1;
        int sum = 0;
        for (int i = char_count -1; i > 0; i--) {
            var number = int.parse (numbers[i-1:i]);
            if (j++ % 2 == 1) {
                number = number * 2;
                if (number > 9) {
                    number = number - 9;
                }
            }

            sum += number;
        }

        return 10 - (sum % 10) == hash;
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                if (layouts.visible_child_name == "card") {
                    show_spinner_view ();
                    on_pay_clicked ();
                } else {
                    show_card_view ();
                }
                break;
            case Gtk.ResponseType.CLOSE:
                destroy ();
                break;
        }
    }

    private async void on_pay_clicked () {
        SourceFunc callback = on_pay_clicked.callback;
        ThreadFunc<void*> run = () => {
            var year = (int.parse (card_expiration_entry.text[2:4]) + 2000).to_string ();

            //var data = get_stripe_data (stripe_key, email_entry.text, (amount * 100).to_string (), card_number_entry.text, card_expiration_entry.text[0:2], year, card_cvc_entry.text);
            var data = get_stripe_data ("pk_test_oBReJdwjFAOVT9f05VtEy70F", "mail@nathandyer.me", "400", "4242424242424242", "12", "2018", "123"); //Mockup

            Json.Parser parser = new Json.Parser ();
            bool error = false;
            
            stderr.printf (data);
        	try {
        		parser.load_from_data (data);
        		var root_object = parser.get_root ().get_object ();
                var token_id = root_object.get_string_member ("id");

                var houston_data = post_to_houston (stripe_key, app_id, token_id, (amount * 100).to_string ());

                if (houston_data != null) {
                    parser.load_from_data (houston_data);
                    root_object = parser.get_root ().get_object ();

                    if (root_object.has_member ("errors")) {
                        error = true;
                    }
                } else {
                    error = true;
                }
        	} catch (Error e) {
        		error = true;
        	}

	    	if (error) {
        	    show_error_view ();
        	} else {
        	    destroy ();
        	}

        	Idle.add ((owned) callback);
        	return null;
    	};
    	Thread.create<void*> (run, false);

    	yield;
    }

    private string get_stripe_data (string key_, string email_, string amount_, string cc_num_, string cc_exp_month_, string cc_exp_year_, string cc_cvc_) {
        var uri = STRIPE_URI.printf (email_, USER_AGENT, amount_, cc_num_, cc_cvc_, cc_exp_month_, cc_exp_year_, key_);
        var session = new Soup.Session ();
        var message = new Soup.Message ("POST", uri);
        session.send_message (message);

        var data = new StringBuilder ();
        foreach (var c in message.response_body.data) {
            data.append ("%c".printf (c));
        }

        return data.str;
    }

    private string post_to_houston (string app_key_, string app_id_, string purchase_token_, string amount_) {
        var uri = HOUSTON_URI.printf (app_id_, app_key_, purchase_token_, amount_);
        stderr.printf ("Uri: %s\n", uri);
        var session = new Soup.Session ();
        var message = new Soup.Message ("POST", uri);
        session.send_message (message);

        var data = new StringBuilder ();
        foreach (var c in message.response_body.data) {
            data.append ("%c".printf (c));
        }

        return data.str;
    }
}

