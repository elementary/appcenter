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

using Gee;
using GLib;


public class AppCenter.Widgets.StripeDialog : Gtk.Dialog    { 

    public signal void download_requested ();

    private const string HOUSTON_URI =  "https://developer.elementary.io/api/payment/%s?key=%s&token=%s&email=%s&amount=%s&currency=USD";
    private const string USER_AGENT = "Stripe checkout";
    private const string STRIPE_URI = "https://api.stripe.com/v1/tokens?email=%s"
                            + "&payment_user_agent=%s&amount=%s&card[number]=%s"
                            + "&card[cvc]=%s&card[exp_month]=%s&card[exp_year]=%s"
                            + "&key=%s";

    private const string INTERNAL_ERROR_MESSAGE = N_("An error occurred while processing the card. Please try again later. We apologize for any inconvenience caused.");
    private const string DEFAULT_ERROR_MESSAGE = N_("Please review your payment info and try again.");

    private Gtk.Grid card_layout;
    private Gtk.Grid? processing_layout = null;
    private Gtk.Grid? error_layout = null;
    private Gtk.Stack layouts;

    private Gtk.Entry email_entry;
    public static Gtk.Entry  card_number_entry;
    private Gtk.Entry card_expiration_entry;
    private Gtk.Entry card_cvc_entry;
    private Gtk.Button pay_button;
    private Gtk.Button cancel_button;
    private Gtk.Button save_button; 

    private Gtk.Label secondary_error_label;
    private GLib.Cancellable cancellable;
    public Gtk.ListStore list_store; 
    public Gtk.TreeIter iter;

    public Gtk.Widget *widget;
    public Gtk.InfoBar *bar;

       struct PaymentCard {
        // Card Definition 
        string cNum;
        string cvc;  
        string expo; 
    }

 
    private PaymentCard userCard;

    public string cryptLoc = "";
    public const string COLLECTION_APPCC = "default";
    // public Gee.ArrayList<string> meta_list;   
    public int index =0;  

    public static AppCenter.Services.XmlParser internal_xml; 
    public AppCenter.App appcenter_internal; 


    public int amount { get; construct set; }
    public string app_name { get; construct set; }
    public string app_id { get; construct set; }
    public string stripe_key { get; construct set; }

    public static string localuser; 
    public static Secret.Service service; 

    public bool trigered;

    private bool email_valid = false;
    private bool card_valid = false;
    private bool expiration_valid = false;
    private bool cvc_valid = false;

    public string?               real_name { public get; private set; }
    public weak Act.User ActiveUser { get; set; }
    public weak Act.UserManager UsrManagment { get; construct; }

    private bool save_state = false; 
    private bool empty; 


    public StripeDialog (int _amount, string _app_name, string _app_id, string _stripe_key) {
        Object (amount: _amount,
                app_name: _app_name,
                app_id: _app_id,
                deletable: false,
                resizable: false,
                stripe_key: _stripe_key);
    }

// : Gtk.ApplicationWindow 

