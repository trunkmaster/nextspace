/* wmsetup.c- create wmaker config file dir structure and copy default
 * 	config files.
 *
 *  Copyright (c) 2000-2003 Alfredo K. Kojima
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
#if 1
int
main()
{
}
#else
#define PROG_VERSION "wmsetup 0.0 (Window Maker)"

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <WINGs/WINGs.h>

#include "../src/config.h"



char *RequiredDirectories[] = {
    "/Defaults",
    "/Library",
    "/Library/Icons",
    "/Library/WindowMaker",
    "/Library/WindowMaker/Backgrounds",
    "/Library/WindowMaker/IconSets",
    "/Library/WindowMaker/Pixmaps",
    "/Library/WindowMaker/CachedPixmaps",
    "/Library/WindowMaker/SoundSets",
    "/Library/WindowMaker/Sounds",
    "/Library/WindowMaker/Styles",
    "/Library/WindowMaker/Themes",
    "/Library/WindowMaker/WPrefs",
    NULL
};


char *RequiredFiles[] = {
    "/Defaults/WindowMaker",
    "/Defaults/WMWindowAttributes",
    NULL
};



WMScreen *scr;



#define wlog wwarning


#if 0
void
wlog(const char *msg, ...)
{
    va_list args;
    char buf[MAXLINE];

    va_start(args, msg);

    vsprintf(buf, msg, args);
    puts(buf);

    va_end(args);
}
#endif


void
alert(const char *msg, ...)
{
    va_list args;
    char buffer[2048];

    va_start(args, msg);

    vsprintf(buf, msg, args);

    WMRunAlertPanel(scr, NULL, _("Error"),
                    buffer, _("OK"), NULL, NULL);

    va_end(args);
}


Bool
ask(char *title, char *yes, char *no, const char *msg, ...)
{
    va_list args;
    char buffer[2048];

    va_start(args, msg);

    vsprintf(buf, msg, args);

    WMRunAlertPanel(scr, NULL, title,
                    buffer, yes, no, NULL);

    va_end(args);
}


char*
renameName(char *path)
{
    char *buf = wmalloc(strlen(path)+8);
    int i;

    sprintf(buf, "%s~", path);

    if (access(buf, F_OK) < 0) {
        return buf;
    }

    for (i = 0; i < 10; i++) {
        sprintf(buf, "%s~%i", path, i);

        if (access(buf, F_OK) < 0) {
            return buf;
        }
    }

    sprintf(buf, "%s~", path);

    return buf;
}



void
showFileError(int error, Bool directory, char *path)
{
    switch (error) {
    case EACCESS:
        if (directory) {
            alert(_("The directory %s needs to be fully accessible, but is\n"
                    "not. Make sure all of it's parent directories have\n"
                    "read and execute permissions set."), path);
        } else {
            alert(_("The file %s needs to be fully accessible, but is not.\n"
                    "Make sure it has read and write permissions set and\n"
                    "all of it's parent directories have read and execute\n"
                    "permissions."), path);
        }
        break;

    case EROFS:
        alert(_("The %s %s is in a read-only file system, but it needs to be\n"
                "writable. Start wmaker with the --static command line option."),
              directory ? _("directory") : _("file"), path);
        break;

    default:
        alert(_("An error occurred while accessing the %s %s. Please make sure\n"
                "it exists and is accessible.\n%s"),
              directory ? _("directory") : _("file"), path,
              wstrerror(error));
        break;
    }
}



Bool
checkDir(char *path, Bool fatal)
{
    if (access(path, F_OK) < 0) {
        if (mkdir(path, 0775) < 0) {
            alert(_("could not create directory %s\n%s"), path,
                  wstrerror(errno));
            return False;
        } else {
            wlog(_("created directory %s"), path);
        }
    }

    if (access(path, R_OK|W_OK|X_OK) == 0) {
        return True;
    }
    wsyserror("bad access to directory %s", path);

    if (!fatal) {
        struct stat buf;

        if (stat(path, &buf) < 0) {
            alert(_("The directory %s could not be stat()ed. Please make sure\n"
                    "it exists and is accessible."), path);
            return False;
        }

        if (!S_ISDIR(buf)) {
            char *newName = renameName(path);

            if (ask(_("Rename"), _("OK"), _("Cancel"),
                    _("A directory named %s needs to be created but a file with\n"
                      "the same name already exists. The file will be renamed to\n"
                      "%s and the directory will be created."),
                    path, newName)) {

                if (rename(path, newName) < 0) {
                    alert(_("Could not rename %s to %s:%s"),
                          path, newName, wstrerror(errno));
                }
            }
            wfree(newName);

            return False;
        }
        if (!(buf.st_mode & S_IRWXU)) {
            if (chmod(path, (buf.st_mode & 00077)|7) < 0) {
                return False;
            }
        }

        return checkDir(path, True);
    }

    showFileError(errno, True, path);

    return False;
}




Bool
checkFile(char *path)
{
    if (access(path, F_OK|R_OK|W_OK) == 0) {
        return True;
    }

    showFileError(errno, False, path);

    return False;
}



Bool
checkCurrentSetup(char *home)
{
    char path[1024];
    char *p;

    if (!checkDir(home, False)) {
        wlog("couldnt make directory %s", home);
        return False;
    }

    for (p = RequiredDirectories; p != NULL; p++) {
        sprintf(path, "%s%s", home, p);
        if (!checkDir(p, False)) {
            wlog("couldnt make directory %s", p);
            return False;
        }
    }

    for (p = RequiredFiles; p != NULL; p++) {
        sprintf(path, "%s%s", home, p);
        if (!checkFile(p, False)) {
            return False;
        }
    }

    return True;
}



Bool
copyAllFiles(char *gsdir)
{
    FILE *f;
    char path[2048];
    char file[256];
    char target[2048];

    /* copy misc data files */

    sprintf(path, "%s/USER_FILES", DATADIR);

    f = fopen(path, "rb");
    while (!feof(f)) {
        if (!fgets(file, 255, f)) {
            break;
        }
        sprintf(path, "%s/%s", DATADIR, file);
        sprintf(target, "%s/Library/WindowMaker/%s", gsdir, file);
        if (!copyFile(path, target)) {
            return False;
        }
    }
    fclose(f);

    /* copy auto{start,finish} scripts */


    /* select and copy menu */


    /* copy Defaults stuff */

    sprintf(path, "%s/USER_FILES", ETCDIR);

    f = fopen(path, "rb");
    while (!feof(f)) {
        if (!fgets(path, 255, f)) {
            break;
        }
        sprintf(path, "%s/%s", ETCDIR, file);
        sprintf(target, "%s/Defaults/%s", gsdir, file);
        if (!copyFile(path, target)) {
            return False;
        }
    }
    fclose(f);

    /* setup .xinitrc */

}



