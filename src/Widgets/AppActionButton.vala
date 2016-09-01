// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC. (https://elementary.io)
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
 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace AppCenter.Widgets {
    public class AppActionButton : Gtk.Button {
        public AppActionButton (string? _label) {
            valign = Gtk.Align.CENTER;
            label = _label;
         }

        public void set_suggested_action_header () {
            var style_ctx = get_style_context ();
            style_ctx.add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            style_ctx.add_class ("h3");
        }

        public void set_destructive_action_header () {
            var style_ctx = get_style_context ();
            style_ctx.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            style_ctx.add_class ("h3");
        }
     }
}
