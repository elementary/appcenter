/* Copyright 2018 elementary, Inc. (https://elementary.io)
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

namespace Utils {
    public void shuffle_array<T> (T[] array) {
        // https://gitlab.gnome.org/GNOME/vala/issues/7
        var rand = new GLib.Rand ();
        for (int i = 0; i < array.length * 3; i++) {
            swap (&array[0], &array[rand.int_range(1, array.length)]);
        }
    }

    public void swap<T> (T *x, T *y) {
        var tmp = *x;
        *x = *y;
        *y = tmp;
    }


    public void reboot () {
        try {
            SuspendControl.get_default ().reboot ();
        } catch (GLib.Error e) {
            var dialog = new AppCenter.Widgets.RestartDialog ();
            dialog.show_all ();
        }
    }

    public uint get_file_age (GLib.File file)
    {
	    var info = file.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);

	    if (info == null) {
            return uint.MAX;
        }

	    uint64 mtime = info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
	    uint64 now = (uint64) get_real_time () / 1000000;

	    if (mtime > now) {
		    return uint.MAX;
        }

	    if (now - mtime > uint.MAX) {
		    return uint.MAX;
        }

	    return (uint) (now - mtime);
    }
}

