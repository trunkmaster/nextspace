/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2013 Window Maker Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef WMSTARTUP_H
#define WMSTARTUP_H

void StartUp(Bool defaultScreenOnly);

void wHackedGrabButton(unsigned int button, unsigned int modifiers,
		       Window grab_window, Bool owner_events,
		       unsigned int event_mask, int pointer_mode,
		       int keyboard_mode, Window confine_to, Cursor cursor);

#ifdef NUMLOCK_HACK
void wHackedGrabKey(int keycode, unsigned int modifiers,
		    Window grab_window, Bool owner_events, int pointer_mode,
		    int keyboard_mode);
#endif

#endif /* WMSTARTUP_H */
