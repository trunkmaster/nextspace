#ifndef _WAPPLICATION_H_
#define _WAPPLICATION_H_

/* ---[ WINGs/wapplication.c ]-------------------------------------------- */

void WMInitializeApplication(const char *applicationName, int *argc, char **argv);

/* You're supposed to call this funtion before exiting so WINGs can terminate properly */
void WMReleaseApplication(void);

void WMSetResourcePath(const char *path);

/* don't free the returned string */
char* WMGetApplicationName(void);

/* Try to locate resource file. ext may be NULL */
char* WMPathForResourceOfType(const char *resource, const char *ext);

#endif
