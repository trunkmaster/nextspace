/* WUtil / userdefaults.h
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

#ifndef WUTIL_USERDEFAULTS_H
#define WUTIL_USERDEFAULTS_H

/*
 * This file is not part of WUtil public API
 *
 * It defines internal things for the user configuration handling functions
 */


/* Save user configuration, to be used when application exits only */
void w_save_defaults_changes(void);


#endif /* WUTIL_USERDEFAULTS_H */
