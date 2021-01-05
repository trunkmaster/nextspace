#ifndef __WORKSPACE_WM_WFINDFILE__
#define __WORKSPACE_WM_WFINDFILE__

/* You have to free the returned string when you no longer need it */
char *WMAbsolutePathForFile(const char *paths, const char *file);

#endif
