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
#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdarg.h>
#include <pwd.h>
#include <math.h>
#include <time.h>

#include <WINGs/WUtil.h>
#include <wraster.h>


#include "WindowMaker.h"
#include "GNUstep.h"
#include "screen.h"
#include "wcore.h"
#include "window.h"
#include "framewin.h"
#include "funcs.h"
#include "defaults.h"
#include "dialog.h"
#include "xutil.h"
#include "xmodifier.h"


/**** global variables *****/

extern WPreferences wPreferences;

extern Time LastTimestamp;


#ifdef USECPP
static void
putdef(char *line, char *name, char *value)
{
    if (!value) {
        wwarning(_("could not define value for %s for cpp"), name);
        return;
    }
    strcat(line, name);
    strcat(line, value);
}



static void
putidef(char *line, char *name, int value)
{
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "%i", value);
    strcat(line, name);
    strcat(line, tmp);
}


static char*
username()
{
    char *tmp;

    tmp = getlogin();
    if (!tmp) {
        struct passwd *user;

        user = getpwuid(getuid());
        if (!user) {
            wsyserror(_("could not get password entry for UID %i"), getuid());
            return NULL;
        }
        if (!user->pw_name) {
            return NULL;
        } else {
            return user->pw_name;
        }
    }
    return tmp;
}

char *
MakeCPPArgs(char *path)
{
    int i;
    char buffer[MAXLINE], *buf, *line;
    Visual *visual;
    char *tmp;

    line = wmalloc(MAXLINE);
    *line = 0;
    i=1;
    if ((buf=getenv("HOSTNAME"))!=NULL) {
        if (buf[0]=='(') {
            wwarning(_("your machine is misconfigured. HOSTNAME is set to %s"),
                     buf);
        } else
            putdef(line, " -DHOST=", buf);
    } else if ((buf=getenv("HOST"))!=NULL) {
        if (buf[0]=='(') {
            wwarning(_("your machine is misconfigured. HOST is set to %s"),
                     buf);
        } else
            putdef(line, " -DHOST=", buf);
    }
    buf = username();
    if (buf)
        putdef(line, " -DUSER=", buf);
    putidef(line, " -DUID=", getuid());
    buf = XDisplayName(DisplayString(dpy));
    putdef(line, " -DDISPLAY=", buf);
    putdef(line, " -DWM_VERSION=", VERSION);

    visual = DefaultVisual(dpy, DefaultScreen(dpy));
    putidef(line, " -DVISUAL=", visual->class);

    putidef(line, " -DDEPTH=", DefaultDepth(dpy, DefaultScreen(dpy)));

    putidef(line, " -DSCR_WIDTH=", WidthOfScreen(DefaultScreenOfDisplay(dpy)));
    putidef(line, " -DSCR_HEIGHT=",
            HeightOfScreen(DefaultScreenOfDisplay(dpy)));

    /* put the dir where the menu is being read from to the
     * search path */
    if (path) {
        tmp = wstrdup(path);
        buf = strchr(tmp+1, ' ');
        if (buf) {
            *buf = 0;
        }
        buf = strrchr(tmp, '/');
        if (buf) {
            *buf = 0; /* trunc filename */
            putdef(line, " -I", tmp);
        }
        wfree(tmp);
    }


    /* this should be done just once, but it works this way */
    strcpy(buffer, DEF_CONFIG_PATHS);
    buf = strtok(buffer, ":");

    do {
        char fullpath[MAXLINE];

        if (buf[0]!='~') {
            strcpy(fullpath, buf);
        } else {
            char * wgethomedir();
            /* home is statically allocated. Don't free it! */
            char *home = wgethomedir();

            strcpy(fullpath, home);
            strcat(fullpath, &(buf[1]));
        }

        putdef(line, " -I", fullpath);

    } while ((buf = strtok(NULL, ":"))!=NULL);

#undef arg
#ifdef DEBUG
    puts("CPP ARGS");
    puts(line);
#endif
    return line;
}
#endif /* USECPP */




#if 0
/*
 * Is win2 below win1?
 */
