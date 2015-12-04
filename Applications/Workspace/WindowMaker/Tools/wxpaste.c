/* wxpaste.c- paste contents of cutbuffer to stdout
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
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#define PROG_VERSION "wxpaste (Window Maker) 0.3"

#include "../src/config.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <sys/time.h>
#include <sys/types.h>
#ifdef HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif


#define MAXDATA		(4*1024*1024)


void
help(char *progn)
{
    printf("Usage: %s [OPTIONS] [FILE]\n", progn);
    puts("Copies data from X selection or cutbuffer to FILE or stdout.");
    puts("");
    puts("  -display display		display to use");
    puts("  --cutbuffer number		cutbuffer number to get data from");
    puts("  --selection [selection]	reads data from named selection instead of\n"
         "				cutbuffer");
    puts("  --help			display this help and exit");
    puts("  --version			output version information and exit");
}


Time
getTimestamp(Display *dpy, Window win)
{
    XEvent ev;

    /* So we do this trickery to get a time stamp:
     *
     * 1. Grab the server because we are paranoid and don't want to
     * get in a race with another instance of wxpaste being ran at the
     * same time.
     *
     * 2. Set a dummy property in our window.
     *
     * 3. Get the PropertyNotify event and get it's timestamp.
     *
     * 4. Ungrab the server.
     */

    XSelectInput(dpy, win, PropertyChangeMask);

    /* Generate a PropertyNotify event */
    XStoreName(dpy, win, "shit");

    /* wait for the event */
    while (1) {
        XNextEvent(dpy, &ev);
        if (ev.type == PropertyNotify)
            break;
    }

    return ev.xproperty.time;
}


char*
fetchSelection(Display *dpy, char *selection, char *progName)
{
    Atom selatom = XInternAtom(dpy, selection, False);
    Atom clipatom = XInternAtom(dpy, "CLIPBOARD", False);
    Time now;
    XEvent ev;
    Window win;
    int ok = 0;
    struct timeval timeout;
    fd_set fdset;

    win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 1, 1,
                              0, 0, 0);
    /*
     * The ICCCM says that we can't pass CurrentTime as the timestamp
     * for XConvertSelection(), but we don't have anything to use as
     * a timestamp...
     */
    now = getTimestamp(dpy, win);

    XConvertSelection(dpy, selatom, XA_STRING, clipatom, win, now);

    timeout.tv_sec = 1;
    timeout.tv_usec = 0;

    /* wait for the convertion */
    while (0) {
        int res;

        if (XPending(dpy)==0) {
            FD_ZERO(&fdset);
            FD_SET(ConnectionNumber(dpy), &fdset);
            res = select(ConnectionNumber(dpy)+1, &fdset, NULL, NULL,
                         &timeout);
            if (res <= 0) {
                ok = 0;
                break;
            }
        }
        if (res > 0 || XPending(dpy) > 0) {
            XNextEvent(dpy, &ev);
            if (ev.type == SelectionNotify && ev.xany.window == win) {
                ok = 1;
                break;
            }
        }
    }

    /* if success, return the data */
    if (ok) {
        Atom rtype;
        int bits;
        unsigned long len, bytes;
        unsigned char *data;

        if (XGetWindowProperty(dpy, win, clipatom, 0, MAXDATA/4, False,
                               XA_STRING, &rtype, &bits, &len, &bytes, &data)!=0)
            return NULL;

        if ((rtype!=XA_STRING) || (bits!=8)) {
            return NULL;
        } else {
            return (char*)data;
        }
    }
    return NULL;
}


int
main(int argc, char **argv)
{
    Display *dpy;
    int i, l;
    int buffer=0;
    char *buf;
    int	status;
    char *display_name="";
    char *selection_name=NULL;

    for (i=1; i<argc; i++) {
        if (argv[i][0]=='-') {
            if (argv[i][1]=='h' || strcmp(argv[i], "--help")==0) {
                help(argv[0]);
                exit(0);
            } else if (strcmp(argv[i], "--version")==0) {
                puts(PROG_VERSION);
                exit(0);
            } else if (strcmp(argv[i],"-selection")==0
                       || strcmp(argv[i],"--selection")==0) {
                if (i<argc-1) {
                    selection_name = argv[++i];
                } else {
                    selection_name = "PRIMARY";
                }
            } else if (strcmp(argv[i],"-display")==0) {
                if (i<argc-1) {
                    display_name = argv[++i];
                } else {
                    help(argv[0]);
                    exit(0);
                }
            } else if (strcmp(argv[i],"-cutbuffer")==0
                       || strcmp(argv[i],"--cutbuffer")==0) {
                if (i<argc-1) {
                    i++;
                    if (sscanf(argv[i],"%i", &buffer)!=1) {
                        fprintf(stderr, "%s: could not convert \"%s\" to int\n",
                                argv[0], argv[i]);
                        exit(1);
                    }
                    if (buffer<0 || buffer > 7) {
                        fprintf(stderr, "%s: invalid buffer number %i\n",
                                argv[0], buffer);
                        exit(1);
                    }
                } else {
                    fprintf(stderr, "%s: invalid argument '%s'\n", argv[0],
                            argv[i]);
                    fprintf(stderr, "Try '%s --help' for more information.\n",
                            argv[0]);
                    exit(1);
                }
            }
        } else {
            fprintf(stderr, "%s: invalid argument '%s'\n", argv[0], argv[i]);
            fprintf(stderr, "Try '%s --help' for more information.\n",
                    argv[0]);
            exit(1);
        }
    }
    dpy = XOpenDisplay(display_name);
    if (!dpy) {
        fprintf(stderr, "%s: could not open display \"%s\"\n", argv[0],
                XDisplayName(display_name));
        exit(1);
    }

    if (selection_name) {
        buf = fetchSelection(dpy, selection_name, argv[0]);
    } else {
        buf = NULL;
    }

    if (buf == NULL) {
        buf = XFetchBuffer(dpy, &l, buffer);
    }

    if (buf == NULL) {
        status = 1;
    } else {
        if (write(STDOUT_FILENO, buf, l) == -1)
            status = errno;
        else
            status = 0;
    }
    XCloseDisplay(dpy);
    exit(status);
}

