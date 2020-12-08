#ifndef __WORKSPACE_WM_WAPPRESOURCE__
#define __WORKSPACE_WM_WAPPRESOURCE__

#include <WINGs/wpixmap.h>

typedef struct W_Application {
    char *applicationName;
    int argc;
    char **argv;
    char *resourcePath;
} W_Application;

extern struct W_Application WMApplication;

void W_InitApplication(WMScreen *scr);

Bool W_ApplicationInitialized(void);

/* ---[ WINGs/wappresource.c ]-------------------------------------------- */

void WMSetApplicationIconImage(WMScreen *app, RImage *image);

RImage* WMGetApplicationIconImage(WMScreen *app);

void WMSetApplicationIconPixmap(WMScreen *app, WMPixmap *icon);

WMPixmap* WMGetApplicationIconPixmap(WMScreen *app);

/* If color==NULL it will use the default color for panels: ae/aa/ae */
WMPixmap* WMCreateApplicationIconBlendedPixmap(WMScreen *scr, const RColor *color);

void WMSetApplicationIconWindow(WMScreen *scr, Window window);

/* ---[ WINGs/wapplication.c ]-------------------------------------------- */

void WMInitializeApplication(const char *applicationName, int *argc, char **argv);

/* You're supposed to call this funtion before exiting so WINGs can terminate properly */
void WMReleaseApplication(void);

/* /\* don't free the returned string *\/ */
char* WMGetApplicationName(void);

#endif