static Bool
isBelow(WWindow *win1, WWindow *win2)
{
    int i;
    WCoreWindow *tmp;

    tmp = win1->frame->core->stacking->under;
    while (tmp) {
        if (tmp == win2->frame->core)
            return True;
        tmp = tmp->stacking->under;
    }

    for (i=win1->frame->core->stacking->window_level-1; i>=0; i--) {
        tmp = win1->screen_ptr->stacking_list[i];
        while (tmp) {
            if (tmp == win2->frame->core)
                return True;
            tmp = tmp->stacking->under;
        }
    }
    return True;
}
#endif



/*
 *  XFetchName Wrapper
 *
 */
Bool
wFetchName(dpy, win, winname)
Display *dpy;
Window win;
char **winname;
{
    XTextProperty text_prop;
    char **list;
    int num;

    if (XGetWMName(dpy, win, &text_prop)) {
        if (text_prop.value && text_prop.nitems > 0) {
            if (text_prop.encoding == XA_STRING) {
                *winname = wstrdup((char *)text_prop.value);
                XFree(text_prop.value);
            } else {
                text_prop.nitems = strlen((char *)text_prop.value);
                if (XmbTextPropertyToTextList(dpy, &text_prop, &list, &num) >=
                    Success && num > 0 && *list) {
                    XFree(text_prop.value);
                    *winname = wstrdup(*list);
                    XFreeStringList(list);
                } else {
                    *winname = wstrdup((char *)text_prop.value);
                    XFree(text_prop.value);
                }
            }
        } else {
            /* the title is set, but it was set to none */
            *winname = wstrdup("");
        }
        return True;
    } else {
        /* the hint is probably not set */
        *winname = NULL;

        return False;
    }
}

/*
 *  XGetIconName Wrapper
 *
 */

Bool
wGetIconName(dpy, win, iconname)
Display *dpy;
Window win;
char **iconname;
{
    XTextProperty text_prop;
    char **list;
    int num;

    if (XGetWMIconName(dpy, win, &text_prop) != 0 && text_prop.value
        && text_prop.nitems > 0) {
        if (text_prop.encoding == XA_STRING)
            *iconname = (char *)text_prop.value;
        else {
            text_prop.nitems = strlen((char *)text_prop.value);
            if (XmbTextPropertyToTextList(dpy, &text_prop, &list, &num) >=
                Success && num > 0 && *list) {
                XFree(text_prop.value);
                *iconname = wstrdup(*list);
                XFreeStringList(list);
            } else
                *iconname = (char *)text_prop.value;
        }
        return True;
    }
    *iconname = NULL;
    return False;
}


static void
eatExpose()
{
    XEvent event, foo;

    /* compress all expose events into a single one */

    if (XCheckMaskEvent(dpy, ExposureMask, &event)) {
        /* ignore other exposure events for this window */
        while (XCheckWindowEvent(dpy, event.xexpose.window, ExposureMask,
                                 &foo));
        /* eat exposes for other windows */
        eatExpose();

        event.xexpose.count = 0;
        XPutBackEvent(dpy, &event);
    }
}