void
showFinishSplash(char *gsdir)
{
#if 0
    WMWindow *win;

    win = WMCreateWindow(scr, "finished");
#endif
}


int
main(int argc, char **argv)
{
    Display *dpy;
    char *gsdir;
    int i;

    for (i=1; i<argc; i++) {
        if (strcmp(argv[i], "-display")==0) {
            i++;
            if (i>=argc) {
                wwarning(_("too few arguments for %s"), argv[i-1]);
                exit(0);
            }
            DisplayName = argv[i];
        } else if (strcmp(argv[i], "-version")==0
                   || strcmp(argv[i], "--version")==0) {
            puts(PROG_VERSION);
            exit(0);
        }
    }

    WMInitializeApplication("WMSetup", &argc, argv);

    dpy = XOpenDisplay("");
    if (!dpy) {
        printf("could not open display\n");
        exit(1);
    }

    scr = WMCreateScreen(dpy, DefaultScreen(dpy));

    gsdir = wusergnusteppath();

    /* check directory structure and copy files */
    if (access(gsdir, F_OK) != 0) {
        if (!ask(_("Window Maker"), _("OK"), _("Cancel"),
                 _("Window Maker will create a directory named %s, where\n"
                   "it will store it's configuration files and other data."),
                 gsdir)) {
            alert(_("Window Maker will be started in 'static' mode, where\n"
                    "it will use default configuration and will not write\n"
                    "any information to disk."));
            return 1;
        }
    }

    if (checkCurrentSetup(gsdir)) {
        printf(_("%s: wmaker configuration files already installed\n"),
               argv[0]);
        return 0;
    }

    if (!copyAllFiles(gsdir)) {
        alert(_("An error occurred while doing user specific setup of\n"
                "Window Maker. It will be started in 'static' mode, where\n"
                "the default configuration will be used and it will not write\n"
                "any information to disk."));
        return 1;
    }

    showFinishSplash(gsdir);

    return 0;
}
#endif