    construct {

        trigered = false; 

        var primary_label = new Gtk.Label ("AppCenter");
        primary_label.get_style_context ().add_class ("primary");

        var secondary_label = new Gtk.Label (app_name);

       

        email_entry = new Gtk.Entry ();
        email_entry.hexpand = true;
        email_entry.input_purpose = Gtk.InputPurpose.EMAIL;
        email_entry.placeholder_text = _("Email");
        email_entry.primary_icon_name = "internet-mail-symbolic";
        email_entry.tooltip_text = _("Your email address is used to send a receipt. It is never stored and you will not be subscribed to a mailing list.");

        email_entry.changed.connect (() => {
           email_entry.text = email_entry.text.replace (" ", "").down ();
           validate (0, email_entry.text);
        });

        Gtk.CheckButton save_check_button = new Gtk.CheckButton.with_label ("Save Card"); 
        internal_xml = new AppCenter.Services.XmlParser ();
        ActiveUser = get_usermanager ().get_user (GLib.Environment.get_user_name ()); 
        ActiveUser.changed.connect(init_user); 
        
    


        card_number_entry = new Gtk.Entry(); 
        //card_number_entry = new Gtk.ComboBox.with_model (list_store);
        card_number_entry.hexpand = true;
        card_number_entry.input_purpose = Gtk.InputPurpose.DIGITS;
        card_number_entry.max_length = 20;
        card_number_entry.placeholder_text = _("Card Number");
        card_number_entry.primary_icon_name = "credit-card-symbolic";

        card_number_entry.changed.connect (() => {
            card_number_entry.text = card_number_entry.text.replace (" ", "");
            validate (1, card_number_entry.text);
        });

        card_expiration_entry = new Gtk.Entry ();
        card_expiration_entry.hexpand = true;
        card_expiration_entry.max_length = 5;
        /// TRANSLATORS: Don't change the order, only transliterate
        card_expiration_entry.placeholder_text = _("MM / YY");
        card_expiration_entry.primary_icon_name = "office-calendar-symbolic";

        card_expiration_entry.changed.connect (() => {
            card_expiration_entry.text = card_expiration_entry.text.replace (" ", "");
            validate (2, card_expiration_entry.text);
        });

        card_expiration_entry.focus_out_event.connect (() => {
            var expiration_text = card_expiration_entry.text;
            if (!("/" in expiration_text) && expiration_text.char_count () > 2) {
                int position = 2;
                card_expiration_entry.insert_text ("/", 1, ref position);
            }
        });

        card_cvc_entry = new Gtk.Entry ();
        card_cvc_entry.hexpand = true;
        card_cvc_entry.input_purpose = Gtk.InputPurpose.DIGITS;
        card_cvc_entry.max_length = 4;
        card_cvc_entry.placeholder_text = _("CVC");
        card_cvc_entry.primary_icon_name = "channel-secure-symbolic";

        card_cvc_entry.changed.connect (() => {
            card_cvc_entry.text = card_cvc_entry.text.replace (" ", "");
            validate (3, card_cvc_entry.text);
        });

        var card_grid_bottom = new Gtk.Grid ();
        card_grid_bottom.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid_bottom.add (card_expiration_entry);
        card_grid_bottom.add (card_cvc_entry);

        var card_grid = new Gtk.Grid ();
        card_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid.orientation = Gtk.Orientation.VERTICAL;
        card_grid.add (card_number_entry);
        card_grid.add (card_grid_bottom);

        card_layout = new Gtk.Grid ();
        card_layout.get_style_context ().add_class ("login");
        card_layout.row_spacing = 12;
        card_layout.orientation = Gtk.Orientation.VERTICAL;
        card_layout.add (primary_label);
        card_layout.add (secondary_label);
        card_layout.add (email_entry);
        card_layout.add (card_grid);
        card_layout.add (save_check_button); 



        layouts = new Gtk.Stack ();
        layouts.vhomogeneous = false;
        layouts.margin_left = layouts.margin_right = 12;
        layouts.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        layouts.add_named (card_layout, "card");
        layouts.set_visible_child_name ("card");

        get_content_area ().add (layouts);

        var privacy_policy_link = new Gtk.LinkButton.with_label ("https://stripe.com/privacy", _("Privacy Policy"));

         
        var action_area = (Gtk.ButtonBox) get_action_area ();
        action_area.margin_right = 5;
        action_area.margin_bottom = 5;
        action_area.margin_top = 14;
        action_area.add (privacy_policy_link);
        // action_area.add(save_check_button); 
        action_area.set_child_secondary (privacy_policy_link, true);


        save_button = (Gtk.Button) add_button (_("Manage Cards"), Gtk.ResponseType.ACCEPT);

        cancel_button = (Gtk.Button) add_button (_("Cancel"), Gtk.ResponseType.CLOSE); 
        //save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION); 

        pay_button = (Gtk.Button) add_button (_("Pay $%d.00").printf (amount), Gtk.ResponseType.APPLY);
        pay_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        pay_button.has_default = true;
        pay_button.sensitive = false;


        show_all ();

        response.connect (on_response);

        email_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        card_number_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        card_expiration_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        card_cvc_entry.activate.connect (() => {
            if (pay_button.sensitive) {
                pay_button.activate ();
            }
        });

        save_check_button.toggled.connect (() => {
			// Emitted when the button has been clicked:
			if (save_check_button.active) {
                save_state = true; 
            }

            else {
                save_state = false; 
            }

			
		}); 
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
        cancel_button.sensitive = false;
        pay_button.sensitive = false;
    }

    private void show_error_view (string error_reason) {
        if (error_layout == null) {
            error_layout = new Gtk.Grid ();

            var primary_label = new Gtk.Label (_("There Was a Problem Processing Your Payment"));
            primary_label.get_style_context ().add_class ("primary");
            primary_label.max_width_chars = 35;
            primary_label.wrap = true;
            primary_label.xalign = 0;

            secondary_error_label = new Gtk.Label (error_reason);
            secondary_error_label.max_width_chars = 35;
            secondary_error_label.wrap = true;
            secondary_error_label.xalign = 0;

            var icon = new Gtk.Image.from_icon_name ("system-software-install", Gtk.IconSize.DIALOG);

            var overlay_icon = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.LARGE_TOOLBAR);
            overlay_icon.halign = Gtk.Align.END;
            overlay_icon.valign = Gtk.Align.END;

            var overlay = new Gtk.Overlay ();
            overlay.valign = Gtk.Align.START;
            overlay.add (icon);
            overlay.add_overlay (overlay_icon);

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            grid.attach (overlay, 0, 0, 1, 2);
            grid.attach (primary_label, 1, 0, 1, 1);
            grid.attach (secondary_error_label, 1, 1, 1, 1);

            error_layout.add (grid);

            layouts.add_named (error_layout, "error");
            layouts.show_all ();
        } else {
            secondary_error_label.label = error_reason;
        }