void
SlideWindow(Window win, int from_x, int from_y, int to_x, int to_y)
{
    time_t time0 = time(NULL);
    float dx, dy, x=from_x, y=from_y, sx, sy, px, py;
    int dx_is_bigger=0;

    /* animation parameters */
    static struct {
        int delay;
        int steps;
        int slowdown;
    } apars[5] = {
        {ICON_SLIDE_DELAY_UF, ICON_SLIDE_STEPS_UF, ICON_SLIDE_SLOWDOWN_UF},
        {ICON_SLIDE_DELAY_F, ICON_SLIDE_STEPS_F, ICON_SLIDE_SLOWDOWN_F},
        {ICON_SLIDE_DELAY_M, ICON_SLIDE_STEPS_M, ICON_SLIDE_SLOWDOWN_M},
        {ICON_SLIDE_DELAY_S, ICON_SLIDE_STEPS_S, ICON_SLIDE_SLOWDOWN_S},
        {ICON_SLIDE_DELAY_US, ICON_SLIDE_STEPS_US, ICON_SLIDE_SLOWDOWN_US}};



    dx = (float)(to_x-from_x);
    dy = (float)(to_y-from_y);
    sx = (dx == 0 ? 0 : fabs(dx)/dx);
    sy = (dy == 0 ? 0 : fabs(dy)/dy);

    if (fabs(dx) > fabs(dy)) {
        dx_is_bigger = 1;
    }

    if (dx_is_bigger) {
        px = dx / apars[(int)wPreferences.icon_slide_speed].slowdown;
        if (px < apars[(int)wPreferences.icon_slide_speed].steps && px > 0)
            px = apars[(int)wPreferences.icon_slide_speed].steps;
        else if (px > -apars[(int)wPreferences.icon_slide_speed].steps && px < 0)
            px = -apars[(int)wPreferences.icon_slide_speed].steps;
        py = (sx == 0 ? 0 : px*dy/dx);
    } else {
        py = dy / apars[(int)wPreferences.icon_slide_speed].slowdown;
        if (py < apars[(int)wPreferences.icon_slide_speed].steps && py > 0)
            py = apars[(int)wPreferences.icon_slide_speed].steps;
        else if (py > -apars[(int)wPreferences.icon_slide_speed].steps && py < 0)
            py = -apars[(int)wPreferences.icon_slide_speed].steps;
        px = (sy == 0 ? 0 : py*dx/dy);
    }

    while (x != to_x || y != to_y) {
        x += px;
        y += py;
        if ((px<0 && (int)x < to_x) || (px>0 && (int)x > to_x))
            x = (float)to_x;
        if ((py<0 && (int)y < to_y) || (py>0 && (int)y > to_y))
            y = (float)to_y;

        if (dx_is_bigger) {
            px = px * (1.0 - 1/(float)apars[(int)wPreferences.icon_slide_speed].slowdown);
            if (px < apars[(int)wPreferences.icon_slide_speed].steps && px > 0)
                px = apars[(int)wPreferences.icon_slide_speed].steps;
            else if (px > -apars[(int)wPreferences.icon_slide_speed].steps && px < 0)
                px = -apars[(int)wPreferences.icon_slide_speed].steps;
            py = (sx == 0 ? 0 : px*dy/dx);
        } else {
            py = py * (1.0 - 1/(float)apars[(int)wPreferences.icon_slide_speed].slowdown);
            if (py < apars[(int)wPreferences.icon_slide_speed].steps && py > 0)
                py = apars[(int)wPreferences.icon_slide_speed].steps;
            else if (py > -apars[(int)wPreferences.icon_slide_speed].steps && py < 0)
                py = -apars[(int)wPreferences.icon_slide_speed].steps;
            px = (sy == 0 ? 0 : py*dx/dy);
        }

        XMoveWindow(dpy, win, (int)x, (int)y);
        XFlush(dpy);
        if (apars[(int)wPreferences.icon_slide_speed].delay > 0) {
            wusleep(apars[(int)wPreferences.icon_slide_speed].delay*1000L);
        } else {
            wusleep(10);
        }
        if (time(NULL) - time0 > MAX_ANIMATION_TIME)
            break;
    }
    XMoveWindow(dpy, win, to_x, to_y);

    XSync(dpy, 0);
    /* compress expose events */
    eatExpose();
}


char*
ShrinkString(WMFont *font, char *string, int width)
{
    int w, w1=0;
    int p;
    char *pos;
    char *text;
    int p1, p2, t;

    p = strlen(string);
    w = WMWidthOfString(font, string, p);
    text = wmalloc(strlen(string)+8);
    strcpy(text, string);
    if (w<=width)
        return text;

    pos = strchr(text, ' ');
    if (!pos)
        pos = strchr(text, ':');

    if (pos) {
        *pos = 0;
        p = strlen(text);
        w1 = WMWidthOfString(font, text, p);
        if (w1 > width) {
            w1 = 0;
            p = 0;
            *pos = ' ';
            *text = 0;
        } else {
            *pos = 0;
            width -= w1;
            p++;
        }
        string += p;
        p=strlen(string);
    } else {
        *text=0;
    }
    strcat(text, "...");
    width -= WMWidthOfString(font, "...", 3);
    pos = string;
    p1=0;
    p2=p;
    t = (p2-p1)/2;
    while (p2>p1 && p1!=t) {
        w = WMWidthOfString(font, &string[p-t], t);
        if (w>width) {
            p2 = t;
            t = p1+(p2-p1)/2;
        } else if (w<width) {
            p1 = t;
            t = p1+(p2-p1)/2;
        } else
            p2=p1=t;
    }
    strcat(text, &string[p-p1]);

    return text;
}


