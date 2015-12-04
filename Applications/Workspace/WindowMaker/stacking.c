/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "WindowMaker.h"
#include "screen.h"
#include "window.h"
#include "funcs.h"
#include "actions.h"
#include "properties.h"
#include "stacking.h"
#include "workspace.h"


/*** Global Variables ***/
extern XContext wStackContext;

extern WPreferences wPreferences;


static void
notifyStackChange(WCoreWindow *frame, char *detail)
{
    WWindow *wwin = wWindowFor(frame->window);

    WMPostNotificationName(WMNChangedStacking, wwin, detail);
}


/*
 *----------------------------------------------------------------------
 * RemakeStackList--
 * 	Remakes the stacking_list for the screen, getting the real
 * stacking order from the server and reordering windows that are not
 * in the correct stacking.
 *
 * Side effects:
 * 	The stacking order list and the actual window stacking
 * may be changed (corrected)
 *
 *----------------------------------------------------------------------
 */
void
RemakeStackList(WScreen *scr)
{
    Window *windows;
    unsigned int nwindows;
    Window junkr, junkp;
    WCoreWindow *frame;
    WCoreWindow *tmp;
    int level;
    int i, c;

    if (!XQueryTree(dpy, scr->root_win, &junkr, &junkp, &windows, &nwindows)) {
        wwarning(_("could not get window list!!"));
        return;
    } else {
        WMEmptyBag(scr->stacking_list);

        /* verify list integrity */
        c=0;
        for (i=0; i<nwindows; i++) {
            if (XFindContext(dpy, windows[i], wStackContext, (XPointer*)&frame)
                ==XCNOENT) {
                continue;
            }
            if (!frame) continue;
            c++;
            level = frame->stacking->window_level;
            tmp = WMGetFromBag(scr->stacking_list, level);
            if (tmp)
                tmp->stacking->above = frame;
            frame->stacking->under = tmp;
            frame->stacking->above = NULL;
            WMSetInBag(scr->stacking_list, level, frame);
        }
        XFree(windows);
#ifdef DEBUG
        if (c!=scr->window_count) {
            puts("Found different number of windows than in window lists!!!");
        }
#endif
        scr->window_count = c;
    }

    CommitStacking(scr);
}



/*
 *----------------------------------------------------------------------
 * CommitStacking--
 * 	Reorders the actual window stacking, so that it has the stacking
 * order in the internal window stacking lists. It does the opposite
 * of RemakeStackList().
 *
 * Side effects:
 * 	Windows may be restacked.
 *----------------------------------------------------------------------
 */
void
CommitStacking(WScreen *scr)
{
    WCoreWindow *tmp;
    int nwindows, i;
    Window *windows;
    WMBagIterator iter;

    nwindows = scr->window_count;
    windows = wmalloc(sizeof(Window)*nwindows);

    i = 0;
    WM_ETARETI_BAG(scr->stacking_list, tmp, iter) {
        while (tmp) {
#ifdef DEBUG
            if (i>=nwindows) {
                puts("Internal inconsistency! window_count is incorrect!!!");
                printf("window_count says %i windows\n", nwindows);
                wfree(windows);
                return;
            }
#endif
            windows[i++] = tmp->window;
            tmp = tmp->stacking->under;
        }
    }
    XRestackWindows(dpy, windows, i);
    wfree(windows);

#ifdef VIRTUAL_DESKTOP
    wWorkspaceRaiseEdge(scr);
#endif

    WMPostNotificationName(WMNResetStacking, scr, NULL);
}

/*
 *----------------------------------------------------------------------
 * moveFrameToUnder--
 * 	Reestacks windows so that "frame" is under "under".
 *
 * Returns:
 *	None
 *
 * Side effects:
 * 	Changes the stacking order of frame.
 *----------------------------------------------------------------------
 */
static void
moveFrameToUnder(WCoreWindow *under, WCoreWindow *frame)
{
    Window wins[2];

    wins[0] = under->window;
    wins[1] = frame->window;
    XRestackWindows(dpy, wins, 2);
}

