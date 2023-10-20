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

void add_card_tests () {
    Test.add_func ("/detect_card_type/amex", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("375556917985515") == AppCenterCore.CardUtils.CardType.AMERICAN_EXPRESS);
        assert (AppCenterCore.CardUtils.detect_card_type ("378282246310005") == AppCenterCore.CardUtils.CardType.AMERICAN_EXPRESS);
    });

    Test.add_func ("/detect_card_type/diners_club", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("30569309025904") == AppCenterCore.CardUtils.CardType.DINERS_CLUB);
        assert (AppCenterCore.CardUtils.detect_card_type ("36050234196908") == AppCenterCore.CardUtils.CardType.DINERS_CLUB);
    });

    Test.add_func ("/detect_card_type/visa", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("4716461583322103") == AppCenterCore.CardUtils.CardType.VISA);
        assert (AppCenterCore.CardUtils.detect_card_type ("4716989580001715211") == AppCenterCore.CardUtils.CardType.VISA);
        assert (AppCenterCore.CardUtils.detect_card_type ("4716221051885662") == AppCenterCore.CardUtils.CardType.VISA);
        assert (AppCenterCore.CardUtils.detect_card_type ("4929722653797141") == AppCenterCore.CardUtils.CardType.VISA);
    });

    Test.add_func ("/detect_card_type/mastercard", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("5555555555554444") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("5105105105105100") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223000048400011") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223016768739313") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223026768739312") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223036768739311") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223046768739310") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223056768739319") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223066768739318") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223076768739317") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223086768739316") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223096768739315") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223806768739314") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223816768739313") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2223826768739312") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("5398228707871527") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2222155765072228") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2225855203075256") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2718760626256570") == AppCenterCore.CardUtils.CardType.MASTERCARD);
        assert (AppCenterCore.CardUtils.detect_card_type ("2720428011723762") == AppCenterCore.CardUtils.CardType.MASTERCARD);
    });

    Test.add_func ("/detect_card_type/jcb", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("3530111333300000") == AppCenterCore.CardUtils.CardType.JCB);
        assert (AppCenterCore.CardUtils.detect_card_type ("3566002020360505") == AppCenterCore.CardUtils.CardType.JCB);
    });

    Test.add_func ("/detect_card_type/discover", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("6011111111111117") == AppCenterCore.CardUtils.CardType.DISCOVER);
        assert (AppCenterCore.CardUtils.detect_card_type ("6011000990139424") == AppCenterCore.CardUtils.CardType.DISCOVER);
    });

    Test.add_func ("/detect_card_type/unionpay", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("6228223624220258") == AppCenterCore.CardUtils.CardType.UNIONPAY);
        assert (AppCenterCore.CardUtils.detect_card_type ("6226050967750613") == AppCenterCore.CardUtils.CardType.UNIONPAY);
        assert (AppCenterCore.CardUtils.detect_card_type ("6234917882863855") == AppCenterCore.CardUtils.CardType.UNIONPAY);
        assert (AppCenterCore.CardUtils.detect_card_type ("6234698580215388") == AppCenterCore.CardUtils.CardType.UNIONPAY);
        assert (AppCenterCore.CardUtils.detect_card_type ("6246281879460688") == AppCenterCore.CardUtils.CardType.UNIONPAY);
        assert (AppCenterCore.CardUtils.detect_card_type ("6263892624162870") == AppCenterCore.CardUtils.CardType.UNIONPAY);
        assert (AppCenterCore.CardUtils.detect_card_type ("6283875070985593") == AppCenterCore.CardUtils.CardType.UNIONPAY);
    });

    Test.add_func ("/detect_card_type/unknown", () => {
        assert (AppCenterCore.CardUtils.detect_card_type ("1234567890123456") == AppCenterCore.CardUtils.CardType.UNKNOWN);
    });

    Test.add_func ("/is_card_valid/valid_numbers", () => {
        assert (AppCenterCore.CardUtils.is_card_valid ("375556917985515") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("378282246310005") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("30569309025904") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("36050234196908") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("4716461583322103") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("4716989580001715211") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("4716221051885662") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("4929722653797141") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("5555555555554444") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("5105105105105100") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223000048400011") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223016768739313") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223026768739312") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223036768739311") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223046768739310") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223056768739319") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223066768739318") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223076768739317") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223086768739316") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223096768739315") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("5398228707871527") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2222155765072228") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2225855203075256") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2718760626256570") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("2720428011723762") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("3530111333300000") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("3566002020360505") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6011111111111117") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6011000990139424") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6228223624220258") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6226050967750613") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6234917882863855") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6234698580215388") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6246281879460688") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6263892624162870") == true);
        assert (AppCenterCore.CardUtils.is_card_valid ("6283875070985593") == true);
    });

    Test.add_func ("/is_card_valid/invalid_numbers", () => {
        assert (AppCenterCore.CardUtils.is_card_valid ("1234567890123456") == false);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223806768739314") == false);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223816768739313") == false);
        assert (AppCenterCore.CardUtils.is_card_valid ("2223826768739312") == false);
    });

    Test.add_func ("/is_card_valid/short", () => {
        assert (AppCenterCore.CardUtils.is_card_valid ("41111111111") == false);
    });

    Test.add_func ("/is_card_valid/empty", () => {
        assert (AppCenterCore.CardUtils.is_card_valid ("") == false);
    });
}