char*
FindImage(char *paths, char *file)
{
    char *tmp, *path;

    tmp = strrchr(file, ':');
    if (tmp) {
        *tmp = 0;
        path = wfindfile(paths, file);
        *tmp = ':';
    }
    if (!tmp || !path) {
        path = wfindfile(paths, file);
    }

    return path;
}


static void
timeoutHandler(void *data)
{
    *(int*)data = 1;
}


static char*
getTextSelection(WScreen *screen, Atom selection)
{
    int buffer = -1;

    switch (selection) {
    case XA_CUT_BUFFER0:
        buffer = 0;
        break;
    case XA_CUT_BUFFER1:
        buffer = 1;
        break;
    case XA_CUT_BUFFER2:
        buffer = 2;
        break;
    case XA_CUT_BUFFER3:
        buffer = 3;
        break;
    case XA_CUT_BUFFER4:
        buffer = 4;
        break;
    case XA_CUT_BUFFER5:
        buffer = 5;
        break;
    case XA_CUT_BUFFER6:
        buffer = 6;
        break;
    case XA_CUT_BUFFER7:
        buffer = 7;
        break;
    }
    if (buffer >= 0) {
        char *data;
        int size;

        data = XFetchBuffer(dpy, &size, buffer);

        return data;
    } else {
        char *data;
        int bits;
        Atom rtype;
        unsigned long len, bytes;
        WMHandlerID timer;
        int timeout = 0;
        XEvent ev;
        static Atom clipboard = 0;

        if (!clipboard)
            clipboard = XInternAtom(dpy, "CLIPBOARD", False);

        XDeleteProperty(dpy, screen->info_window, clipboard);

        XConvertSelection(dpy, selection, XA_STRING,
                          clipboard, screen->info_window,
                          CurrentTime);

        timer = WMAddTimerHandler(1000, timeoutHandler, &timeout);

        while (!XCheckTypedWindowEvent(dpy, screen->info_window,
                                       SelectionNotify, &ev) && !timeout);

        if (!timeout) {
            WMDeleteTimerHandler(timer);
        } else {
            wwarning("selection retrieval timed out");
            return NULL;
        }

        /* nobody owns the selection or the current owner has
         * nothing to do with what we need */
        if (ev.xselection.property == None) {
            return NULL;
        }

        if (XGetWindowProperty(dpy, screen->info_window,
                               clipboard, 0, 1024,
                               False, XA_STRING, &rtype, &bits, &len,
                               &bytes, (unsigned char**)&data)!=Success) {
            return NULL;
        }
        if (rtype!=XA_STRING || bits!=8) {
            wwarning("invalid data in text selection");
            if (data)
                XFree(data);
            return NULL;
        }
        return data;
    }
}

static char*
getselection(WScreen *scr)
{
    char *tmp;

    tmp = getTextSelection(scr, XA_PRIMARY);
    if (!tmp)
        tmp = getTextSelection(scr, XA_CUT_BUFFER0);
    return tmp;
}


