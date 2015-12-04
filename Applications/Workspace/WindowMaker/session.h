/*  session.h
 *
 *  Copyright (c) 1999-2003 Alfredo K. Kojima
 *
 *  Window Maker window manager
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

#ifndef WMSESSION_H_
#define WMSESSION_H_


typedef struct {
    int x;
    int y;
    unsigned int w;		       /* client size */
    unsigned int h;

    int workspace;
    unsigned shortcuts; /* mask like 1<<shortcut_number */

    WWindowAttributes mflags;
    WWindowAttributes flags;

    char miniaturized;
    char shaded;
    char maximized;

    char user_changed_width;
    char user_changed_height;
} WSessionData;


void wSessionSaveState(WScreen *scr);

void wSessionSaveClients(WScreen *scr);

void wSessionSendSaveYourself(WScreen *scr);

void wSessionClearState(WScreen *scr);

void wSessionRestoreState(WScreen *scr);

void wSessionRestoreLastWorkspace(WScreen *scr);

#ifdef XSMP_ENABLED
void wSessionConnectManager(char **argv, int argc);

void wSessionDisconnectManager(void);

void wSessionRequestShutdown(void);

Bool  wSessionIsManaged(void);

#endif

Bool wSessionGetStateFor(WWindow *wwin, WSessionData *state);

#endif
