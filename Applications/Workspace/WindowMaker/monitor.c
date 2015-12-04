/* monitor.c - monitors the wmaker process
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2004 Alfredo K. Kojima
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

#include "wconfig.h"
#include <unistd.h>
#include <stdlib.h>
#include <time.h>
#include <signal.h>
#include <sys/wait.h>
#ifdef __FreeBSD__
#include <sys/signal.h>
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xproto.h>

#include "WindowMaker.h"
#include "screen.h"
#include "window.h"
#include "dialog.h"
#include "funcs.h"

/****** Global Variables ******/

extern WPreferences wPreferences;

extern int wScreenCount;




int showCrashDialog(int sig)
{
    int crashAction;
    
    dpy = XOpenDisplay(NULL);
    if (dpy) {
/* XXX TODO make sure that window states are saved and restored via netwm */

        XGrabServer(dpy);
        crashAction = wShowCrashingDialogPanel(sig);
        XCloseDisplay(dpy);
        dpy = NULL;
    } else {
        wsyserror(_("cannot open connection for crashing dialog panel. Aborting."));
        crashAction = WMAbort;
    }
    
    if (crashAction == WMStartAlternate)
    {
        int i;

    	wmessage(_("trying to start alternate window manager..."));

        for (i=0; i<WMGetArrayItemCount(wPreferences.fallbackWMs); i++) {
            Restart(WMGetFromArray(wPreferences.fallbackWMs, i), False);
        }

        wfatal(_("failed to start alternate window manager. Aborting."));

        return 0;
    } 
    else if (crashAction == WMAbort)
      return 0;
    else
      return 1;
}


int MonitorLoop(int argc, char **argv)
{
    pid_t pid, exited;
    char **child_argv= wmalloc(sizeof(char*)*(argc+2));
    int i, status;
    time_t last_start;
    Bool error = False;

    for (i= 0; i < argc; i++)
        child_argv[i]= argv[i];
    child_argv[i++]= "--for-real";
    child_argv[i]= NULL;

    for (;;)
    {
        last_start= time(NULL);

        /* Start Window Maker */
        pid = fork();
        if (pid == 0)
        {
            execvp(child_argv[0], child_argv);
            wsyserror(_("Error respawning Window Maker"));
            exit(1);
        }
        else if (pid < 0)
        {
            wsyserror(_("Error respawning Window Maker"));
            exit(1);
        }

        do {
            if ((exited=waitpid(-1, &status, 0)) < 0)
            {
                wsyserror(_("Error during monitoring of Window Maker process."));
                error = True;
                break;
            }
        } while (exited != pid);

        if (error)
            break;

        child_argv[argc]= "--for-real-";
        
        /* Check if the wmaker process exited due to a crash */
        if (WIFSIGNALED(status) && 
            (WTERMSIG(status) == SIGSEGV ||
             WTERMSIG(status) == SIGBUS ||
             WTERMSIG(status) == SIGILL ||
             WTERMSIG(status) == SIGABRT ||
             WTERMSIG(status) == SIGFPE))
        {
            /* If so, we check when was the last restart.
             * If it was less than 3s ago, it's a bad sign, so we show
             * the crash panel and ask the user what to do */
            if (time(NULL) - last_start < 3)
            {
                if (showCrashDialog(WTERMSIG(status)) == 0) {
                    return 1;
                }
            }
            wwarning(_("Window Maker exited due to a crash (signal %i) and will be restarted."),
                     WTERMSIG(status));
        }
        else
          break;
    }
    return 0;
}

