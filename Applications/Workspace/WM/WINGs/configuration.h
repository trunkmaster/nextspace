#ifndef __WORKSPACE_WM_WCONFIGURATION__
#define __WORKSPACE_WM_WCONFIGURATION__

/* ---[ WINGs/configuration.c ]------------------------------------------- */

void W_ReadConfigurations(void);

unsigned W_getconf_mouseWheelUp(void);

unsigned W_getconf_mouseWheelDown(void);

void W_setconf_doubleClickDelay(int value);

#endif
