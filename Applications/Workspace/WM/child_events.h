/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef WM_CHILD_EVENTS_H
#define WM_CHILD_EVENTS_H
#include <sys/types.h>

int wChildEventsInit(void);
int wChildEventsRegister(pid_t pid);
void wReapChildProcesses(void);
void wChildEventsWakeUp(void);
void wChildEventsDrain(void (*callback)(pid_t, int));
#endif
