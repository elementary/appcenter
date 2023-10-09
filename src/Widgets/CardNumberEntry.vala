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

    private AppCenterCore.CardUtils.CardType card_type = AppCenterCore.CardUtils.CardType.UNKNOWN;
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
            update_number ();
            card_type = AppCenterCore.CardUtils.detect_card_type (card_number);
            change_card_icon ();

            int[] pattern = card_type.get_pattern ();
            var number_chars = card_number.to_utf8 ();
            var builder = new GLib.StringBuilder ();
            for (int i = 0; i < number_chars.length; i++) {
                builder.append_c (number_chars[i]);
                if ((insertion || i + 1 != number_chars.length) && (i + 1) in pattern) {
                    builder.append_c (' ');
                }
            }

            if (text != builder.str) {
                var end_offset = (text.char_count () - 1) - cursor_position;
                text = builder.str;
                var new_offset = (text.char_count () - 1) - cursor_position;
                if (end_offset != new_offset) {
                    Idle.add (() => {
                        set_position (new_offset + end_offset + 1);
                        return false;
                    });
                }
            }

            max_length = card_type.get_max_length () + pattern.length;
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

    private void change_card_icon () {
        switch (card_type) {
            case AppCenterCore.CardUtils.CardType.VISA:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-visa");
                break;
            case AppCenterCore.CardUtils.CardType.MASTERCARD:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-mastercard");
                break;
            case AppCenterCore.CardUtils.CardType.AMERICAN_EXPRESS:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-amex");
                break;
            case AppCenterCore.CardUtils.CardType.DISCOVER:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-discover");
                break;
            case AppCenterCore.CardUtils.CardType.DINERS_CLUB:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-diners-club");
                break;
            case AppCenterCore.CardUtils.CardType.JCB:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-jcb");
                break;
            case AppCenterCore.CardUtils.CardType.UNIONPAY:
                secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("payment-card-unionpay");
                break;
            default:
                secondary_icon_gicon = null;
                break;
        }
    }
}
