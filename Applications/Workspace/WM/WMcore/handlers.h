#ifndef _WHANDLERS_H_
#define _WHANDLERS_H_

#include <WINGs/WINGs.h>

Bool W_CheckIdleHandlers(void);

void W_CheckTimerHandlers(void);

Bool W_HandleInputEvents(Bool waitForInput, int inputfd);

/* ---[ WINGs/handlers.c ]------------------------------------------------ */

/* Event handlers: timer, idle, input */

WMHandlerID WMAddTimerHandler(int milliseconds, WMCallback *callback,
                              void *cdata);

WMHandlerID WMAddPersistentTimerHandler(int milliseconds, WMCallback *callback,
                                        void *cdata);

void WMDeleteTimerWithClientData(void *cdata);

void WMDeleteTimerHandler(WMHandlerID handlerID);

WMHandlerID WMAddIdleHandler(WMCallback *callback, void *cdata);

void WMDeleteIdleHandler(WMHandlerID handlerID);

WMHandlerID WMAddInputHandler(int fd, int condition, WMInputProc *proc,
                              void *clientData);

void WMDeleteInputHandler(WMHandlerID handlerID);

#endif