/*
 *----------------------------------------------------------------------
 * wRaiseFrame--
 * 	Raises a frame taking the window level into account.
 *
 * Returns:
 * 	None
 *
 * Side effects:
 * 	Window stacking order and stacking list are changed.
 *
 *----------------------------------------------------------------------
 */
void
wRaiseFrame(WCoreWindow *frame)
{
    WCoreWindow *wlist = frame;
    int level = frame->stacking->window_level;
    WScreen *scr = frame->screen_ptr;

    /* already on top */
    if (frame->stacking->above == NULL) {
        return;
    }

    /* insert it on top of other windows on the same level */
    if (frame->stacking->under)
        frame->stacking->under->stacking->above = frame->stacking->above;
    if (frame->stacking->above)
        frame->stacking->above->stacking->under = frame->stacking->under;

    frame->stacking->above = NULL;
    frame->stacking->under = WMGetFromBag(scr->stacking_list, level);
    if (frame->stacking->under) {
        frame->stacking->under->stacking->above = frame;
    }
    WMSetInBag(scr->stacking_list, level, frame);

    /* raise transients under us from bottom to top
     * so that the order is kept */
again:
    wlist = frame->stacking->under;
    while (wlist && wlist->stacking->under)
        wlist = wlist->stacking->under;
    while (wlist && wlist!=frame) {
        if (wlist->stacking->child_of == frame) {
            wRaiseFrame(wlist);
            goto again;
        }
        wlist = wlist->stacking->above;
    }

    /* try to optimize things a little */
    if (frame->stacking->above == NULL) {
        WMBagIterator iter;
        WCoreWindow *above = WMBagLast(scr->stacking_list, &iter);
        int i, last = above->stacking->window_level;

        /* find the 1st level above us which has windows in it */
        for (i = level+1, above = NULL; i <= last; i++) {
            above = WMGetFromBag(scr->stacking_list, i);
            if (above != NULL)
                break;
        }

        if (above != frame && above != NULL) {
            while (above->stacking->under)
                above = above->stacking->under;
            moveFrameToUnder(above, frame);
        } else {
            /* no window above us */
            above = NULL;
            XRaiseWindow(dpy, frame->window);
        }
    } else {
        moveFrameToUnder(frame->stacking->above, frame);
    }

    notifyStackChange(frame, "raise");

#ifdef VIRTUAL_DESKTOP
    wWorkspaceRaiseEdge(scr);
#endif
}


void
wRaiseLowerFrame(WCoreWindow *frame)
{
    if (!frame->stacking->above
        ||(frame->stacking->window_level
           !=frame->stacking->above->stacking->window_level)) {

        wLowerFrame(frame);
    } else {
        WCoreWindow *scan = frame->stacking->above;
        WWindow *frame_wwin = (WWindow*) frame->descriptor.parent;

        while (scan) {

            if (scan->descriptor.parent_type == WCLASS_WINDOW) {
                WWindow *scan_wwin = (WWindow*)scan->descriptor.parent;

                if (wWindowObscuresWindow(scan_wwin, frame_wwin)
                    && scan_wwin->flags.mapped) {
                    break;
                }
            }
            scan = scan->stacking->above;
        }

        if (scan) {
            wRaiseFrame(frame);
        } else {
            wLowerFrame(frame);
        }
    }
}


