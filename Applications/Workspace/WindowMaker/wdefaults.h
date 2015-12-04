/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#ifndef WMWDEFAULTS_H_
#define WMWDEFAULTS_H_


/* bit flags for the above window attributes */
#define WA_TITLEBAR  		(1<<0)
#define WA_RESIZABLE  		(1<<1)
#define WA_CLOSABLE  		(1<<2)
#define WA_MINIATURIZABLE  	(1<<3)
#define WA_BROKEN_CLOSE  	(1<<4)
#define WA_SHADEABLE  		(1<<5)
#define WA_FOCUSABLE  		(1<<6)
#define WA_OMNIPRESENT 	 	(1<<7)
#define WA_SKIP_WINDOW_LIST  	(1<<8)
#define WA_FLOATING  		(1<<9)
#define WA_IGNORE_KEYS 		(1<<10)
#define WA_IGNORE_MOUSE  	(1<<11)
#define WA_IGNORE_HIDE_OTHERS	(1<<12)
#define WA_NOT_APPLICATION	(1<<13)
#define WA_DONT_MOVE_OFF	(1<<14)

#endif
