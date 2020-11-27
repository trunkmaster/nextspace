#ifndef _WHANDLERS_H_
#define _WHANDLERS_H_

#include <WINGs/WINGs.h>

/* Timers */

void W_CheckTimerHandlers(void);

WMHandlerID WMAddTimerHandler(int milliseconds, WMCallback *callback,
                              void *cdata);

WMHandlerID WMAddPersistentTimerHandler(int milliseconds, WMCallback *callback,
                                        void *cdata);

void WMDeleteTimerWithClientData(void *cdata);

void WMDeleteTimerHandler(WMHandlerID handlerID);

/* Input event handlers */

Bool W_HandleInputEvents(Bool waitForInput, int inputfd);

WMHandlerID WMAddInputHandler(int fd, int condition, WMInputProc *proc,
                              void *clientData);

void WMDeleteInputHandler(WMHandlerID handlerID);

#endif
