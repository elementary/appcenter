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
    public class Info : Object {
        public string   package_id      { public get; protected set; }
        public string   package_name    { public get; protected set; }
        public string   display_name    { public get; protected set; }
        public string   display_icon    { public get; protected set; }
        public string   display_version { public get; protected set; }
        public bool     installed       { public get; protected set; }
        public bool     loaded          { public get; protected set; }

        public signal void loading_finished ();

        //protected Info () { }
    }
}
