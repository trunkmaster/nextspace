/* appicon.h- application icon
 *
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


#ifndef WMAPPICON_H_
#define WMAPPICON_H_

#include <wraster.h>

#include "wcore.h"
#include "window.h"
#include "icon.h"
#include "application.h"


typedef struct WAppIcon {
    short xindex;
    short yindex;
    struct WAppIcon *next;
    struct WAppIcon *prev;
    WIcon *icon;

    char *client_machine;

    int x_pos, y_pos;		       /* absolute screen coordinate */

    char *command;		       /* command used to launch app */

#ifdef XDND
    char *dnd_command;		       /* command to use when something is */
                                       /* dropped on us */
#endif

    char *paste_command;	       /* command to run when something is pasted */

    char *wm_class;
    char *wm_instance;
    pid_t pid;			       /* for apps launched from the dock */
    Window main_window;

    struct WDock *dock;		       /* In which dock is docked. */

    struct _AppSettingsPanel *panel;   /* Settings Panel */

    unsigned int gnustep_app:1;	       /* if this is a GNUstep application */
    unsigned int docked:1;
    unsigned int omnipresent:1;        /* If omnipresent when docked in clip */
    unsigned int attracted:1;	       /* If it was attracted by the clip */
    unsigned int launching:1;
    unsigned int running:1;	       /* application is already running */
    unsigned int relaunching:1;	       /* launching 2nd instance */

    unsigned int forced_dock:1;
    unsigned int auto_launch:1;	       /* launch app on startup */
    unsigned int remote_start:1;
    unsigned int updated:1;
    unsigned int editing:1;	       /* editing docked icon */
    unsigned int drop_launch:1;	       /* launching from drop action */
    unsigned int paste_launch:1;       /* launching from paste action */
    unsigned int destroyed:1;	       /* appicon was destroyed */
    unsigned int buggy_app:1;	       /* do not make dock rely on hints
                                        * set by app */

    unsigned int lock:1;	       /* do not allow to be destroyed */

} WAppIcon;


WAppIcon *wAppIconCreate(WWindow *leader_win);
WAppIcon *wAppIconCreateForDock(WScreen *scr, char *command, char *wm_instance,
                                char *wm_class, int tile);

void wAppIconDestroy(WAppIcon *aicon);

void wAppIconPaint(WAppIcon *aicon);

Bool wAppIconChangeImage(WAppIcon *icon, char *file);

void wAppIconMove(WAppIcon *aicon, int x, int y);

#endif

