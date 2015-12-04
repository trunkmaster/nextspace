/* WUtil / misc.c
 *
 *  Copyright (c) 2001 Dan Pascu
 *  Copyright (c) 2014 Window Maker Team
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

/* Miscelaneous helper functions */

#include <WUtil.h>

#include "error.h"

WMRange wmkrange(int start, int count)
{
	WMRange range;

	range.position = start;
	range.count = count;

	return range;
}

/*
 * wutil_shutdown - cleanup in WUtil when user program wants to exit
 */
void wutil_shutdown(void)
{
#ifdef HAVE_SYSLOG
	w_syslog_close();
#endif
}