static char*
getuserinput(WScreen *scr, char *line, int *ptr)
{
    char *ret;
    char *title;
    char *prompt;
    int j, state;
    int begin = 0;
#define BUFSIZE 512
    char tbuffer[BUFSIZE], pbuffer[BUFSIZE];


    title = _("Program Arguments");
    prompt = _("Enter command arguments:");
    ret = NULL;

#define _STARTING 0
#define _TITLE 1
#define _PROMPT 2
#define _DONE 3

    state = _STARTING;
    j = 0;
    for (; line[*ptr]!=0 && state!=_DONE; (*ptr)++) {
        switch (state) {
        case _STARTING:
            if (line[*ptr]=='(') {
                state = _TITLE;
                begin = *ptr+1;
            } else {
                state = _DONE;
            }
            break;

        case _TITLE:
            if (j <= 0 && line[*ptr]==',') {

                j = 0;
                if (*ptr > begin) {
                    strncpy(tbuffer, &line[begin], WMIN(*ptr-begin, BUFSIZE));
                    tbuffer[WMIN(*ptr-begin, BUFSIZE)] = 0;
                    title = (char*)tbuffer;
                }
                begin = *ptr+1;
                state = _PROMPT;

            } else if (j <= 0 && line[*ptr]==')') {

                if (*ptr > begin) {
                    strncpy(tbuffer, &line[begin], WMIN(*ptr-begin, BUFSIZE));
                    tbuffer[WMIN(*ptr-begin, BUFSIZE)] = 0;
                    title = (char*)tbuffer;
                }
                state = _DONE;

            } else if (line[*ptr]=='(') {
                j++;
            } else if (line[*ptr]==')') {
                j--;
            }

            break;

        case _PROMPT:
            if (line[*ptr]==')' && j==0) {

                if (*ptr-begin > 1) {
                    strncpy(pbuffer, &line[begin], WMIN(*ptr-begin, BUFSIZE));
                    pbuffer[WMIN(*ptr-begin, BUFSIZE)] = 0;
                    prompt = (char*)pbuffer;
                }
                state = _DONE;
            } else if (line[*ptr]=='(')
                j++;
            else if (line[*ptr]==')')
                j--;
            break;
        }
    }
    (*ptr)--;
#undef _STARTING
#undef _TITLE
#undef _PROMPT
#undef _DONE

    if (!wInputDialog(scr, title, prompt, &ret))
        return NULL;
    else
        return ret;
}


#define S_NORMAL 0
#define S_ESCAPE 1
#define S_OPTION 2

/*
 * state    	input   new-state	output
 * NORMAL	%	OPTION		<nil>
 * NORMAL	\	ESCAPE		<nil>
 * NORMAL	etc.	NORMAL		<input>
 * ESCAPE	any	NORMAL		<input>
 * OPTION	s	NORMAL		<selection buffer>
 * OPTION	w	NORMAL		<selected window id>
 * OPTION	a	NORMAL		<input text>
 * OPTION	d	NORMAL		<OffiX DND selection object>
 * OPTION	W	NORMAL		<current workspace>
 * OPTION	etc.	NORMAL		%<input>
 */
