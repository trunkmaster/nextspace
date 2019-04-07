/* shutdown.c - Shutdown functions
 *
 *  Window Maker window manager
 *
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef SHUTDOWN_H
#define SHUTDOWN_H

/* shutdown modes */
typedef enum {
    WSExitMode,
    WSLogoutMode,
    WSKillMode,
    WSRestartPreparationMode
} WShutdownMode;

void Shutdown(WShutdownMode mode);
void RestoreDesktop(WScreen *scr);

#endif  /* SHUTDOWN_H */