void
wLowerFrame(WCoreWindow *frame)
{
    WScreen *scr = frame->screen_ptr;
    WCoreWindow *wlist=frame;
    int level = frame->stacking->window_level;

    /* already in bottom */
    if (wlist->stacking->under == NULL) {
        return;
    }
    /* cant lower transient below below its owner */
    if (wlist->stacking->under == wlist->stacking->child_of) {
        return;
    }
    /* remove from the list */
    if (WMGetFromBag(scr->stacking_list, level) == frame) {
        /* it was the top window */
        WMSetInBag(scr->stacking_list, level, frame->stacking->under);
        frame->stacking->under->stacking->above = NULL;
    } else {
        if (frame->stacking->under)
            frame->stacking->under->stacking->above = frame->stacking->above;
        if (frame->stacking->above)
            frame->stacking->above->stacking->under = frame->stacking->under;
    }
    wlist = WMGetFromBag(scr->stacking_list, level);

    /* look for place to put this window */
    if (wlist) {
        WCoreWindow *owner = frame->stacking->child_of;

        if (owner != wlist) {
            while (wlist->stacking->under) {
                /* if this is a transient, it should not be placed under
                 * it's owner */
                if (owner == wlist->stacking->under)
                    break;
                wlist = wlist->stacking->under;
            }
        }
    }
    /* insert under the place found */
    frame->stacking->above = wlist;
    if (wlist) {
        frame->stacking->under = wlist->stacking->under;
        if (wlist->stacking->under)
            wlist->stacking->under->stacking->above = frame;
        wlist->stacking->under = frame;
    } else {
        frame->stacking->under = NULL;
    }

    if (frame->stacking->above == NULL) {
        WMBagIterator iter;
        WCoreWindow *above = WMBagLast(scr->stacking_list, &iter);
        int i, last = above->stacking->window_level;

        /* find the 1st level above us which has windows in it */
        for (i = level+1, above = NULL; i <= last; i++) {
            above = WMGetFromBag(scr->stacking_list, i);
            if (above != NULL)
                break;
        }

        if (above != frame && above != NULL) {
            while (above->stacking->under)
                above = above->stacking->under;
            moveFrameToUnder(above, frame);
        } else {
            /* no window below us */
            XLowerWindow(dpy, frame->window);
        }
    } else {
        moveFrameToUnder(frame->stacking->above, frame);
    }

    notifyStackChange(frame, "lower");

#ifdef VIRTUAL_DESKTOP
    wWorkspaceRaiseEdge(scr);
#endif
}


/*
 *----------------------------------------------------------------------
 * AddToStackList--
 * 	Inserts the frame in the top of the stacking list. The
 * stacking precedence is obeyed.
 *
 * Returns:
 * 	None
 *
 * Side effects:
 * 	The frame is added to it's screen's window list.
 *----------------------------------------------------------------------
 */
void
AddToStackList(WCoreWindow *frame)
{
    WCoreWindow *curtop, *wlist;
    int index = frame->stacking->window_level;
    WScreen *scr = frame->screen_ptr;
    WCoreWindow *trans = NULL;

    frame->screen_ptr->window_count++;
    XSaveContext(dpy, frame->window, wStackContext, (XPointer)frame);
    curtop = WMGetFromBag(scr->stacking_list, index);

    /* first window in this level */
    if (curtop == NULL) {
        WMSetInBag(scr->stacking_list, index, frame);
        frame->stacking->above = NULL;
        frame->stacking->under = NULL;
        CommitStacking(scr);
        return;
    }

    /* check if this is a transient owner */
    wlist = curtop;
    while (wlist) {
        if (wlist->stacking->child_of == frame)
            trans = wlist;
        wlist = wlist->stacking->under;
    }
    /* trans will hold the transient in the lowest position
     * in stacking list */

    frame->stacking->above = trans;
    if (trans != NULL) {
        /* window is owner of a transient.. put it below
         * the lowest transient */
        frame->stacking->under = trans->stacking->under;
        if (trans->stacking->under) {
            trans->stacking->under->stacking->above = frame;
        }
        trans->stacking->under = frame;
    } else {
        /* window is not owner of transients.. just put it in the
         * top of other windows */
        frame->stacking->under = curtop;
        curtop->stacking->above = frame;
        WMSetInBag(scr->stacking_list, index, frame);
    }
    CommitStacking(scr);
}


/*
 *----------------------------------------------------------------------
 * MoveInStackListAbove--
 * 	Moves the frame above "next".
 *
 * Returns:
 * 	None
 *
 * Side effects:
 * 	Stacking order may be changed.
 *      Window level for frame may be changed.
 *----------------------------------------------------------------------
 */