#define TMPBUFSIZE 64
char*
ExpandOptions(WScreen *scr, char *cmdline)
{
    int ptr, optr, state, len, olen;
    char *out, *nout;
    char *selection=NULL;
    char *user_input=NULL;
#ifdef XDND
    char *dropped_thing=NULL;
#endif
    char tmpbuf[TMPBUFSIZE];
    int slen;

    len = strlen(cmdline);
    olen = len+1;
    out = malloc(olen);
    if (!out) {
        wwarning(_("out of memory during expansion of \"%s\""));
        return NULL;
    }
    *out = 0;
    ptr = 0; 			       /* input line pointer */
    optr = 0;			       /* output line pointer */
    state = S_NORMAL;
    while (ptr < len) {
        switch (state) {
        case S_NORMAL:
            switch (cmdline[ptr]) {
            case '\\':
                state = S_ESCAPE;
                break;
            case '%':
                state = S_OPTION;
                break;
            default:
                state = S_NORMAL;
                out[optr++]=cmdline[ptr];
                break;
            }
            break;
        case S_ESCAPE:
            switch (cmdline[ptr]) {
            case 'n':
                out[optr++]=10;
                break;

            case 'r':
                out[optr++]=13;
                break;

            case 't':
                out[optr++]=9;
                break;

            default:
                out[optr++]=cmdline[ptr];
            }
            state = S_NORMAL;
            break;
        case S_OPTION:
            state = S_NORMAL;
            switch (cmdline[ptr]) {
            case 'w':
                if (scr->focused_window
                    && scr->focused_window->flags.focused) {
                    snprintf(tmpbuf, sizeof(tmpbuf), "0x%x",
                             (unsigned int)scr->focused_window->client_win);
                    slen = strlen(tmpbuf);
                    olen += slen;
                    nout = realloc(out,olen);
                    if (!nout) {
                        wwarning(_("out of memory during expansion of \"%w\""));
                        goto error;
                    }
                    out = nout;
                    strcat(out,tmpbuf);
                    optr+=slen;
                } else {
                    out[optr++]=' ';
                }
                break;

            case 'W':
                snprintf(tmpbuf, sizeof(tmpbuf), "0x%x",
                         (unsigned int)scr->current_workspace + 1);
                slen = strlen(tmpbuf);
                olen += slen;
                nout = realloc(out,olen);
                if (!nout) {
                    wwarning(_("out of memory during expansion of \"%W\""));
                    goto error;
                }
                out = nout;
                strcat(out,tmpbuf);
                optr+=slen;
                break;

            case 'a':
                ptr++;
                user_input = getuserinput(scr, cmdline, &ptr);
                if (user_input) {
                    slen = strlen(user_input);
                    olen += slen;
                    nout = realloc(out,olen);
                    if (!nout) {
                        wwarning(_("out of memory during expansion of \"%a\""));
                        goto error;
                    }
                    out = nout;
                    strcat(out,user_input);
                    optr+=slen;
                } else {
                    /* Not an error, but user has Canceled the dialog box.
                     * This will make the command to not be performed. */
                    goto error;
                }
                break;

#ifdef XDND
            case 'd':
                if(scr->xdestring) {
                    dropped_thing = wstrdup(scr->xdestring);
                }
                if (!dropped_thing) {
                    dropped_thing = get_dnd_selection(scr);
                }
                if (!dropped_thing) {
                    scr->flags.dnd_data_convertion_status = 1;
                    goto error;
                }
                slen = strlen(dropped_thing);
                olen += slen;
                nout = realloc(out,olen);
                if (!nout) {
                    wwarning(_("out of memory during expansion of \"%d\""));
                    goto error;
                }
                out = nout;
                strcat(out,dropped_thing);
                optr+=slen;
                break;
#endif /* XDND */

            case 's':
                if (!selection) {
                    selection = getselection(scr);
                }
                if (!selection) {
                    wwarning(_("selection not available"));
                    goto error;
                }
                slen = strlen(selection);
                olen += slen;
                nout = realloc(out,olen);
                if (!nout) {
                    wwarning(_("out of memory during expansion of \"%s\""));
                    goto error;
                }
                out = nout;
                strcat(out,selection);
                optr+=slen;
                break;

            default:
                out[optr++]='%';
                out[optr++]=cmdline[ptr];
            }
            break;
        }
        out[optr]=0;
        ptr++;
    }
    if (selection)
        XFree(selection);
    return out;

error:
    wfree(out);
    if (selection)
        XFree(selection);
    return NULL;
}


void
ParseWindowName(WMPropList *value, char **winstance, char **wclass, char *where)
{
    char *name;

    *winstance = *wclass = NULL;

    if (!WMIsPLString(value)) {
        wwarning(_("bad window name value in %s state info"), where);
        return;
    }

    name = WMGetFromPLString(value);
    if (!name || strlen(name)==0) {
        wwarning(_("bad window name value in %s state info"), where);
        return;
    }

    UnescapeWM_CLASS(name, winstance, wclass);
}


#if 0
static char*
keysymToString(KeySym keysym, unsigned int state)
{
    XKeyEvent kev;
    char *buf = wmalloc(20);
    int count;

    kev.display = dpy;
    kev.type = KeyPress;
    kev.send_event = False;
    kev.window = DefaultRootWindow(dpy);
    kev.root = DefaultRootWindow(dpy);
    kev.same_screen = True;
    kev.subwindow = kev.root;
    kev.serial = 0x12344321;
    kev.time = CurrentTime;
    kev.state = state;
    kev.keycode = XKeysymToKeycode(dpy, keysym);
    count = XLookupString(&kev, buf, 19, NULL, NULL);
    buf[count] = 0;

    return buf;
}
#endif


