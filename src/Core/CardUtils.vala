/*-
 * Copyright (c) 2023 elementary LLC. (https://elementary.io)
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
 */

public class AppCenterCore.CardUtils {
    public enum CardType {
        UNKNOWN,
        VISA,
        MASTERCARD,
        AMERICAN_EXPRESS,
        UNIONPAY,
        DINERS_CLUB,
        DISCOVER,
        JCB;

        // The numbers represents the position of the spaces
        public int[] get_pattern () {
            switch (this) {
                case AppCenterCore.CardUtils.CardType.AMERICAN_EXPRESS:
                case AppCenterCore.CardUtils.CardType.DINERS_CLUB:
                    return {4, 10};
                case AppCenterCore.CardUtils.CardType.VISA:
                case AppCenterCore.CardUtils.CardType.MASTERCARD:
                case AppCenterCore.CardUtils.CardType.DISCOVER:
                case AppCenterCore.CardUtils.CardType.JCB:
                case AppCenterCore.CardUtils.CardType.UNIONPAY:
                default:
                    return {4, 8, 12};
            }
        }

        public int get_max_length () {
            switch (this) {
                case AppCenterCore.CardUtils.CardType.AMERICAN_EXPRESS:
                    return 15;
                case AppCenterCore.CardUtils.CardType.MASTERCARD:
                    return 16;
                case AppCenterCore.CardUtils.CardType.VISA:
                case AppCenterCore.CardUtils.CardType.DISCOVER:
                case AppCenterCore.CardUtils.CardType.DINERS_CLUB:
                case AppCenterCore.CardUtils.CardType.JCB:
                case AppCenterCore.CardUtils.CardType.UNIONPAY:
                default:
                    return 19;
            }
        }
    }

    public static CardType detect_card_type (string number) {
        if (number.has_prefix ("4")) {
            return CardType.VISA;
        }

        if (GLib.Regex.match_simple ("^(?:5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[01]|2720)", number)) {
            return CardType.MASTERCARD;
        }

        if (number.has_prefix ("34") || number.has_prefix ("37")) {
            return CardType.AMERICAN_EXPRESS;
        }

        if (number.has_prefix ("62")) {
            return CardType.UNIONPAY;
        }

        if (GLib.Regex.match_simple ("^(2[01]([2-4]|1[4-9])|36|30([0-5]|95)|3[89])", number)) {
            return CardType.DINERS_CLUB;
        }

        if (GLib.Regex.match_simple ("^(6011|6[45])", number)) {
            return CardType.DISCOVER;
        }

        if (GLib.Regex.match_simple ("^(35([3-8]|2[89]))", number)) {
            return CardType.JCB;
        }

        return CardType.UNKNOWN;
    }

    // Checks whether a credit card number is valid
    public static bool is_card_valid (string numbers) {
        var char_count = numbers.char_count ();

        if (char_count < 14) return false;

        int hash = int.parse (numbers[char_count - 1:char_count]);

        int j = 1;
        int sum = 0;
        for (int i = char_count - 1; i > 0; i--) {
            var number = int.parse (numbers[i - 1:i]);
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
}