void
MoveInStackListAbove(WCoreWindow *next, WCoreWindow *frame)
{
    WCoreWindow *tmpw;
    WScreen *scr = frame->screen_ptr;
    int index;

    if (!next || frame->stacking->under == next)
        return;

    if (frame->stacking->window_level != next->stacking->window_level)
        ChangeStackingLevel(frame, next->stacking->window_level);

    index = frame->stacking->window_level;

    tmpw = WMGetFromBag(scr->stacking_list, index);
    if (tmpw == frame)
        WMSetInBag(scr->stacking_list, index, frame->stacking->under);
    if (frame->stacking->under)
        frame->stacking->under->stacking->above = frame->stacking->above;
    if (frame->stacking->above)
        frame->stacking->above->stacking->under = frame->stacking->under;
    if (next->stacking->above)
        next->stacking->above->stacking->under = frame;
    frame->stacking->under = next;
    frame->stacking->above = next->stacking->above;
    next->stacking->above = frame;
    if (tmpw == next)
        WMSetInBag(scr->stacking_list, index, frame);

    /* try to optimize things a little */
    if (frame->stacking->above == NULL) {
        WCoreWindow *above = NULL;
        WMBagIterator iter;

        for (above = WMBagIteratorAtIndex(scr->stacking_list, index+1, &iter);
             above != NULL;
             above = WMBagNext(scr->stacking_list, &iter)) {

            /* can't optimize */
            while (above->stacking->under)
                above = above->stacking->under;
            break;
        }
        if (above == NULL) {
            XRaiseWindow(dpy, frame->window);
        } else {
            moveFrameToUnder(above, frame);
        }
    } else {
        moveFrameToUnder(frame->stacking->above, frame);
    }

    WMPostNotificationName(WMNResetStacking, scr, NULL);

#ifdef VIRTUAL_DESKTOP
    wWorkspaceRaiseEdge(scr);
#endif
}


/*
 *----------------------------------------------------------------------
 * MoveInStackListUnder--
 * 	Moves the frame to under "prev".
 *
 * Returns:
 * 	None
 *
 * Side effects:
 * 	Stacking order may be changed.
 *      Window level for frame may be changed.
 *----------------------------------------------------------------------
 */
void
MoveInStackListUnder(WCoreWindow *prev, WCoreWindow *frame)
{
    WCoreWindow *tmpw;
    int index;
    WScreen *scr = frame->screen_ptr;

    if (!prev || frame->stacking->above == prev)
        return;

    if (frame->stacking->window_level != prev->stacking->window_level)
        ChangeStackingLevel(frame, prev->stacking->window_level);

    index = frame->stacking->window_level;

    tmpw = WMGetFromBag(scr->stacking_list, index);
    if (tmpw == frame)
        WMSetInBag(scr->stacking_list, index, frame->stacking->under);
    if (frame->stacking->under)
        frame->stacking->under->stacking->above = frame->stacking->above;
    if (frame->stacking->above)
        frame->stacking->above->stacking->under = frame->stacking->under;
    if (prev->stacking->under)
        prev->stacking->under->stacking->above = frame;
    frame->stacking->above = prev;
    frame->stacking->under = prev->stacking->under;
    prev->stacking->under = frame;
    moveFrameToUnder(prev, frame);

    WMPostNotificationName(WMNResetStacking, scr, NULL);
}


void
RemoveFromStackList(WCoreWindow *frame)
{
    int index = frame->stacking->window_level;

    if (XDeleteContext(dpy, frame->window, wStackContext)==XCNOENT) {
        wwarning("RemoveFromStackingList(): window not in list ");
        return;
    }
    /* remove from the window stack list */
    if (frame->stacking->under)
        frame->stacking->under->stacking->above = frame->stacking->above;
    if (frame->stacking->above)
        frame->stacking->above->stacking->under = frame->stacking->under;
    else /* this was the first window on the list */
        WMSetInBag(frame->screen_ptr->stacking_list, index,
                   frame->stacking->under);

    frame->screen_ptr->window_count--;

    WMPostNotificationName(WMNResetStacking, frame->screen_ptr, NULL);
}


void
ChangeStackingLevel(WCoreWindow *frame, int new_level)
{
    int old_level;

    if (frame->stacking->window_level == new_level)
        return;
    old_level = frame->stacking->window_level;

    RemoveFromStackList(frame);
    frame->stacking->window_level = new_level;
    AddToStackList(frame);
    if (old_level > new_level) {
        wRaiseFrame(frame);
    } else {
        wLowerFrame(frame);
    }
}