char*
GetShortcutString(char *text)
{
    char *buffer = NULL;
    char *k;
    int modmask = 0;
    /*    KeySym ksym;*/
    int control = 0;
    char *tmp;

    tmp = text = wstrdup(text);

    /* get modifiers */
    while ((k = strchr(text, '+'))!=NULL) {
        int mod;

        *k = 0;
        mod = wXModifierFromKey(text);
        if (mod<0) {
            return wstrdup("bug");
        }

        modmask |= mod;

        if (strcasecmp(text, "Meta")==0) {
            buffer = wstrappend(buffer, "M+");
        } else if (strcasecmp(text, "Alt")==0) {
            buffer = wstrappend(buffer, "A+");
        } else if (strcasecmp(text, "Shift")==0) {
            buffer = wstrappend(buffer, "Sh+");
        } else if (strcasecmp(text, "Mod1")==0) {
            buffer = wstrappend(buffer, "M1+");
        } else if (strcasecmp(text, "Mod2")==0) {
            buffer = wstrappend(buffer, "M2+");
        } else if (strcasecmp(text, "Mod3")==0) {
            buffer = wstrappend(buffer, "M3+");
        } else if (strcasecmp(text, "Mod4")==0) {
            buffer = wstrappend(buffer, "M4+");
        } else if (strcasecmp(text, "Mod5")==0) {
            buffer = wstrappend(buffer, "M5+");
        } else if (strcasecmp(text, "Control")==0) {
            control = 1;
        } else {
            buffer = wstrappend(buffer, text);
        }
        text = k+1;
    }

    if (control) {
        buffer = wstrappend(buffer, "^");
    }
    buffer = wstrappend(buffer, text);

    /* get key */
    /*    ksym = XStringToKeysym(text);
     tmp = keysymToString(ksym, modmask);
     puts(tmp);
     buffer = wstrappend(buffer, tmp);
     */
    wfree(tmp);

    return buffer;
}


char*
EscapeWM_CLASS(char *name, char *class)
{
    char *ret;
    char *ename = NULL, *eclass = NULL;
    int i, j, l;

    if (!name && !class)
        return NULL;

    if (name) {
        l = strlen(name);
        ename = wmalloc(l*2+1);
        j = 0;
        for (i=0; i<l; i++) {
            if (name[i]=='\\') {
                ename[j++] = '\\';
            } else if (name[i]=='.') {
                ename[j++] = '\\';
            }
            ename[j++] = name[i];
        }
        ename[j] = 0;
    }
    if (class) {
        l = strlen(class);
        eclass = wmalloc(l*2+1);
        j = 0;
        for (i=0; i<l; i++) {
            if (class[i]=='\\') {
                eclass[j++] = '\\';
            } else if (class[i]=='.') {
                eclass[j++] = '\\';
            }
            eclass[j++] = class[i];
        }
        eclass[j] = 0;
    }

    if (ename && eclass) {
        int len = strlen(ename)+strlen(eclass)+4;
        ret = wmalloc(len);
        snprintf(ret, len, "%s.%s", ename, eclass);
        wfree(ename);
        wfree(eclass);
    } else if (ename) {
        ret = wstrdup(ename);
        wfree(ename);
    } else {
        ret = wstrdup(eclass);
        wfree(eclass);
    }

    return ret;
}


void
UnescapeWM_CLASS(char *str, char **name, char **class)
{
    int i, j, k, dot;

    j = strlen(str);
    *name = wmalloc(j);
    **name = 0;
    *class = wmalloc(j);
    **class = 0;

    /* separate string in 2 parts */
    dot = -1;
    for (i = 0; i < j; i++) {
        if (str[i]=='\\') {
            i++;
            continue;
        } else if (str[i]=='.') {
            dot = i;
            break;
        }
    }

    /* unescape strings */
    for (i=0, k=0; i < dot; i++) {
        if (str[i]=='\\') {
            continue;
        } else {
            (*name)[k++] = str[i];
        }
    }
    (*name)[k] = 0;

    for (i=dot+1, k=0; i<j; i++) {
        if (str[i]=='\\') {
            continue;
        } else {
            (*class)[k++] = str[i];
        }
    }
    (*class)[k] = 0;

    if (!*name) {
        wfree(*name);
        *name = NULL;
    }
    if (!*class) {
        wfree(*class);
        *class = NULL;
    }
}



