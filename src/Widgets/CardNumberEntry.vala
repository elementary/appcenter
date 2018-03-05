/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
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

public class AppCenter.Widgets.CardNumberEntry : Gtk.Entry {
    public string card_number { get; set; }

    private enum CardType {
        UNKNOWN,
        VISA,
        MASTERCARD,
        AMERICAN_EXPRESS,
        DISCOVER,
        DINERS_CLUB,
        JCB,
        UNIONPAY
    }

    private CardType card_type = CardType.UNKNOWN;
    private uint timeout = 0;
    private bool insertion = true;

    construct {
        input_purpose = Gtk.InputPurpose.DIGITS;
        max_length = 26;
        placeholder_text = _("Card Number");
        primary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-symbolic");
        delete_text.connect ((start_pos, end_pos) => {
            insertion = false;
        });

        insert_text.connect ((start_pos, end_pos, ref pos) => {
            insertion = true;
        });

        changed.connect (() => {
            if (timeout > 0) {
                GLib.Source.remove (timeout);
            }
            update_number ();
            detect_card ();
            change_card_icon ();
            int[] pattern = get_card_pattern ();
            var number_chars = card_number.to_utf8 ();
            var builder = new GLib.StringBuilder ();
            for (int i = 0; i < number_chars.length; i++) {
                builder.append_c (number_chars[i]);
                if ((insertion || i+1 != number_chars.length) && (i+1) in pattern) {
                    builder.append_c (' ');
                }
            }

            var end_offset = (text.char_count ()-1) - cursor_position;
            text = builder.str;
            var new_offset = (text.char_count ()-1) - cursor_position;
            if (end_offset != new_offset) {
                Idle.add (() => {
                    move_cursor (Gtk.MovementStep.LOGICAL_POSITIONS, new_offset - end_offset, false);
                    return false;
                });
            }

            max_length = get_card_max_length () + pattern.length;
        });
    }

    private void update_number () {
        try {
            var regex = new GLib.Regex ("[^0-9]");
            card_number = regex.replace_literal (text, -1, 0, "");
        } catch (Error e) {
            critical (e.message);
            card_number = text;
        }
    }

    private void detect_card () {
        var number = card_number;

        if (number.has_prefix ("4")) {
            card_type = CardType.VISA;
            return;
        }

        if (GLib.Regex.match_simple ("^(?:5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[01]|2720)", number)) {
            card_type = CardType.MASTERCARD;
            return;
        }

        if (number.has_prefix ("34") || number.has_prefix ("37")) {
            card_type = CardType.AMERICAN_EXPRESS;
            return;
        }

        if (number.has_prefix ("62")) {
            card_type = CardType.UNIONPAY;
            return;
        }

        if (GLib.Regex.match_simple ("^(2[01]([2-4]|1[4-9])|36|30([0-5]|95)|3[89])", number)) {
            card_type = CardType.DINERS_CLUB;
            return;
        }

        if (GLib.Regex.match_simple ("^(6011|6[45])", number)) {
            card_type = CardType.DISCOVER;
            return;
        }

        if (GLib.Regex.match_simple ("^(35([3-8]|2[89]))", number)) {
            card_type = CardType.JCB;
            return;
        }

        card_type = CardType.UNKNOWN;
    }

    private void change_card_icon () {
        switch (card_type) {
            case CardType.VISA:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-visa");
                break;
            case CardType.MASTERCARD:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-mastercard");
                break;
            case CardType.AMERICAN_EXPRESS:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-amex");
                break;
            case CardType.DISCOVER:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-discover");
                break;
            case CardType.DINERS_CLUB:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-diners-club");
                break;
            case CardType.JCB:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-jcb");
                break;
            case CardType.UNIONPAY:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-unionpay");
                break;
            default:
                secondary_icon_gicon = null;
                break;
        }
    }

    // The numbers represents the position of the spaces
    private int[] get_card_pattern () {
        switch (card_type) {
            case CardType.AMERICAN_EXPRESS:
            case CardType.DINERS_CLUB:
                return {4, 10};
            case CardType.VISA:
            case CardType.MASTERCARD:
            case CardType.DISCOVER:
            case CardType.JCB:
            case CardType.UNIONPAY:
            default:
                return {4, 8, 12};
        }
    }

    private int get_card_max_length () {
        switch (card_type) {
            case CardType.AMERICAN_EXPRESS:
                return 15;
            case CardType.MASTERCARD:
                return 16;
            case CardType.VISA:
            case CardType.DISCOVER:
            case CardType.DINERS_CLUB:
            case CardType.JCB:
            case CardType.UNIONPAY:
            default:
                return 19;
        }
    }
}
