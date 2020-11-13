/* ---[ WINGs/findfile.c ]------------------------------------------------ */

#ifndef _WFINDFILE_H_
#define _WFINDFILE_H_

#include <WMcore/proplist.h>

/* For the 4 function below, you have to free the returned string when you no longer need it */

char* wfindfile(const char *paths, const char *file);

char* wfindfileinlist(char *const *path_list, const char *file);

char* wfindfileinarray(WMPropList* array, const char *file);

char* wexpandpath(const char *path);

int wcopy_file(const char *toPath, const char *srcFile, const char *destFile);

/* don't free the returned string */
char* wgethomedir(void);

#endif