void
SendHelperMessage(WScreen *scr, char type, int workspace, char *msg)
{
    char *buffer;
    int len;
    int i;
    char buf[16];

    if (!scr->flags.backimage_helper_launched) {
        return;
    }

    len = (msg ? strlen(msg) : 0) + (workspace >=0 ? 4 : 0) + 1 ;
    buffer = wmalloc(len+5);
    snprintf(buf, len, "%4i", len);
    memcpy(buffer, buf, 4);
    buffer[4] = type;
    i = 5;
    if (workspace >= 0) {
        snprintf(buf, sizeof(buf), "%4i", workspace);
        memcpy(&buffer[i], buf, 4);
        i += 4;
        buffer[i] = 0;
    }
    if (msg)
        strcpy(&buffer[i], msg);

    if (write(scr->helper_fd, buffer, len+4) < 0) {
        wsyserror(_("could not send message to background image helper"));
    }
    wfree(buffer);
}


Bool
UpdateDomainFile(WDDomain *domain)
{
    struct stat stbuf;
    char path[PATH_MAX];
    WMPropList *shared_dict, *dict;
    Bool result, freeDict = False;

    dict = domain->dictionary;
    if (WMIsPLDictionary(domain->dictionary)) {
        /* retrieve global system dictionary */
        snprintf(path, sizeof(path), "%s/WindowMaker/%s",
                 SYSCONFDIR, domain->domain_name);
        if (stat(path, &stbuf) >= 0) {
            shared_dict = WMReadPropListFromFile(path);
            if (shared_dict) {
                if (WMIsPLDictionary(shared_dict)) {
                    freeDict = True;
                    dict = WMDeepCopyPropList(domain->dictionary);
                    WMSubtractPLDictionaries(dict, shared_dict, True);
                }
                WMReleasePropList(shared_dict);
            }
        }
    }

    result = WMWritePropListToFile(dict, domain->path, True);

    if (freeDict) {
        WMReleasePropList(dict);
    }

    return result;
}


char*
StrConcatDot(char *a, char *b)
{
    int len;
    char *str;

    if (!a)
        a = "";
    if (!b)
        b = "";

    len = strlen(a)+strlen(b)+4;
    str = wmalloc(len);

    snprintf(str, len, "%s.%s", a, b);

    return str;
}


#define MAX_CMD_SIZE 4096

Bool
GetCommandForPid(int pid, char ***argv, int *argc)
{
    static char buf[MAX_CMD_SIZE];
    FILE *fPtr;
    int count, i, j;
    Bool ok= False;

    sprintf(buf, "/proc/%d/cmdline", pid);
    fPtr = fopen(buf, "r");
    if (fPtr) {
        count = read(fileno(fPtr), buf, MAX_CMD_SIZE);
        if (count > 0) {
            buf[count-1] = 0;
            for (i=0, *argc=0; i<count; i++) {
                if (buf[i] == 0) {
                    (*argc)++;
                }
            }
            if ((*argc) == 0) {
                *argv = NULL;
                ok= False;
            } else {
                *argv = (char**) wmalloc(sizeof(char*) * (*argc));
                (*argv)[0] = buf;
                for (i=0, j=1; i<count; i++) {
                    if (buf[i] != 0)
                      continue;
                    if (i < count-1) {
                        (*argv)[j++] = &buf[i+1];
                    }
                    if (j == *argc) {
                        break;
                    }
                }
                ok= True;
            }
        }
        fclose(fPtr);
    }

    return ok;
}


static char*
getCommandForWindow(Window win, int elements)
{
    char **argv, *command = NULL;
    int argc;

    if (XGetCommand(dpy, win, &argv, &argc)) {
        if (argc > 0 && argv != NULL) {
            if (elements==0)
                elements = argc;
            command = wtokenjoin(argv, WMIN(argc, elements));
            if (command[0] == 0) {
                wfree(command);
                command = NULL;
            }
        }
        if (argv) {
            XFreeStringList(argv);
        }
    }

    return command;
}


/* Free result when done */
char*
GetCommandForWindow(Window win)
{
    return getCommandForWindow(win, 0);
}


/* Free result when done */
char*
GetProgramNameForWindow(Window win)
{
    return getCommandForWindow(win, 1);
}