        layouts.set_visible_child_name ("error");
        cancel_button.label = _("Pay Later");
        pay_button.label = _("Retry");

        cancel_button.sensitive = true;
        pay_button.sensitive = true;
    }

    private void show_card_view () {
        pay_button.label = _("Pay $%d.00").printf (amount);
        cancel_button.label = _("Cancel");
        save_button.label = _("Save"); 

        layouts.set_visible_child_name ("card");
        is_payment_sensitive ();
    }

 

    private void validate (int entry, string new_text) {
        try {
            switch (entry) {
                case 0:
                    var regex = new Regex ("""[a-z|0-9]+@[a-z|0-9]+\.[a-z]+""");
                    email_valid = regex.match (new_text);
                    break;
                case 1:
                    card_valid = is_card_valid (new_text);
                    break;
                case 2:
                    if (new_text.length < 4) {
                        expiration_valid = false;
                    } else {
                        var regex = new Regex ("""^[0-9]{2}\/?[0-9]{2}$""");
                        expiration_valid = regex.match (new_text);
                    }
                    break;
                case 3:
                    var regex = new Regex ("""[0-9]{3,4}""");
                    cvc_valid = regex.match (new_text);
                    break;
            }
        } catch (GLib.Error e) {
            warning (e.message);
        }

        is_payment_sensitive ();
    }

    private void is_payment_sensitive () {
        if (email_valid && card_valid && expiration_valid && cvc_valid) {
            pay_button.sensitive = true;
            cardDataDecrypt (); 
        } else {
            pay_button.sensitive = false;
            cardDataEncrypt (); 
        }
    }

    private void is_meta_empty () {
       empty = internal_xml.empty; 
        if (empty = true) {
        save_button.sensitive = false; 
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

        return (10 - (sum % 10)) % 10 == hash;
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                if (save_state == true) { 
                     add_cc_entry (card_number_entry.text, card_expiration_entry.text, card_cvc_entry.text);
                     cardDataDecrypt (); 
                    string str = card_number_entry.text;
                    // get last 4 digits
                    int len = str.char_count (); 
                    int start = 0;
                    int end = str.index_of_nth_char (len-4);    
                    

                    str = str.splice(start,end, ""); 
                    stdout.printf(@"[debug cnum]: $str\n");
                    stdout.printf("[debug count] start:%d end:%d",start,end);  
                    add_meta_entry(str); 
                     cardDataEncrypt ();
                     save_state = false;   
                }
                if (layouts.visible_child_name == "card") {
                    show_spinner_view ();
                    on_pay_clicked ();
                } else {
                    show_card_view ();
                }
                break;
            case Gtk.ResponseType.CLOSE:
                if (layouts.visible_child_name == "error") {
                    download_requested (); 
                }
                purge("cc.xml"); 
                destroy ();
                break;
            case Gtk.ResponseType.ACCEPT: 
                // Card Save action here
                string cardNumber = card_number_entry.text; 
                string cardCvc = card_cvc_entry.text; 
                string cardExpo = card_expiration_entry.text; 

                if (cardNumber == "") { 
                    cardNotify();  
                }
                
                 if (cardNumber != "") { 
                    cardNotify();           
                }
                // remove data from memory
                cardNumber = null; 
                cardCvc = null; 
                cardExpo = null; 
                break;  
        }
    }

    private void on_pay_clicked () {
        new Thread<void*> (null, () => {
            string expiration_dateyear = card_expiration_entry.text.replace("/", "");
            var year = (int.parse (expiration_dateyear[2:4]) + 2000).to_string ();

            var data = get_stripe_data (stripe_key, email_entry.text, (amount * 100).to_string (), card_number_entry.text, expiration_dateyear[0:2], year, card_cvc_entry.text);
            debug ("Stripe data:%s", data);
            string? error = null;
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (data);
                var root_object = parser.get_root ().get_object ();
                if (root_object != null && root_object.has_member ("id")) {
                    var token_id = root_object.get_string_member ("id");
                    string? houston_data = post_to_houston (stripe_key, app_id, token_id, email_entry.text, (amount * 100).to_string ());
                    if (houston_data != null) {
                        debug ("Houston data:%s", houston_data);
                        parser.load_from_data (houston_data);
                        root_object = parser.get_root ().get_object ();
                        if (root_object.has_member ("errors")) {
                            error = _(DEFAULT_ERROR_MESSAGE);
                        }
                    } else {
                        error = _(DEFAULT_ERROR_MESSAGE);
                    }
                } else if (root_object != null && root_object.has_member ("error")) {
                    error = get_stripe_error (root_object.get_object_member ("error"));
                } else {
                    error = _(DEFAULT_ERROR_MESSAGE);
                }
            } catch (GLib.Error e) {
                error = _(DEFAULT_ERROR_MESSAGE);
                debug (e.message);
            }

            Idle.add (() => {
                if (error != null) {
                    show_error_view (error);
                } else {
                    download_requested ();
                    destroy ();
                }

                return GLib.Source.REMOVE;
            });

            return null;
        });
    }

    private string get_stripe_data (string _key, string _email, string _amount, string _cc_num, string _cc_exp_month, string _cc_exp_year, string _cc_cvc) {
        var uri = STRIPE_URI.printf (_email, USER_AGENT, _amount, _cc_num, _cc_cvc, _cc_exp_month, _cc_exp_year, _key);
        var session = new Soup.Session ();
        var message = new Soup.Message ("POST", uri);
        session.send_message (message);

        var data = new StringBuilder ();
        foreach (var c in message.response_body.data) {
            data.append ("%c".printf (c));
        }

        return data.str;
    }

    private string post_to_houston (string _app_key, string _app_id, string _purchase_token, string _email, string _amount) {
        var uri = HOUSTON_URI.printf (_app_id, _app_key, _purchase_token, _email, _amount);
        var session = new Soup.Session ();
        var message = new Soup.Message ("POST", uri);
        session.send_message (message);

        var data = new StringBuilder ();
        foreach (var c in message.response_body.data) {
            data.append ("%c".printf (c));
        }

        return data.str;
    }

    private static unowned string get_stripe_error (Json.Object error_object) {
        if (error_object.has_member ("type")) {
            unowned string error_type = error_object.get_string_member ("type");
            debug ("Stripe error type: %s", error_type);
            switch (error_type) {
                case "card_error":
                    if (error_object.has_member ("code")) {
                        unowned string error_code = error_object.get_string_member ("code");
                        debug ("Stripe error code: %s", error_code);
                        switch (error_code) {
                            case "incorrect_number":
                            case "invalid_number":
                                return _("The card number is incorrect. Please try again using the correct card number.");
                            case "invalid_expiry_month":
                                return _("The expiration month is invalid. Please try again using the correct expiration date.");
                            case "invalid_expiry_year":
                                return _("The expiration year is invalid. Please try again using the correct expiration date.");
                            case "incorrect_cvc":
                            case "invalid_cvc":
                                return _("The CVC number is incorrect. Please try again using the correct CVC.");
                            case "expired_card":
                                return _("The card has expired. Please try again with a different card.");
                            case "processing_error":
                                return _(INTERNAL_ERROR_MESSAGE);
                            case "card_declined":
                                if (error_object.has_member ("decline_code")) {
                                    unowned string decline_code = error_object.get_string_member ("decline_code");
                                    debug ("Stripe decline error code: %s", decline_code);
                                    return get_stripe_decline_reason (decline_code);
                                } else {
                                    return _(DEFAULT_ERROR_MESSAGE);
                                }
                            default:
                                return _(DEFAULT_ERROR_MESSAGE);
                        }
                    } else {
                        return _(DEFAULT_ERROR_MESSAGE);
                    }
                case "validation_error":
                    return _(DEFAULT_ERROR_MESSAGE);
                case "rate_limit_error":
                    return _("There are too many payment requests at the moment, please retry later.");
                case "api_connection_error":
                case "api_error":
                case "authentication_error":
                case "invalid_request_error":
                default:
                    return _(INTERNAL_ERROR_MESSAGE);
            }
        } else {
            return _(DEFAULT_ERROR_MESSAGE);
        }
    }

    private static unowned string get_stripe_decline_reason (string decline_code) {
        switch (decline_code) {
            case "card_not_supported":
                return _("This card does not support this kind of transaction. Please try again with a different card.");
            case "currency_not_supported":
                return _("The currency is not supported by this card. Please try again with a different card.");
            case "duplicate_transaction":
                return _("The transaction has already been processed.");
            case "expired_card":
                return _("The card has expired. Please try again with a different card.");
            case "incorrect_zip":
                return _("The ZIP/Postal code is incorrect. Please try again using the correct ZIP/Postal code.");
            case "insufficient_funds":
                return _("You don't have enough funds. Please use an alternative payment method.");
            case "invalid_amount":
                return _("The amount is incorrect. Please try again using a valid amount.");
            case "incorrect_cvc":
            case "invalid_cvc":
                return _("The CVC number is incorrect. Please try again using the correct CVC.");
            case "invalid_expiry_year":
                return _("The expiration year is invalid. Please try again using the correct expiration date.");
            case "incorrect_number":
            case "invalid_number":
                return _("The card number is incorrect. Please try again using the correct card number.");
            case "incorrect_pin":
            case "invalid_pin":
                return _("The pin number is incorrect. Please try again using the correct pin.");
            case "pin_try_exceeded":
                return _("There has been too many pin attempts. Please try again with a different card.");
            case "call_issuer":
            case "do_not_honor":
            case "do_not_try_again":
            case "fraudulent":
            case "generic_decline":
            case "invalid_account":
            case "lost_card":
            case "new_account_information_available":
            case "no_action_taken":
            case "not_permitted":
            case "pickup_card":
            case "restricted_card":
            case "revocation_of_all_authorizations":
            case "revocation_of_authorization":
            case "security_violation":
            case "service_not_allowed":
            case "stolen_card":
            case "stop_payment_order":
            case "transaction_not_allowed":
                return _("Unable to complete the transaction. Please contact your bank for further information.");
            case "card_velocity_exceeded":
            case "withdrawal_count_limit_exceeded":
                return _("The balance or credit limit on the card has been reached.");
            case "live_mode_test_card":
            case "testmode_decline":
                return _("The given card is a test card. Please use a real card to proceed.");
            case "approve_with_id":
            case "issuer_not_available":
            case "processing_error":
            case "reenter_transaction":
            case "try_again_later":
                return _(INTERNAL_ERROR_MESSAGE);
            default:
                return _(DEFAULT_ERROR_MESSAGE);
        }
    }
    
    private bool loadMetaData() { 
        AppCenter.Services.XmlParser internal_xml = new AppCenter.Services.XmlParser (); 
        stdout.printf("[Loading cc meta-data]\n"); 
        string parent = null; 
        localuser = user();
        string path = (@"/home/$localuser/appcenter/meta_cc.xml");
        internal_xml.xml_parse_filepath(path);
        stdout.printf("[cc meta-data loaded]\n");

        return internal_xml.empty;  
        
    } 

    private void loadccData() {
        stdout.printf("[Loading cc data]\n");
        cardDataDecrypt ();  
        string path = (@"/home/$localuser/appcenter/cc.xml");
        internal_xml.xml_parse_filepath(path); 
        stdout.printf("[cc data loaded]\n");
    }

    private void delete_meta_entry (string target) {         

        loadMetaData (); 
        var file = File.new_for_path (@"/home/$localuser/appcenter/meta_cc.xml");
        if(!file.query_exists ()) { 
            stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
        } 

        var nodes = new Gee.ArrayList<string> ();
        nodes = internal_xml.node_content_list;
        int i = 0; 
        try {
        purge("meta_cc.xml"); 
        FileOutputStream os = file.create (FileCreateFlags.PRIVATE); 
        os.write ("<cards>\n".data);   
        foreach (string element in nodes) {
            i++; 
            if (!element.contains(target)) {
                os.write (" <card>\n".data);
                os.write (@"     <cNum>$element</cNum>\n".data);
                os.write (" </card>\n".data); 
            } 
        }
        if(i == 1) {
  
            os.write (" <card>\n".data);
            os.write (@"     <cNum></cNum>\n".data);
            os.write (" </card>\n".data);
            os.write ("</cards>\n".data); 
            stdout.printf ("-- meta_cc.xml [target deleted]\n"); 
        } 
        else {
        os.write ("</cards>".data); 
        stdout.printf ("-- meta_cc.xml [target deleted]\n"); 
        }
        } 
    catch (Error e) {
        stdout.printf("Error: %s\n", e.message); 
    }
    }

    private void add_meta_entry (string target) {
        loadMetaData (); 
        var file = File.new_for_path (@"/home/$localuser/appcenter/meta_cc.xml");
        if(!file.query_exists ()) { 
            stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
        } 

        var nodes = new Gee.ArrayList<string> ();
        nodes = internal_xml.node_content_list;
       

        nodes.add (target); 

        try {
        purge("meta_cc.xml");
        FileOutputStream os = file.create (FileCreateFlags.PRIVATE); 
        os.write ("<cards>\n".data);  

        foreach (string element in nodes) {
            if (element !="") {
                os.write (" <card>\n".data);
                os.write (@"     <cNum>$element</cNum>\n".data);
                os.write (" </card>\n".data); 
            }
        } 
        os.write ("</cards>".data); 
        stdout.printf ("-- meta_cc.xml [target added]\n"); 
        } 
    catch (Error e) {
        stdout.printf("Error: %s\n", e.message); 
    }
    } 
    

    private void delete_cc_entry (string target) {
        loadccData (); 
        var file = File.new_for_path (@"/home/$localuser/appcenter/cc.xml");

        bool first_pass = false; 
        bool second_pass = false;
        bool skip = false;  
        var nodes = new Gee.ArrayList<string> ();
        nodes = internal_xml.node_content_list;
        purge("cc.xml"); 
        FileOutputStream os = file.create (FileCreateFlags.PRIVATE);  
        try {
        
        os.write ("<cards>\n".data);  
        int i =0; 

        foreach (string element in nodes) {
            i++; 
            if(element.contains(target)) {
                skip = true; 
            }

            // checks to see if index is even 
            if (first_pass == true && second_pass == true ) {
                if(skip == false) { 
                // 3rd pass logic
                os.write (@" <cvc>$element</cvc>\n".data);  
                os.write (@" </card>\n".data); 
                stdout.printf(@"[CVC Number] $element\n");
 
                first_pass = false; 
                second_pass = false; 

            }
                skip = false;
                first_pass = false; 
                second_pass = false;   
            }

            else { 

            if (second_pass == false) {
                 
                if (first_pass == false)  {
                    first_pass = true; 
                    // First Pass Logic
                    if (skip == false) {
                    
                    os.write (@"<card>\n".data); 
                    os.write (@" <cnum>$element</cnum>\n".data);  
                    stdout.printf(@"[Card Number] $element\n");

                }
                }
                else {
                    second_pass = true; 
                    // Second Pass Logic
                    if (skip == false) {
                    os.write (@" <expo>$element</expo>\n".data); 
            
                    stdout.printf(@"[Expo Date] $element\n");
                    }
                }
                } 

            
            
        }
            
    }

   if (i == 3) {
        os.write (" <card>\n".data);
        os.write (@"     <cNum></cNum>\n".data);
        os.write (@"     <expo></expo>\n".data);
        os.write (@"     <cvc></cvc>\n".data); 
        os.write (" </card>\n".data);
        os.write ("</cards>\n".data);
        stdout.printf ("-- cc.xml [target deleted]\n");  
   } 

   else { 
         os.write (@" </cards>\n".data); 
    stdout.printf ("-- cc.xml [target deleted]\n");  
   }
 
    } 
    catch (Error e) {
        stdout.printf("Error: %s\n", e.message); 
        } 
    }

    private void add_cc_entry (string cnum, string expo, string cvc) {
        cardDataDecrypt ();
        loadccData(); 
        var file = File.new_for_path (@"/home/$localuser/appcenter/cc.xml");

        bool first_pass = false; 
        bool second_pass = false;
        bool skip = false;  
        var nodes = new Gee.ArrayList<string> ();
        nodes = internal_xml.node_content_list;
        
        
        nodes.add(cnum); 
        nodes.add(expo); 
        nodes.add(cvc); 

        try {
        purge("cc.xml");
        purge("cc.xml.aes"); 
        FileOutputStream os = file.create (FileCreateFlags.PRIVATE); 
        os.write ("<cards>\n".data);  
        foreach (string element in nodes) {
            if (first_pass == true && second_pass ==true) {
                if(element != "") {
                    os.write (@"     <cvc>$element</cvc>\n".data);
                    os.write (" </card>\n".data);  

                    first_pass = false; 
                    second_pass = false;
                    continue;  
                }
                 first_pass = false; 
                second_pass = false;
                continue; 
            }
        

            if (second_pass == false) {
                if (first_pass == false) {
                    first_pass = true; 
                    // First Pass Logic 
                    if(element != "") {
                    os.write (" <card>\n".data); 
                        os.write (@"     <cNum>$element</cNum>\n".data); 
                }
                }
                else {
                    second_pass = true; 
                    if(element != "") { 
                    // Second Pass Logic 
                        
                        os.write (@"     <expo>$element</expo>\n".data);
            }
                }
                }
            
         
        
        }
    
    os.write ("</cards>".data); 
        stdout.printf ("-- cc.xml [target deleted]\n"); 
    }
        catch (Error e) { 
            stderr.printf("Error: %s\n", e.message); 
        }
          
    }

        
    private void cardNotify () { 
        cardDataDecrypt (); 
        GLib.Menu menu = new GLib.Menu ();  
        loadMetaData(); 
        string selected = null; 
        var nodes = new Gee.ArrayList<string> ();
        var numbers  = new Gee.ArrayList<string> ();
        Gtk.Popover pop = new Gtk.Popover (save_button);

        nodes = internal_xml.node_content_list;
        
        menu.append ("Your Saved Cards", "label");
         
        int i = 0;
    
        foreach (string element in nodes) {

            if (element.length > 3){
                numbers.add(@"$element"); 
                i++; 
            }
        
            else {
                menu.append ("No cards have been saved", null);
             }
        }
   
        

         
        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0); 

        box.margin_right = 10; 
        box.margin_left = 10; 
        box.margin_top = 5; 
        box.margin_bottom = 5; 
        box.set_spacing(5); 
 
        Gtk.Label label = new Gtk.Label( "Your saved cards");
        box.pack_start (label, false, false, 0);  

        // The buttons:
        if (nodes[0].length > 3) { 
          
		    Gtk.RadioButton button1 = new Gtk.RadioButton.with_label_from_widget (null,"");

            Gtk.RadioButton button;  
       
            foreach (string element in nodes) {

		    button = new Gtk.RadioButton.with_label_from_widget (button1, @"Use card ending in $element");
		    box.pack_start (button, false, false, 0);
		    button.toggled.connect (() => { 
            stdout.printf("button trigered\n");
            //button.set_active (true);  
            // card_number_entry.text = @"xxxx-xxxx-$element";
            selected = element; 
            trigered = true;  
             
        }); 
        }

    } 
        else {
        
        pop.bind_model (menu, null);
        pop.show_all (); 
        pop.set_visible (true); 
    }

      Gtk.Grid grid = new Gtk.Grid (); 
      grid.column_spacing = 24;

       Gtk.Button apply_button = new Gtk.Button.with_label ("Use"); 
        apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        apply_button.clicked.connect (() => { 
            
            getCardInfo (selected);
            cardDataEncrypt ();  

             pop.hide (); 
        });

      Gtk.Button delete_button = new Gtk.Button.with_label ("Delete"); 
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        delete_button.clicked.connect (() => {
            // action function
            
            delete_meta_entry(selected); 
            delete_cc_entry(selected);
            purge("cc.xml.aes"); 
            cardDataEncrypt ();
             pop.hide (); 
        });

        box.pack_start(grid, false,false,0);  

        grid.attach(delete_button, 0,0,4,3);
        grid.attach(apply_button,12,0,4,3); 


        
		// button1.set_active (true);
        // button.set_active (false); 
          
        //grid.attach(button1, 0, 0, 7, 1);
        //grid.attach(button2, 0, 4, 7, 1);
        //grid.attach(button3, 0, 8, 7, 1);
         
        pop.add(box);  
        // pop.bind_model (menu, null);
        //box.pack_start(lb, expand);
        //box.pack_start (new Gtk.Label ("1"), false, false, 0);
        pop.show_all (); 
        pop.set_visible (true); 
     
    
   
        

		
        
    }

    
 
    /* Pending for rewrite */       
    private void cardDataEncrypt() {
        // Data Encryption & Storage here 
        string strongkey ="";
        var attributes = new GLib.HashTable<string,string> (str_hash, str_equal); 
        attributes["size"] = "78"; 
        attributes["type"] = "appcenter"; 
        var appCenterS = new Secret.Schema ("org.appcenter.Password", Secret.SchemaFlags.NONE,
                                            "size", Secret.SchemaAttributeType.INTEGER,
                                            "type", Secret.SchemaAttributeType.STRING);
         
        // Search for key 
        Secret.password_lookupv.begin (appCenterS, attributes, null, (obj, async_res) => {
            string password = (string) Secret.password_lookup.end (async_res);

        if (password.length < 3 ) {
            password = (string) keyGen(); 
        }  

        else {
            stdout.printf("[password found]\n"); 
        }

        // debug for keygen 
        /*
        stdout.printf("[ Forced Key Regeneration ]"); 
        password = keyGen (); 
         */

        stdout.printf ("[user] " + localuser +"\n"); 
        stdout.printf ("[key] " + password +"\n");

        try { 
            string[] spawn_args = {"aescrypt", "-e", "-p",  @"$password", "cc.xml"};
            string[] spawn_args2 = {"shred", "-n", "3", "-u", "-z", "cc.xml"}; 
            string[] spawn_env = Environ.get ();
		    string ls_stdout;
		    string ls_stderr;
		    int ls_status;
            Process.spawn_sync(@"/home/$localuser/appcenter/",
            spawn_args,
            spawn_env,
            SpawnFlags.SEARCH_PATH,
			null,
			out ls_stdout,
			out ls_stderr,
			out ls_status);
            Process.spawn_sync(@"/home/$localuser/appcenter/",
            spawn_args2,
            spawn_env,
            SpawnFlags.SEARCH_PATH,
			null,
			out ls_stdout,
			out ls_stderr,
			out ls_status);
        } catch (SpawnError e) {
		    stdout.printf ("Error: %s\n", e.message);
            }
            
            stdout.printf("[Unencrypted file] Purged");  
            stdout.printf("[Encrypt complete]");  
       
     });
       
    }
    
    private void purge (string file) {

            try {

            string[] spawn_args = {"shred", "-n", "3", "-u", "-z",@"$file"}; 
            string[] spawn_env = Environ.get ();
		    string ls_stdout;
		    string ls_stderr;
		    int ls_status;
            Process.spawn_sync(@"/home/$localuser/appcenter/",
            spawn_args,
            spawn_env,
            SpawnFlags.SEARCH_PATH,
			null,
			out ls_stdout,
			out ls_stderr,
			out ls_status);
        } catch (SpawnError e) {
		    stdout.printf ("Error: %s\n", e.message);
            }
            
            stdout.printf("[Unencrypted file] Purged");  
            stdout.printf("[Encrypt complete]");  
       
     }

    private string keyGen() {  
        
        var keybuild = new StringBuilder(); 
        string strongkey;
        var builder = new StringBuilder();
        var attributes = new GLib.HashTable<string,string> (str_hash, str_equal); 
        attributes["size"] = "78"; 
        attributes["type"] = "appcenter"; 
        Cancellable cancellable = new Cancellable ();
        
        var appCenterS = new Secret.Schema ("org.appcenter.Password", Secret.SchemaFlags.NONE,
                                            "size", Secret.SchemaAttributeType.INTEGER,
                                            "type", Secret.SchemaAttributeType.STRING);
        
        stdout.printf ("[appcenter] unable to find key, generating a new key\n"); 
         /*Keygen starts*/

        int i =0;
        while(i < 12) { //12 
        // Generates a passkey 
         keybuild.append_unichar("ABCDEFGHIJKLMNOPQRSTUVWZWZabcdefghijklmnopqrstuvwxyz0123456789@#$%"[Random.int_range (0,66)]);
         builder.append( (string) keybuild.str); 
         i ++; 
        }
        strongkey = builder.str; 
         /*Keygen ends */
        
        Secret.password_storev.begin (appCenterS,attributes,Secret.COLLECTION_DEFAULT,"acc",strongkey,null,(obj,async_res) => {
            bool res = Secret.password_store.end(async_res); 
            /*Password Stored - complete additional processes */
            stdout.printf ("[password stored]\n"); 
            }); 

        return strongkey; 
    } 

    private void cardDataDecrypt() {

        stdout.printf("[File Decrypt]\n ");
        var attributes = new GLib.HashTable<string,string> (str_hash, str_equal); 
        attributes["size"] = "78"; 
        attributes["type"] = "appcenter"; 
        var appCenterS = new Secret.Schema ("org.appcenter.Password", Secret.SchemaFlags.NONE,
                                            "size", Secret.SchemaAttributeType.INTEGER,
                                            "type", Secret.SchemaAttributeType.STRING); 
					    
         Secret.password_lookupv.begin(appCenterS,attributes,null,(obj,async_res) => {
            string token = Secret.password_lookup.end (async_res);  
        if (token.length < 3 ) {
            token = (string) keyGen(); 
        }

        stdout.printf(@"[key]: $token\n"); 

          try { 
            string[] spawn_args = {"aescrypt", "-d", "-p", @"$token", "cc.xml.aes"};
            string[] spawn_env = Environ.get ();
		    string ls_stdout;
		    string ls_stderr;
		    int ls_status;
            Process.spawn_sync(@"/home/$localuser/appcenter/",
            spawn_args,
            spawn_env,
            SpawnFlags.SEARCH_PATH,
			null,
			out ls_stdout,
			out ls_stderr,
			out ls_status);
        } catch (SpawnError e) {
		    stdout.printf ("Error: %s\n", e.message);
            }

            stdout.printf("[File Unencrypted]\n ");  
        
    });


        
        }

    /* Pending of rewrite */
    private void getCardInfo(string short_card_num) {
        loadccData ();
        var nodes = new Gee.ArrayList<string> ();
        var card_number = new Gee.ArrayList<string> (); 
        var card_expo = new Gee.ArrayList<string> (); 
        var card_cvc = new Gee.ArrayList<string> (); 
        nodes = internal_xml.node_content_list;
        
        bool first_pass = false; 
        bool second_pass = false; 
        int cards = 0; 
        int i = 1;

        foreach (string element in nodes) {
            // checks to see if index is even 
            if (first_pass == true && second_pass == true ) {
                // 3rd pass logic
                stdout.printf(@"[CVC Number] $element\n");
                card_cvc.add(element); 

                i++;  
                cards ++; 
                first_pass = false; 
                second_pass = false;
                stdout.printf(@"--------------------------\n"); 
            }

            else { 

            if (second_pass == false) {
                if (first_pass == false)  {
                    first_pass = true; 
                    // First Pass Logic
                    stdout.printf(@"---------Card $i ------------\n");
                    
                    stdout.printf(@"[Card Number] $element\n");
                    card_number.add(element); 

                }
                else {
                    second_pass = true; 
                    // Second Pass Logic
                    stdout.printf(@"[Expo Date] $element\n");
                    card_expo.add(element);  

                }

            }
            
        }

    }
    
        int y = 0; 
        i = i-1; 
        while (y < i) {
            if(card_number[y].contains(short_card_num)) {
                card_number_entry.text = card_number[y]; 
                card_cvc_entry.text = card_cvc[y]; 
                card_expiration_entry.text = card_expo[y]; 
            } 
            y++; 
        }

        stdout.printf("[done lodaing card]\n"); 

    }



    private static Act.UserManager? usermanager = null;

    public static unowned Act.UserManager? get_usermanager () {
        if (usermanager != null && usermanager.is_loaded)
            return usermanager;

        usermanager = Act.UserManager.get_default ();
        return usermanager;
    }

    private void init_user() {
        user(); 
    }
    private string user() {
        // Get user name 
        return real_name =ActiveUser.get_user_name (); 

    }
}
