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
    public class Details : Info {
        public string description   { public get; private set; }
        public string license       { public get; private set; }
        public uint64 size          { public get; private set; }
        public string url           { public get; private set; }

        public Details (string package_name) {
            this.package_name = package_name;

            //make sure properties are initialized
            loaded = false;
            description = "";
            license = "";
            package_id = "";
            size = 0;
            url = "";

            Pk.Task task = new Pk.Task ();
            task.get_details_async.begin ({package_name, null}, null, () => { }, (obj, res) => {
                try {
                    Pk.Results results = task.generic_finish (res);
                    var details_array = results.get_details_array ();

                    if (details_array.length == 1) {
                        results.get_details_array ().foreach ((detail) => {
                            loaded = true;
                            description = detail.description;
                            license = detail.license;
                            package_id = detail.package_id;
                            size = detail.size;
                            url = detail.url;

                            //generating display properties for the AppInfoView
                            display_name = detail.package_id.slice (0, detail.package_id.index_of (";"));

                            int start = detail.package_id.index_of (";") + 1;
                            int end = detail.package_id.index_of (";", start);
                            display_version = detail.package_id.slice (start, end);

                            // The part of ID about Ubuntu version should be dropped. 
                            // This way the package will be installed, 
                            // no matter which Ubuntu version you are on.
                            // This turns something like: maya-calendar;0.3.1.1+r811+pkg70~daily~ubuntu15.04.1;amd64;vervet
                            // into something like: maya-calendar;0.3.1.1+r811+pkg70~daily~ubuntu15.04.1;amd64;
                            package_id =  detail.package_id.slice (0, 
                                detail.package_id.index_of (";", end + 1) + 1);

                            debug ("Loading AppInfo data for '%s' finished.", package_name);
                            loading_finished ();
                        });
                    } else
                        warning ("AppInfo did not found one matching package! Data not loaded.");
                } catch (Error e) {
                    warning (e.message);
                }
            });
        }
    }
}
