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

namespace AppCenterCore {
    public class Summary : Info {
        public Summary (string package_id) {
            this.package_id = package_id;
            this.display_name = this.package_id.slice (0, this.package_id.index_of (";"));

            //TODO: Load data from database based on package_id

            loading_finished ();
            loaded = true;
        }
    }
}
