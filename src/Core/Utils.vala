/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

namespace AppCenterCore.Utils {
    public static Pk.Bitfield bitfield_from_filter (Pk.Filter filter) {
        return Pk.Filter.bitfield_from_string (Pk.Filter.enum_to_string (filter));
    }

    public static Pk.Bitfield bitfield_from_group (Pk.Group group) {
        return Pk.Group.bitfield_from_string (Pk.Group.enum_to_string (group));
    }

    public static Pk.Bitfield bitfield_from_transaction_flag (Pk.TransactionFlag transaction_flag) {
        return Pk.TransactionFlag.bitfield_from_string (Pk.TransactionFlag.enum_to_string (transaction_flag));
    }

    public static Pk.Bitfield bitfield_from_role (Pk.Role role) {
        return Pk.Role.bitfield_from_string (Pk.Role.enum_to_string (role));
    }
}
