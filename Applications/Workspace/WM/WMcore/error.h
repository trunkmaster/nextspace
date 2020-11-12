/* WUtil / error.h
 *
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

#ifndef WUTIL_ERROR_H
#define WUTIL_ERROR_H

/*
 * This file is not part of WUtil public API
 *
 * It defines internal things for the error message display functions
 */


#ifdef HAVE_SYSLOG_H
/* Function to cleanly close the syslog stuff, called by wutil_shutdown from user side */
void w_syslog_close(void);
#endif


#endif /* WUTIL_ERROR_H */
