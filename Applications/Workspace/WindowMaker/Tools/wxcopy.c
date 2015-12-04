/* wxcopy.c- copy stdin or file into cutbuffer
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

#define PROG_VERSION "wxcopy 0.3"


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>


#define LINESIZE	(4*1024)
#define MAXDATA		(64*1024)

void
help(char *progn)
{
    printf("Usage: %s [OPTIONS] [FILE]\n", progn);
    puts("Copies data from FILE or stdin into X cut buffer.");
    puts("");
    puts("  -display <display>		display to use");
    puts("  --cutbuffer <number>		cutbuffer number to put data");
    puts("  --no-limit			do not limit size of input data");
    puts("  --clear-selection		clears the current PRIMARY selection");
    puts("  --help			display this help and exit");
    puts("  --version			output version information and exit");
}

static int
errorHandler(Display *dpy, XErrorEvent *err)
{
    /* ignore all errors */
    return 0;
}


int
main(int argc, char **argv)
{
    Display *dpy;
    int i;
    int buffer=-1;
    char *filename=NULL;
    FILE *file=stdin;
    char *buf=NULL;
    char *display_name="";
    int l=0;
    int buf_len = 0;
    int	limit_check = 1;
    int clear_selection = 0;

    for (i=1; i<argc; i++) {
        if (argv[i][0]=='-') {
            if (strcmp(argv[i], "--help")==0) {
                help(argv[0]);
                exit(0);
            } else if (strcmp(argv[i], "--version")==0) {
                puts(PROG_VERSION);
                exit(0);
            } else if (strcmp(argv[i],"-cutbuffer")==0
                       || strcmp(argv[i],"--cutbuffer")==0) {
                if (i<argc-1) {
                    i++;
                    if (sscanf(argv[i],"%i", &buffer)!=1) {
                        fprintf(stderr, "%s: could not convert '%s' to int\n",
                                argv[0], argv[i]);
                        exit(1);
                    }
                    if (buffer<0 || buffer > 7) {
                        fprintf(stderr, "%s: invalid buffer number %i\n",
                                argv[0], buffer);
                        exit(1);
                    }
                } else {
                    printf("%s: missing argument for '%s'\n", argv[0], argv[i]);
                    printf("Try '%s --help' for more information\n", argv[0]);
                    exit(1);
                }
            } else if (strcmp(argv[i], "-display")==0) {
                if (i < argc-1) {
                    display_name = argv[++i];
                } else {
                    printf("%s: missing argument for '%s'\n", argv[0], argv[i]);
                    printf("Try '%s --help' for more information\n", argv[0]);
                    exit(1);
                }
            } else if (strcmp(argv[i],"-clearselection")==0
                       || strcmp(argv[i],"--clear-selection")==0) {
                clear_selection = 1;
            } else if (strcmp(argv[i],"-nolimit")==0
                       || strcmp(argv[i],"--no-limit")==0) {
                limit_check = 0;
            } else {
                printf("%s: invalid argument '%s'\n", argv[0], argv[i]);
                printf("Try '%s --help' for more information\n", argv[0]);
                exit(1);
            }
        } else {
            filename = argv[i];
        }
    }
    if (filename) {
        file = fopen(filename, "rb");
        if (!file) {
            char line[1024];
            sprintf(line, "%s: could not open \"%s\"", argv[0], filename);
            perror(line);
            exit(1);
        }
    }

    dpy = XOpenDisplay(display_name);
    XSetErrorHandler(errorHandler);
    if (!dpy) {
        fprintf(stderr, "%s: could not open display \"%s\"\n", argv[0],
                XDisplayName(display_name));
        exit(1);
    }

    if (buffer<0) {
        Atom *rootWinProps;
        int exists[8] = {0, 0, 0, 0, 0, 0, 0, 0};
        int i, count;

        /* Create missing CUT_BUFFERs */
        rootWinProps = XListProperties(dpy, DefaultRootWindow(dpy), &count);
        for (i=0; i<count; i++) {
            switch(rootWinProps[i]) {
            case XA_CUT_BUFFER0:
                exists[0] = 1; break;
            case XA_CUT_BUFFER1:
                exists[1] = 1; break;
            case XA_CUT_BUFFER2:
                exists[2] = 1; break;
            case XA_CUT_BUFFER3:
                exists[3] = 1; break;
            case XA_CUT_BUFFER4:
                exists[4] = 1; break;
            case XA_CUT_BUFFER5:
                exists[5] = 1; break;
            case XA_CUT_BUFFER6:
                exists[6] = 1; break;
            case XA_CUT_BUFFER7:
                exists[7] = 1; break;
            default:
                break;
            }
        }
        if (rootWinProps) {
            XFree(rootWinProps);
        }
        for (i=0; i<8; i++) {
            if (!exists[i]) {
                XStoreBuffer(dpy, "", 0, i);
            }
        }

        XRotateBuffers(dpy, 1);
        buffer=0;
    }

    while (!feof(file)) {
        char *nbuf;
        char tmp[LINESIZE+2];
        int nl=0;

        /*
         * Use read() instead of fgets() to preserve NULLs, since
         * especially since there's no reason to read one line at a time.
         */
        if ((nl = fread(tmp, 1, LINESIZE, file)) <= 0) {
            break;
        }
        if (buf_len == 0) {
            nbuf = malloc(buf_len = l+nl+1);
        } else if (buf_len < l+nl+1) {
            /*
             * To avoid terrible performance on big input buffers,
             * grow by doubling, not by the minimum needed for the
             * current line.
             */
            buf_len = 2 * buf_len + nl + 1;
            /* some realloc implementations don't do malloc if buf==NULL */
            if (buf == NULL) {
                nbuf = malloc(buf_len);
            } else {
                nbuf = realloc(buf, buf_len);
            }
        } else {
            nbuf = buf;
        }
        if (!nbuf) {
            fprintf(stderr, "%s: out of memory\n", argv[0]);
            exit(1);
        }
        buf=nbuf;
        /*
         * Don't strcat, since it would make the algorithm n-squared.
         * Don't use strcpy, since it stops on a NUL.
         */
        memcpy(buf+l, tmp, nl);
        l+=nl;
        if (limit_check && l>=MAXDATA) {
            fprintf
                (
                 stderr,
                 "%s: too much data in input - more than %d bytes\n"
                 "  use the -nolimit argument to remove the limit check.\n",
                 argv[0], MAXDATA
                );
            exit(1);
        }
    }

    if (clear_selection) {
        XSetSelectionOwner(dpy, XA_PRIMARY, None, CurrentTime);
    }
    if (buf) {
        XStoreBuffer(dpy, buf, l, buffer);
    }
    XFlush(dpy);
    XCloseDisplay(dpy);
    exit(buf == NULL || errno != 0);
}

