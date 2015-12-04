/*
 * Command-line utilities for WindowMaker
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
 * Copyright (c) 2004 Dan Pascu
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

/*
 * Functions that are used by more than one tool
 */

#ifndef UTIL_COMMON_H
#define UTIL_COMMON_H

/* ---[ util/fontconv.c ]------------------------------------------------- */
char *convertFont(char *font, Bool keepXLFD);

#endif
